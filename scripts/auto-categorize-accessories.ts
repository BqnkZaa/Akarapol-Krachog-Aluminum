/**
 * scripts/auto-categorize-accessories.ts
 * ─────────────────────────────────────────────────────────────
 * ONE-OFF DATA MIGRATION: Auto-categorize Accessory Series
 *
 * WHAT THIS SCRIPT DOES:
 *   1. Fetches all Accessory records in the database.
 *   2. Checks each Accessory's code and name (case-insensitive) to match:
 *      - Contains "SL" -> "ชุดบานเลื่อน" (Sliding)
 *      - Contains "CA" or "OP" -> "ชุดบานเปิด, บานกระทุ้ง" (Casement/Awning)
 *      - Contains "BF" -> "ชุดบานเฟี้ยม" (Bi-fold)
 *   3. If no match is found, leaves the series as-is, or defaults to "ทั่วไป" if it's currently empty.
 *   4. Updates the database and prints a detailed summary of changes.
 *
 * RUNNING THIS SCRIPT:
 *   npx tsx scripts/auto-categorize-accessories.ts
 *
 * DRY RUN (Print changes without updating database):
 *   DRY_RUN=true npx tsx scripts/auto-categorize-accessories.ts
 * ─────────────────────────────────────────────────────────────
 */

import { config } from "dotenv";
config();

import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

// ── Prisma setup ─────────────────────────────────────────────
const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error("❌ Error: DATABASE_URL environment variable is not defined.");
  process.exit(1);
}

const adapter = new PrismaPg({ connectionString });
const prisma = new PrismaClient({ adapter });

// ── Configuration ─────────────────────────────────────────────
const DRY_RUN = process.env.DRY_RUN === "true";

async function main() {
  console.log("═══════════════════════════════════════════════════════════");
  console.log(
    DRY_RUN
      ? "🔍 DRY RUN — No database changes will be made"
      : "🚀 LIVE RUN — Changes WILL be committed to the database"
  );
  console.log("═══════════════════════════════════════════════════════════\n");

  console.log("→ Fetching accessories from database...");
  const accessories = await prisma.accessory.findMany({
    orderBy: { code: "asc" },
  });

  if (accessories.length === 0) {
    console.log("✅ No accessories found in the database.");
    return;
  }

  console.log(`Fetched ${accessories.length} accessories. Starting categorization...\n`);

  let updatedCount = 0;
  let slidingCount = 0;
  let casementCount = 0;
  let bifoldCount = 0;
  let generalCount = 0;
  let unchangedCount = 0;

  for (const acc of accessories) {
    const codeUpper = acc.code.toUpperCase();
    const nameUpper = acc.name.toUpperCase();
    let targetSeries = acc.series;

    // Categorization logic based on name or code matching
    if (codeUpper.includes("SL") || nameUpper.includes("SL")) {
      targetSeries = "ชุดบานเลื่อน";
      slidingCount++;
    } else if (
      codeUpper.includes("CA") ||
      codeUpper.includes("OP") ||
      nameUpper.includes("CA") ||
      nameUpper.includes("OP")
    ) {
      targetSeries = "ชุดบานเปิด, บานกระทุ้ง";
      casementCount++;
    } else if (codeUpper.includes("BF") || nameUpper.includes("BF")) {
      targetSeries = "ชุดบานเฟี้ยม";
      bifoldCount++;
    } else {
      // Leave as is, or fallback to default
      if (!targetSeries) {
        targetSeries = "ทั่วไป";
      }
      generalCount++;
    }

    if (targetSeries !== acc.series) {
      console.log(
        `   [UPDATE] Code: ${acc.code.padEnd(12)} | Name: ${acc.name.padEnd(25)} | "${acc.series || "N/A"}" -> "${targetSeries}"`
      );
      updatedCount++;

      if (!DRY_RUN) {
        await prisma.accessory.update({
          where: { id: acc.id },
          data: { series: targetSeries },
        });
      }
    } else {
      unchangedCount++;
    }
  }

  console.log("\n📊 Migration Summary:");
  console.log(`- Total Accessories Scanned    : ${accessories.length}`);
  console.log(`- Updated Categories           : ${updatedCount}`);
  console.log(`- Unchanged Categories         : ${unchangedCount}`);
  console.log("\nDistribution of Matched Categories:");
  console.log(`- "ชุดบานเลื่อน" (Sliding)      : ${slidingCount}`);
  console.log(`- "ชุดบานเปิด, บานกระทุ้ง" (Casement): ${casementCount}`);
  console.log(`- "ชุดบานเฟี้ยม" (Bi-fold)       : ${bifoldCount}`);
  console.log(`- "ทั่วไป" / Unmatched          : ${generalCount}`);
  console.log("═══════════════════════════════════════════════════════════");
  console.log(
    DRY_RUN
      ? "🔍 DRY RUN complete — no changes were written to the database."
      : "✅ Auto-categorization migration completed successfully."
  );
  console.log("═══════════════════════════════════════════════════════════\n");
}

main()
  .catch((e) => {
    console.error("\n❌ Auto-categorization failed:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
