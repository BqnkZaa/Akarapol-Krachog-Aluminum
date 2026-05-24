/**
 * scripts/migrate-formulas-to-cm.ts
 * ─────────────────────────────────────────────────────────────
 * ONE-OFF DATA MIGRATION: Convert seeded template formulas to cm
 *
 * WHAT THIS SCRIPT DOES:
 *   1. Targets only the standard seeded templates by their unique slug.
 *   2. Replaces millimeter formulas (e.g. H - 40) with centimeter formulas (e.g. H - 4).
 *   3. Operates completely in-place on the existing database.
 *   4. Absolutely safe: does NOT delete or overwrite any real customer data.
 *   5. Does NOT touch any user-defined custom templates.
 *
 * RUNNING THIS SCRIPT:
 *   npx tsx scripts/migrate-formulas-to-cm.ts
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

const MIGRATIONS = [
  {
    slug: "iconiq-sliding-door-2-panel",
    components: {
      "(W / 2) + 20": "(W / 2) + 2",
      "H - 40": "H - 4",
      "(W / 2) - 30": "(W / 2) - 3",
      "H - 100": "H - 10",
      "H - 30": "H - 3"
    },
    glass: {
      "(W / 2) - 50": "(W / 2) - 5",
      "H - 110": "H - 11"
    }
  },
  {
    slug: "iconiq-fixed-glazing-window",
    components: {
      "W - 40": "W - 4",
      "H - 60": "H - 6"
    },
    glass: {
      "W - 50": "W - 5",
      "H - 70": "H - 7"
    }
  },
  {
    slug: "iconiq-casement-window",
    components: {
      "W - 45": "W - 4.5",
      "H - 45": "H - 4.5",
      "W - 95": "W - 9.5",
      "H - 95": "H - 9.5"
    },
    glass: {
      "W - 105": "W - 10.5",
      "H - 105": "H - 10.5"
    }
  },
  {
    slug: "iconiq-awning-window",
    components: {
      "W - 45": "W - 4.5",
      "H - 45": "H - 4.5",
      "W - 95": "W - 9.5",
      "H - 95": "H - 9.5"
    },
    glass: {
      "W - 105": "W - 10.5",
      "H - 105": "H - 10.5"
    }
  },
  {
    slug: "smartx-sliding-2panel",
    components: {
      "W / 2 + 20": "W / 2 + 2",
      "H - 45": "H - 4.5",
      "W / 2 + 20 - 60": "W / 2 + 2 - 6"
    },
    glass: {
      "W / 2 - 30": "W / 2 - 3",
      "H - 80": "H - 8"
    }
  },
  {
    slug: "smartx-fixed-glazing",
    components: {
      "W - 10": "W - 1",
      "H - 10": "H - 1",
      "W - 40": "W - 4",
      "H - 40": "H - 4"
    },
    glass: {
      "W - 60": "W - 6",
      "H - 60": "H - 6"
    }
  },
  {
    slug: "smartx-casement",
    components: {
      "W - 30": "W - 3",
      "H - 35": "H - 3.5",
      "W - 70": "W - 7",
      "H - 70": "H - 7"
    },
    glass: {
      "W - 90": "W - 9",
      "H - 90": "H - 9"
    }
  },
  {
    slug: "smartx-awning",
    components: {
      "W - 25": "W - 2.5",
      "H - 30": "H - 3",
      "W - 65": "W - 6.5",
      "H - 65": "H - 6.5"
    },
    glass: {
      "W - 85": "W - 8.5",
      "H - 85": "H - 8.5"
    }
  },
  {
    slug: "smartx-folding-door",
    components: {
      "H - 20": "H - 2",
      "W / 2 - 20": "W / 2 - 2",
      "H - 60": "H - 6",
      "W / 2 - 60": "W / 2 - 6",
      "H - 100": "H - 10"
    },
    glass: {
      "W / 2 - 80": "W / 2 - 8",
      "H - 120": "H - 12"
    }
  }
];

async function main() {
  console.log("🚀 Starting database formula migration (mm -> cm)...");
  
  for (const m of MIGRATIONS) {
    const template = await prisma.productTemplate.findUnique({
      where: { slug: m.slug },
      include: { components: true, glassSpecifications: true }
    });

    if (!template) {
      console.log(`⚠️ Template not found for slug: ${m.slug}, skipping.`);
      continue;
    }

    console.log(`\n📄 Processing template: "${template.name}" (${m.slug})`);

    // Migrate components
    for (const comp of template.components) {
      const targetFormula = m.components[comp.formula as keyof typeof m.components];
      if (targetFormula) {
        console.log(`   [COMP] "${comp.label}": "${comp.formula}" -> "${targetFormula}"`);
        await prisma.templateComponent.update({
          where: { id: comp.id },
          data: { formula: targetFormula }
        });
      }
    }

    // Migrate glass
    for (const glass of template.glassSpecifications) {
      const updateData: any = {};
      const targetW = m.glass[glass.widthFormula as keyof typeof m.glass];
      const targetH = m.glass[glass.heightFormula as keyof typeof m.glass];

      if (targetW) {
        console.log(`   [GLASS W] "${glass.label}": "${glass.widthFormula}" -> "${targetW}"`);
        updateData.widthFormula = targetW;
      }
      if (targetH) {
        console.log(`   [GLASS H] "${glass.label}": "${glass.heightFormula}" -> "${targetH}"`);
        updateData.heightFormula = targetH;
      }

      if (Object.keys(updateData).length > 0) {
        await prisma.glassSpecification.update({
          where: { id: glass.id },
          data: updateData
        });
      }
    }
  }

  console.log("\n✅ Database formula migration completed successfully!");
}

main()
  .catch((e) => {
    console.error("❌ Migration failed:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
