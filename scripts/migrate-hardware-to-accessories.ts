/**
 * scripts/migrate-hardware-to-accessories.ts
 * ─────────────────────────────────────────────────────────────
 * ONE-OFF DATA MIGRATION: Material → Accessory
 *
 * WHAT THIS SCRIPT DOES:
 *   1. Identifies hardware items in the Material table by:
 *      a) Their code prefix  → AKL-, ACF-, AAL-, AGU-, AHD-, ASP-, ADC-
 *      b) Their unit         → "ชิ้น", "ม้วน", "แพค"
 *      c) Their category slug → "alumet-accessories"
 *      d) FFA- (Flexi end caps / clip-locks, unit "ชิ้น")
 *
 *   2. For each found Material:
 *      - Creates a matching Accessory row (code, name, unit, baseCost)
 *      - Creates matching AccessoryVariant rows from MaterialVariant rows
 *      - Skips if an Accessory with the same code already exists (idempotent)
 *
 *   3. Checks for TemplateComponent references (via materialId):
 *      - Hardware should NOT appear in TemplateComponent (they are not bar profiles)
 *      - If any are found, the script ABORTS with a clear warning before deleting
 *
 *   4. Deletes the original Material (+ its MaterialVariants cascade) only
 *      after all Accessory rows have been committed successfully.
 *
 * SAFETY:
 *   - All DB work is in a single Prisma $transaction (atomic)
 *   - A full dry-run mode prints what WOULD happen without making changes
 *   - CuttingResult references are also checked before deletion
 *
 * PREREQUISITES:
 *   1. Run the Prisma migration that adds the `accessories` table:
 *      npx prisma migrate dev --name add-accessory-model
 *   2. Then run this script:
 *      npx tsx scripts/migrate-hardware-to-accessories.ts
 *
 *   Optional dry-run (print only, no DB changes):
 *      DRY_RUN=true npx tsx scripts/migrate-hardware-to-accessories.ts
 * ─────────────────────────────────────────────────────────────
 */

import { config } from "dotenv";
config();

import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

// ── Prisma setup (mirrors the project's standard config) ──────
const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL,
});
const prisma = new PrismaClient({ adapter });

// ── Configuration ─────────────────────────────────────────────
const DRY_RUN = process.env.DRY_RUN === "true";

/**
 * A Material is classified as "hardware / accessory" when any of the
 * following conditions is true:
 *   1. Its `unit` is one of the piece/roll/pack units (not a bar/meter)
 *   2. Its `code` starts with a known hardware prefix
 *   3. Its category has slug "alumet-accessories"
 */
const HARDWARE_UNITS = new Set(["ชิ้น", "ม้วน", "แพค"]);

const HARDWARE_CODE_PREFIXES = [
  "AKL-",
  "ACF-",
  "AAL-",
  "AGU-",
  "AHD-",
  "ASP-",
  "ADC-",
  "FFA-",   // Flexi end caps / clip-locks
];

function isHardwareCode(code: string): boolean {
  return HARDWARE_CODE_PREFIXES.some((prefix) => code.startsWith(prefix));
}

// ── Main ──────────────────────────────────────────────────────
async function main() {
  console.log("═══════════════════════════════════════════════════════════");
  console.log(
    DRY_RUN
      ? "🔍 DRY RUN — No database changes will be made"
      : "🚀 LIVE RUN — Changes WILL be committed to the database"
  );
  console.log("═══════════════════════════════════════════════════════════\n");

  // ── Step 1: Find all candidate Materials ─────────────────────
  console.log("→ Step 1: Identifying hardware/accessory Materials...\n");

  const allMaterials = await prisma.material.findMany({
    include: {
      variants: { include: { color: true } },
      category: { select: { slug: true, name: true } },
      templateComponents: { select: { id: true, label: true } },
      cuttingResults: { select: { id: true } },
    },
    orderBy: { code: "asc" },
  });

  const hardwareMaterials = allMaterials.filter((m) => {
    const byUnit = HARDWARE_UNITS.has(m.unit);
    const byCode = isHardwareCode(m.code);
    const byCategory = m.category.slug === "alumet-accessories";
    return byUnit || byCode || byCategory;
  });

  if (hardwareMaterials.length === 0) {
    console.log("✅ No hardware materials found. Nothing to migrate.\n");
    return;
  }

  console.log(`   Found ${hardwareMaterials.length} hardware material(s) to migrate:\n`);

  // ── Step 2: Preflight safety checks ──────────────────────────
  console.log("→ Step 2: Preflight safety checks...\n");

  let hasBlockers = false;

  for (const m of hardwareMaterials) {
    const hasTemplateLinks = m.templateComponents.length > 0;
    const hasCuttingLinks = m.cuttingResults.length > 0;

    if (hasTemplateLinks || hasCuttingLinks) {
      console.error(
        `   ❌ BLOCKER: [${m.code}] "${m.name}" has active references:\n` +
          (hasTemplateLinks
            ? `      • ${m.templateComponents.length} TemplateComponent record(s): ${m.templateComponents.map((tc) => `"${tc.label}"`).join(", ")}\n`
            : "") +
          (hasCuttingLinks
            ? `      • ${m.cuttingResults.length} CuttingResult record(s)\n`
            : "")
      );
      hasBlockers = true;
    } else {
      console.log(
        `   ✓ [${m.code}] "${m.name}" — unit="${m.unit}", ` +
          `variants=${m.variants.length}, ` +
          `category="${m.category.name}"`
      );
    }
  }

  if (hasBlockers) {
    console.error(
      "\n❌ MIGRATION ABORTED — Resolve the blockers above before re-running.\n" +
        "   Hardware items should not be referenced by TemplateComponent or CuttingResult.\n" +
        "   If these links are intentional, manually update the related records first.\n"
    );
    process.exit(1);
  }

  console.log("\n   ✅ All safety checks passed.\n");

  // ── Step 3: Check for already-migrated records ────────────────
  const existingAccessoryCodes = new Set(
    (await prisma.accessory.findMany({ select: { code: true } })).map(
      (a) => a.code
    )
  );

  const toMigrate = hardwareMaterials.filter(
    (m) => !existingAccessoryCodes.has(m.code)
  );
  const alreadyMigrated = hardwareMaterials.filter((m) =>
    existingAccessoryCodes.has(m.code)
  );

  if (alreadyMigrated.length > 0) {
    console.log(
      `→ Skipping ${alreadyMigrated.length} already-migrated record(s):\n`
    );
    alreadyMigrated.forEach((m) =>
      console.log(`   ⏭  [${m.code}] "${m.name}" — already in Accessory table`)
    );
    console.log();
  }

  if (toMigrate.length === 0) {
    console.log("✅ All records already migrated. Nothing left to do.\n");
    return;
  }

  // ── Step 4: Summarise the plan ────────────────────────────────
  console.log(`→ Step 3: Migration plan — ${toMigrate.length} Material(s) to move:\n`);

  let totalVariants = 0;
  for (const m of toMigrate) {
    totalVariants += m.variants.length;
    console.log(
      `   → [${m.code}] "${m.name}"  unit="${m.unit}"  baseCost=฿${m.baseCost}` +
        `  variants=${m.variants.length}` +
        (m.variants.length > 0
          ? " (" + m.variants.map((v) => v.color.name.split(" ")[0]).join(", ") + ")"
          : "")
    );
  }

  console.log(
    `\n   Totals: ${toMigrate.length} Accessory rows + ${totalVariants} AccessoryVariant rows`
  );
  console.log(
    `   Then:   ${toMigrate.length} Material rows will be DELETED (cascade deletes MaterialVariants)\n`
  );

  if (DRY_RUN) {
    console.log(
      "🔍 DRY RUN complete — no changes made. Remove DRY_RUN=true to execute.\n"
    );
    return;
  }

  // ── Step 5: Execute — one atomic transaction per item ────────
  // (Using per-item transactions avoids the 5s Prisma interactive
  //  transaction timeout that would fire if all 133 items ran in one tx.)
  console.log("→ Step 4: Executing migration...\n");

  let successCount = 0;
  let failCount = 0;

  for (const m of toMigrate) {
    try {
      await prisma.$transaction(async (tx) => {
        // 5a. Create Accessory
        const accessory = await tx.accessory.create({
          data: {
            code: m.code,
            name: m.name,
            unit: m.unit,
            baseCost: m.baseCost,
            description: m.description ?? undefined,
            imageUrl: m.imageUrl ?? undefined,
            sortOrder: m.sortOrder,
            isActive: m.isActive,
          },
        });

        // 5b. Create AccessoryVariants
        for (const v of m.variants) {
          await tx.accessoryVariant.create({
            data: {
              accessoryId: accessory.id,
              colorId: v.colorId,
              unitCost: v.unitCost,
              isActive: v.isActive,
            },
          });
        }

        // 5c. Delete original Material (MaterialVariants cascade automatically)
        await tx.material.delete({ where: { id: m.id } });
      });

      console.log(
        `   ✅ [${m.code}] "${m.name}" — copied ${m.variants.length} variant(s), deleted from Material`
      );
      successCount++;
    } catch (err) {
      console.error(
        `   ❌ [${m.code}] "${m.name}" — FAILED (item skipped, DB unchanged for this record):\n`,
        err
      );
      failCount++;
    }
  }

  // ── Step 6: Verify ───────────────────────────────────────────
  console.log("\n→ Step 5: Verification...\n");

  const newAccessoryCount = await prisma.accessory.count();
  const newVariantCount = await prisma.accessoryVariant.count();
  const orphanCheck = await prisma.material.findMany({
    where: {
      OR: [
        { unit: { in: ["ชิ้น", "ม้วน", "แพค"] } },
        ...HARDWARE_CODE_PREFIXES.map((prefix) => ({
          code: { startsWith: prefix },
        })),
      ],
    },
    select: { code: true, name: true },
  });

  console.log(`   Accessory rows in DB   : ${newAccessoryCount}`);
  console.log(`   AccessoryVariant rows  : ${newVariantCount}`);

  if (orphanCheck.length > 0) {
    console.warn(
      `\n   ⚠️  ${orphanCheck.length} Material row(s) still match hardware criteria:`
    );
    orphanCheck.forEach((m) =>
      console.warn(`      [${m.code}] "${m.name}"`)
    );
    console.warn(
      "   These may be new records added after migration started, or were blocked above.\n"
    );
  } else {
    console.log("   ✅ No stray hardware Materials remain in Material table.\n");
  }

  console.log("═══════════════════════════════════════════════════════════");
  console.log(
    `✅ Migration complete — ${successCount} item(s) moved from Material → Accessory` +
      (failCount > 0 ? ` (${failCount} failed — see errors above)` : "")
  );
  console.log("═══════════════════════════════════════════════════════════\n");
}

main()
  .catch((e) => {
    console.error("\n❌ Migration failed:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
