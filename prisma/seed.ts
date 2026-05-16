/**
 * prisma/seed.ts
 * ─────────────────────────────────────────────────────────────
 * Seed mockup data for Phase 1 — Aluminum Cost Estimation
 *
 * Catalog reference: Alumet / iConiq Sliding Series (iS-xxxx)
 *
 * Run with:  npx prisma db seed
 * ─────────────────────────────────────────────────────────────
 */

import { config } from "dotenv";
config(); // load .env so DATABASE_URL is in process.env

import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

// Prisma v7 requires a driver adapter — no more bundled engine
const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });


async function main() {
  console.log("🌱 Starting seed...\n");

  // ─────────────────────────────────────────────────────────────
  // 1. COLORS  (shared across all categories / materials)
  // ─────────────────────────────────────────────────────────────
  console.log("→ Seeding colors...");

  const colorWhite = await prisma.color.upsert({
    where: { name: "ขาว (White)" },
    update: {},
    create: {
      name: "ขาว (White)",
      hexCode: "#F5F5F5",
      sortOrder: 1,
    },
  });

  const colorBlack = await prisma.color.upsert({
    where: { name: "ดำ (Black)" },
    update: {},
    create: {
      name: "ดำ (Black)",
      hexCode: "#2C2C2C",
      sortOrder: 2,
    },
  });

  const colorWood = await prisma.color.upsert({
    where: { name: "ลายไม้ (Wood Grain)" },
    update: {},
    create: {
      name: "ลายไม้ (Wood Grain)",
      hexCode: "#8B6914",
      sortOrder: 3,
    },
  });

  console.log(
    `   ✓ ${colorWhite.name}, ${colorBlack.name}, ${colorWood.name}\n`
  );

  // ─────────────────────────────────────────────────────────────
  // 2. CATEGORIES  (brand/series)
  // ─────────────────────────────────────────────────────────────
  console.log("→ Seeding categories...");

  const catIconiq = await prisma.category.upsert({
    where: { slug: "iconiq-sliding" },
    update: {},
    create: {
      name: "iConiq Sliding Series",
      slug: "iconiq-sliding",
      description:
        "ชุดโปรไฟล์อลูมิเนียมสำหรับประตู-หน้าต่างบานเลื่อน iConiq",
      sortOrder: 1,
    },
  });

  const catEuro = await prisma.category.upsert({
    where: { slug: "alumet-euro-casement" },
    update: {},
    create: {
      name: "Alumet Euro Casement Series",
      slug: "alumet-euro-casement",
      description:
        "ชุดโปรไฟล์อลูมิเนียมสำหรับประตู-หน้าต่างบานเปิด Euro Series",
      sortOrder: 2,
    },
  });

  console.log(`   ✓ ${catIconiq.name}, ${catEuro.name}\n`);

  // ─────────────────────────────────────────────────────────────
  // 3. MATERIALS + VARIANTS  (raw aluminum profiles)
  //
  //  iConiq Sliding Series (iS-xxxx):
  //    iS-0101  เฟรมบน-ล่างบานเลื่อน ไอคอนิค       unit: เส้น
  //    iS-0102  ขอบยึดกระจกบานเลื่อน ไอคอนิค        unit: เส้น
  //    iS-0103  รางล่างบานเลื่อน 2 ร่อง ไอคอนิค     unit: เส้น
  //    iS-0104  รางบนบานเลื่อน 2 ร่อง ไอคอนิค       unit: เส้น
  //
  //  Prices (THB per เส้น, 6m length):
  //            White    Black
  //  iS-0101   185      215
  //  iS-0102   165      195
  //  iS-0103   220      255
  //  iS-0104   210      245
  //
  //  Note: Wood Grain not available for Sliding Series (sliding profiles
  //        only come in White/Black for this series).
  // ─────────────────────────────────────────────────────────────
  console.log("→ Seeding materials & variants...");

  type MaterialSeed = {
    code: string;
    name: string;
    unit: string;
    baseCost: number;
    sortOrder: number;
    variants: { colorId: string; unitCost: number }[];
  };

  const iconiqMaterials: MaterialSeed[] = [
    {
      code: "iS-0101",
      name: "เฟรมบน-ล่างบานเลื่อน ไอคอนิค",
      unit: "เส้น",
      baseCost: 185,
      sortOrder: 1,
      variants: [
        { colorId: colorWhite.id, unitCost: 185 },
        { colorId: colorBlack.id, unitCost: 215 },
      ],
    },
    {
      code: "iS-0102",
      name: "ขอบยึดกระจกบานเลื่อน ไอคอนิค",
      unit: "เส้น",
      baseCost: 165,
      sortOrder: 2,
      variants: [
        { colorId: colorWhite.id, unitCost: 165 },
        { colorId: colorBlack.id, unitCost: 195 },
      ],
    },
    {
      code: "iS-0103",
      name: "รางล่างบานเลื่อน 2 ร่อง ไอคอนิค",
      unit: "เส้น",
      baseCost: 220,
      sortOrder: 3,
      variants: [
        { colorId: colorWhite.id, unitCost: 220 },
        { colorId: colorBlack.id, unitCost: 255 },
      ],
    },
    {
      code: "iS-0104",
      name: "รางบนบานเลื่อน 2 ร่อง ไอคอนิค",
      unit: "เส้น",
      baseCost: 210,
      sortOrder: 4,
      variants: [
        { colorId: colorWhite.id, unitCost: 210 },
        { colorId: colorBlack.id, unitCost: 245 },
      ],
    },
  ];

  for (const mat of iconiqMaterials) {
    const material = await prisma.material.upsert({
      where: { code: mat.code },
      update: {
        name: mat.name,
        baseCost: mat.baseCost,
      },
      create: {
        categoryId: catIconiq.id,
        code: mat.code,
        name: mat.name,
        unit: mat.unit,
        baseCost: mat.baseCost,
        sortOrder: mat.sortOrder,
      },
    });

    for (const v of mat.variants) {
      await prisma.materialVariant.upsert({
        where: {
          materialId_colorId: {
            materialId: material.id,
            colorId: v.colorId,
          },
        },
        update: { unitCost: v.unitCost },
        create: {
          materialId: material.id,
          colorId: v.colorId,
          unitCost: v.unitCost,
        },
      });
    }

    const colors = mat.variants
      .map((v) => (v.colorId === colorWhite.id ? "White" : "Black"))
      .join(", ");
    console.log(`   ✓ [${mat.code}] ${mat.name}  (${colors})`);
  }

  // ─────────────────────────────────────────────────────────────
  // 4. SAMPLE ESTIMATION PROJECT  (demo quotation)
  //
  //  Scenario: Sliding door 2000 × 1500 mm, Black color
  //  BOM:
  //    iS-0101 × 4 pcs  (top/bottom frame × 2 panels × 2)
  //    iS-0102 × 4 pcs  (glass bead × 2 panels × 2)
  //    iS-0103 × 1 pc   (bottom track)
  //    iS-0104 × 1 pc   (top track)
  // ─────────────────────────────────────────────────────────────
  console.log("\n→ Seeding sample estimation project...");

  // Fetch the materials and black variants we just seeded
  const [m0101, m0102, m0103, m0104] = await Promise.all([
    prisma.material.findUniqueOrThrow({
      where: { code: "iS-0101" },
      include: { variants: { include: { color: true } } },
    }),
    prisma.material.findUniqueOrThrow({
      where: { code: "iS-0102" },
      include: { variants: { include: { color: true } } },
    }),
    prisma.material.findUniqueOrThrow({
      where: { code: "iS-0103" },
      include: { variants: { include: { color: true } } },
    }),
    prisma.material.findUniqueOrThrow({
      where: { code: "iS-0104" },
      include: { variants: { include: { color: true } } },
    }),
  ]);

  const getBlackVariant = (mat: typeof m0101) => {
    const v = mat.variants.find((v) => v.colorId === colorBlack.id);
    if (!v) throw new Error(`No black variant for ${mat.code}`);
    return v;
  };

  type BomLine = {
    materialId: string;
    materialVariantId: string;
    quantity: number;
    description: string;
    sortOrder: number;
    unitCost: number;
    materialCost: number;
  };

  const bomLines: BomLine[] = [
    {
      materialId: m0101.id,
      materialVariantId: getBlackVariant(m0101).id,
      quantity: 4,
      description: "เฟรมบน-ล่าง (2 บาน × บน+ล่าง)",
      sortOrder: 1,
      unitCost: getBlackVariant(m0101).unitCost,
      materialCost: getBlackVariant(m0101).unitCost * 4,
    },
    {
      materialId: m0102.id,
      materialVariantId: getBlackVariant(m0102).id,
      quantity: 4,
      description: "ขอบยึดกระจก (2 บาน × 2 ด้าน)",
      sortOrder: 2,
      unitCost: getBlackVariant(m0102).unitCost,
      materialCost: getBlackVariant(m0102).unitCost * 4,
    },
    {
      materialId: m0103.id,
      materialVariantId: getBlackVariant(m0103).id,
      quantity: 1,
      description: "รางล่าง",
      sortOrder: 3,
      unitCost: getBlackVariant(m0103).unitCost,
      materialCost: getBlackVariant(m0103).unitCost * 1,
    },
    {
      materialId: m0104.id,
      materialVariantId: getBlackVariant(m0104).id,
      quantity: 1,
      description: "รางบน",
      sortOrder: 4,
      unitCost: getBlackVariant(m0104).unitCost,
      materialCost: getBlackVariant(m0104).unitCost * 1,
    },
  ];

  const subtotal = bomLines.reduce((sum, l) => sum + l.materialCost, 0);

  const project = await prisma.estimationProject.create({
    data: {
      projectName: "ประตูบานเลื่อน – บ้านคุณสมชาย",
      customerName: "คุณสมชาย ใจดี",
      customerPhone: "081-234-5678",
      notes: "ประตูบานเลื่อน 2 บาน สีดำ",
      refWidthMm: 2000,
      refHeightMm: 1500,
      profitMarginPercent: 20,
      laborCost: 500,
      additionalCost: 0,
      discountPercent: 0,
      status: "DRAFT",
      items: {
        create: bomLines,
      },
    },
    include: { items: true },
  });

  // ─── Pretty-print the quotation summary ───────────────────────
  const withMargin = subtotal * (1 + 20 / 100);
  const finalPrice = withMargin + 500;

  console.log("\n   ✓ Sample project created:");
  console.log(`     Project  : ${project.projectName}`);
  console.log(`     Customer : ${project.customerName}`);
  console.log(
    `     Ref. dims: ${project.refWidthMm} × ${project.refHeightMm} mm`
  );
  console.log(`     Items    : ${project.items.length}`);
  console.log(`     Subtotal : ฿${subtotal.toLocaleString()}`);
  console.log(`     + Margin (20%): ฿${(subtotal * 0.2).toLocaleString()}`);
  console.log(`     + Labor  : ฿500`);
  console.log(`     ─────────────────────────────`);
  console.log(`     Final    : ฿${finalPrice.toLocaleString()}`);

  console.log("\n✅ Seed complete.\n");
}

main()
  .catch((e) => {
    console.error("❌ Seed failed:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
