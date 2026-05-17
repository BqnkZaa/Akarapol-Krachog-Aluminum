/**
 * prisma/seed.ts
 * ─────────────────────────────────────────────────────────────
 * Real production seed from Alumet iConiq Euro Series catalog
 * and official retail price list (ราคาปลีกสีสต็อก ไอคอนิค).
 *
 * Data source:
 *   - iConiq Euro Series Catalog.pdf (profiles, specs, weights)
 *   - ราคาปลีกสีสต็อก_ไอคอนิค 110569 ล่าสุด.pdf (prices per 6.4m bar)
 *
 * Key business rules:
 *   - Standard bar length: 6400mm (NOT 6000mm)
 *   - Prices are per bar (6.4m), retail, ex-VAT
 *   - Color pricing tiers: White/Black < Sahara Grey < Sahara Sand
 *
 * Run with:  npx prisma db seed
 * ─────────────────────────────────────────────────────────────
 */

import { config } from "dotenv";
config();

import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL,
});
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log("🌱 Starting Alumet iConiq Euro Series seed...\n");

  // ═══════════════════════════════════════════════════════════
  // 1. COLORS (from catalog page 25 + price list header)
  // ═══════════════════════════════════════════════════════════
  console.log("→ Seeding colors...");

  const colorWhite = await prisma.color.upsert({
    where: { name: "ขาว Milky White (8911)" },
    update: {},
    create: { name: "ขาว Milky White (8911)", hexCode: "#F5F5F0", sortOrder: 1 },
  });

  const colorBlack = await prisma.color.upsert({
    where: { name: "ดำ Midnight Black (8816)" },
    update: {},
    create: { name: "ดำ Midnight Black (8816)", hexCode: "#1C1C1C", sortOrder: 2 },
  });

  const colorSaharaGrey = await prisma.color.upsert({
    where: { name: "ซาฮาร่าเกรย์ Sapphire Grey (8820)" },
    update: {},
    create: { name: "ซาฮาร่าเกรย์ Sapphire Grey (8820)", hexCode: "#7A7D7F", sortOrder: 3 },
  });

  const colorSaharaSand = await prisma.color.upsert({
    where: { name: "ซาฮาร่าแซนด์ Jewel Sand (8515)" },
    update: {},
    create: { name: "ซาฮาร่าแซนด์ Jewel Sand (8515)", hexCode: "#C2B280", sortOrder: 4 },
  });

  console.log(`   ✓ ${colorWhite.name}`);
  console.log(`   ✓ ${colorBlack.name}`);
  console.log(`   ✓ ${colorSaharaGrey.name}`);
  console.log(`   ✓ ${colorSaharaSand.name}\n`);

  // ═══════════════════════════════════════════════════════════
  // 2. CATEGORY
  // ═══════════════════════════════════════════════════════════
  console.log("→ Seeding category...");

  const catIconiq = await prisma.category.upsert({
    where: { slug: "alumet-iconiq-euro-series" },
    update: { name: "Alumet iConiq Euro Series" },
    create: {
      name: "Alumet iConiq Euro Series",
      slug: "alumet-iconiq-euro-series",
      description: "ชุดโปรไฟล์อลูมิเนียมระบบบานเลื่อน อลูเม็ท ไอคอนิค ยูโรซีรี่ส์ — มาตรฐานยุโรป ความยาวเส้น 6.4 เมตร",
      sortOrder: 1,
    },
  });
  console.log(`   ✓ ${catIconiq.name}\n`);

  // ═══════════════════════════════════════════════════════════
  // 3. MATERIALS + COLOR VARIANTS
  //    Real prices from ราคาปลีกสีสต็อก (per 6.4m bar, ex-VAT)
  // ═══════════════════════════════════════════════════════════
  console.log("→ Seeding materials & color variants...");

  type VariantPrice = { colorId: string; unitCost: number };
  type MaterialSeed = {
    code: string;
    name: string;
    weightKgM: number;
    baseCost: number;
    sortOrder: number;
    variants: VariantPrice[];
  };

  const materials: MaterialSeed[] = [
    // ── Frame profiles ─────────────────────────────────
    {
      code: "iS-0101",
      name: "เฟรมบน-ล่างบานเลื่อน ไอคอนิค",
      weightKgM: 1.899,
      baseCost: 4185,
      sortOrder: 1,
      variants: [
        { colorId: colorWhite.id, unitCost: 4185 },
        { colorId: colorBlack.id, unitCost: 4185 },
        { colorId: colorSaharaGrey.id, unitCost: 4295 },
        { colorId: colorSaharaSand.id, unitCost: 4510 },
      ],
    },
    {
      code: "iS-0102",
      name: "เฟรมข้างบานเลื่อน ไอคอนิค",
      weightKgM: 0.869,
      baseCost: 1915,
      sortOrder: 2,
      variants: [
        { colorId: colorWhite.id, unitCost: 1915 },
        { colorId: colorBlack.id, unitCost: 1915 },
        { colorId: colorSaharaGrey.id, unitCost: 1965 },
        { colorId: colorSaharaSand.id, unitCost: 2065 },
      ],
    },
    {
      code: "iS-0113",
      name: "ตบเฟรมบนบานเลื่อน ไอคอนิค",
      weightKgM: 1.135,
      baseCost: 2505,
      sortOrder: 3,
      variants: [
        { colorId: colorWhite.id, unitCost: 2505 },
        { colorId: colorBlack.id, unitCost: 2505 },
        { colorId: colorSaharaGrey.id, unitCost: 2570 },
        { colorId: colorSaharaSand.id, unitCost: 2700 },
      ],
    },
    {
      code: "iS-0103",
      name: "ยูเสริมปีกเฟรมข้างบานเลื่อน ไอคอนิค",
      weightKgM: 0.230,
      baseCost: 520,
      sortOrder: 4,
      variants: [
        { colorId: colorWhite.id, unitCost: 520 },
        { colorId: colorBlack.id, unitCost: 520 },
        { colorId: colorSaharaGrey.id, unitCost: 535 },
        { colorId: colorSaharaSand.id, unitCost: 560 },
      ],
    },
    {
      code: "iS-0106",
      name: "กันน้ำหัวบาน ไอคอนิค",
      weightKgM: 0.243,
      baseCost: 570,
      sortOrder: 5,
      variants: [
        { colorId: colorWhite.id, unitCost: 570 },
        { colorId: colorBlack.id, unitCost: 570 },
        { colorId: colorSaharaGrey.id, unitCost: 585 },
        { colorId: colorSaharaSand.id, unitCost: 615 },
      ],
    },
    {
      code: "iS-0107",
      name: "ฝาปิดขอบปูน ไอคอนิค",
      weightKgM: 0.175,
      baseCost: 410,
      sortOrder: 6,
      variants: [
        { colorId: colorWhite.id, unitCost: 410 },
        { colorId: colorBlack.id, unitCost: 410 },
        { colorId: colorSaharaGrey.id, unitCost: 420 },
        { colorId: colorSaharaSand.id, unitCost: 445 },
      ],
    },
    {
      code: "iS-0114",
      name: "ตบธรณีบานเลื่อน ไอคอนิค",
      weightKgM: 0.322,
      baseCost: 755,
      sortOrder: 7,
      variants: [
        { colorId: colorWhite.id, unitCost: 755 },
        { colorId: colorBlack.id, unitCost: 755 },
        { colorId: colorSaharaGrey.id, unitCost: 775 },
        { colorId: colorSaharaSand.id, unitCost: 810 },
      ],
    },
    // ── Panel profiles ─────────────────────────────────
    {
      code: "iS-0201",
      name: "กรอบบานเลื่อน 2.0 เปิดคิ้ว ไอคอนิค",
      weightKgM: 1.322,
      baseCost: 2850,
      sortOrder: 10,
      variants: [
        { colorId: colorWhite.id, unitCost: 2850 },
        { colorId: colorBlack.id, unitCost: 2850 },
        { colorId: colorSaharaGrey.id, unitCost: 2920 },
        { colorId: colorSaharaSand.id, unitCost: 3070 },
      ],
    },
    {
      code: "iS-0202",
      name: "คิ้วกรอบบาน 2.0 ร่องกระจก 12.7 มม. ไอคอนิค",
      weightKgM: 0.211,
      baseCost: 475,
      sortOrder: 11,
      variants: [
        { colorId: colorWhite.id, unitCost: 475 },
        { colorId: colorBlack.id, unitCost: 475 },
        { colorId: colorSaharaGrey.id, unitCost: 490 },
        { colorId: colorSaharaSand.id, unitCost: 510 },
      ],
    },
    {
      code: "iS-0207",
      name: "ตบเกี่ยวบานเลื่อน ไอคอนิค",
      weightKgM: 0.396,
      baseCost: 850,
      sortOrder: 12,
      variants: [
        { colorId: colorWhite.id, unitCost: 850 },
        { colorId: colorBlack.id, unitCost: 850 },
        { colorId: colorSaharaGrey.id, unitCost: 870 },
        { colorId: colorSaharaSand.id, unitCost: 910 },
      ],
    },
    {
      code: "iS-0210",
      name: "ชนกลางบานเลื่อน ไอคอนิค",
      weightKgM: 0.468,
      baseCost: 1055,
      sortOrder: 13,
      variants: [
        { colorId: colorWhite.id, unitCost: 1055 },
        { colorId: colorBlack.id, unitCost: 1055 },
        { colorId: colorSaharaGrey.id, unitCost: 1080 },
        { colorId: colorSaharaSand.id, unitCost: 1135 },
      ],
    },
    {
      code: "iS-0206",
      name: "กรอบบานเลื่อน 1.5 ร่องกระจก 9.5 มม. ไอคอนิค",
      weightKgM: 1.243,
      baseCost: 2705,
      sortOrder: 14,
      variants: [
        { colorId: colorWhite.id, unitCost: 2705 },
        { colorId: colorBlack.id, unitCost: 2705 },
        { colorId: colorSaharaGrey.id, unitCost: 2775 },
        { colorId: colorSaharaSand.id, unitCost: 2915 },
      ],
    },
    // ── Fixed Glazing (iF-) profiles ───────────────────────
    {
      code: "iF-0101",
      name: "เฟรมบน-ข้างช่องแสง ไอคอนิค",
      weightKgM: 0.950,
      baseCost: 2075,
      sortOrder: 20,
      variants: [
        { colorId: colorWhite.id, unitCost: 2075 },
        { colorId: colorBlack.id, unitCost: 2075 },
        { colorId: colorSaharaGrey.id, unitCost: 2130 },
        { colorId: colorSaharaSand.id, unitCost: 2235 },
      ],
    },
    {
      code: "iF-0102",
      name: "เฟรมล่างช่องแสง ไอคอนิค",
      weightKgM: 1.077,
      baseCost: 2360,
      sortOrder: 21,
      variants: [
        { colorId: colorWhite.id, unitCost: 2360 },
        { colorId: colorBlack.id, unitCost: 2360 },
        { colorId: colorSaharaGrey.id, unitCost: 2420 },
        { colorId: colorSaharaSand.id, unitCost: 2540 },
      ],
    },
    {
      code: "iF-0103",
      name: "ซอยเฟรมช่องแสง ไอคอนิค",
      weightKgM: 1.513,
      baseCost: 3305,
      sortOrder: 22,
      variants: [
        { colorId: colorWhite.id, unitCost: 3305 },
        { colorId: colorBlack.id, unitCost: 3305 },
        { colorId: colorSaharaGrey.id, unitCost: 3390 },
        { colorId: colorSaharaSand.id, unitCost: 3560 },
      ],
    },
    {
      code: "iF-0104",
      name: "ตบช่องแสง ไอคอนิค",
      weightKgM: 0.661,
      baseCost: 1465,
      sortOrder: 23,
      variants: [
        { colorId: colorWhite.id, unitCost: 1465 },
        { colorId: colorBlack.id, unitCost: 1465 },
        { colorId: colorSaharaGrey.id, unitCost: 1500 },
        { colorId: colorSaharaSand.id, unitCost: 1575 },
      ],
    },
    // ── Shared glazing bead (iO-) ──────────────────────────
    {
      code: "iO-0203",
      name: "คิ้วกรอบบาน 12.7 ไอคอนิค",
      weightKgM: 0.222,
      baseCost: 515,
      sortOrder: 24,
      variants: [
        { colorId: colorWhite.id, unitCost: 515 },
        { colorId: colorBlack.id, unitCost: 515 },
        { colorId: colorSaharaGrey.id, unitCost: 525 },
        { colorId: colorSaharaSand.id, unitCost: 550 },
      ],
    },
    // ── Casement (iO-) profiles ─────────────────────────────
    {
      code: "iO-0101",
      name: "เฟรมประตูบานเปิด ไอคอนิค",
      weightKgM: 1.392,
      baseCost: 3060,
      sortOrder: 30,
      variants: [
        { colorId: colorWhite.id, unitCost: 3060 },
        { colorId: colorBlack.id, unitCost: 3060 },
        { colorId: colorSaharaGrey.id, unitCost: 3140 },
        { colorId: colorSaharaSand.id, unitCost: 3300 },
      ],
    },
    {
      code: "iO-0201",
      name: "กรอบบานประตูบานเปิด ไอคอนิค",
      weightKgM: 1.502,
      baseCost: 3220,
      sortOrder: 31,
      variants: [
        { colorId: colorWhite.id, unitCost: 3220 },
        { colorId: colorBlack.id, unitCost: 3220 },
        { colorId: colorSaharaGrey.id, unitCost: 3305 },
        { colorId: colorSaharaSand.id, unitCost: 3470 },
      ],
    },
    {
      code: "iO-0204",
      name: "คิ้วกรอบบาน 20 ไอคอนิค",
      weightKgM: 0.186,
      baseCost: 435,
      sortOrder: 32,
      variants: [
        { colorId: colorWhite.id, unitCost: 435 },
        { colorId: colorBlack.id, unitCost: 435 },
        { colorId: colorSaharaGrey.id, unitCost: 445 },
        { colorId: colorSaharaSand.id, unitCost: 465 },
      ],
    },
    // ── Awning (iC-) profiles ───────────────────────────────
    {
      code: "iC-0101",
      name: "เฟรมบน-ข้างกระทุ้ง ไอคอนิค",
      weightKgM: 1.062,
      baseCost: 2305,
      sortOrder: 40,
      variants: [
        { colorId: colorWhite.id, unitCost: 2305 },
        { colorId: colorBlack.id, unitCost: 2305 },
        { colorId: colorSaharaGrey.id, unitCost: 2365 },
        { colorId: colorSaharaSand.id, unitCost: 2485 },
      ],
    },
    {
      code: "iC-0102",
      name: "เฟรมล่างกระทุ้ง ไอคอนิค",
      weightKgM: 1.182,
      baseCost: 2570,
      sortOrder: 41,
      variants: [
        { colorId: colorWhite.id, unitCost: 2570 },
        { colorId: colorBlack.id, unitCost: 2570 },
        { colorId: colorSaharaGrey.id, unitCost: 2640 },
        { colorId: colorSaharaSand.id, unitCost: 2770 },
      ],
    },
    {
      code: "iC-0201",
      name: "กรอบบานกระทุ้ง ไอคอนิค",
      weightKgM: 1.067,
      baseCost: 2310,
      sortOrder: 42,
      variants: [
        { colorId: colorWhite.id, unitCost: 2310 },
        { colorId: colorBlack.id, unitCost: 2310 },
        { colorId: colorSaharaGrey.id, unitCost: 2370 },
        { colorId: colorSaharaSand.id, unitCost: 2490 },
      ],
    },
    {
      code: "iC-0105",
      name: "คิ้วช่องแสงเฟรมกระทุ้ง 20 ไอคอนิค",
      weightKgM: 0.218,
      baseCost: 510,
      sortOrder: 43,
      variants: [
        { colorId: colorWhite.id, unitCost: 510 },
        { colorId: colorBlack.id, unitCost: 510 },
        { colorId: colorSaharaGrey.id, unitCost: 520 },
        { colorId: colorSaharaSand.id, unitCost: 550 },
      ],
    },
  ];

  const materialMap: Record<string, string> = {}; // code → id

  for (const mat of materials) {
    const material = await prisma.material.upsert({
      where: { code: mat.code },
      update: { name: mat.name, baseCost: mat.baseCost },
      create: {
        categoryId: catIconiq.id,
        code: mat.code,
        name: mat.name,
        unit: "เส้น",
        baseCost: mat.baseCost,
        sortOrder: mat.sortOrder,
        description: `น้ำหนัก ${mat.weightKgM} กก./ม. — ราคาต่อเส้น 6.4 ม.`,
      },
    });
    materialMap[mat.code] = material.id;

    for (const v of mat.variants) {
      await prisma.materialVariant.upsert({
        where: { materialId_colorId: { materialId: material.id, colorId: v.colorId } },
        update: { unitCost: v.unitCost },
        create: { materialId: material.id, colorId: v.colorId, unitCost: v.unitCost },
      });
    }
    console.log(`   ✓ [${mat.code}] ${mat.name}  ฿${mat.baseCost}/เส้น`);
  }

  // ═══════════════════════════════════════════════════════════
  // 4. PRODUCT TEMPLATE: บานเลื่อนสลับ 2 บาน
  //
  // Standard 2-Panel Sliding Door (iConiq Euro Series)
  // Bar length: 6400mm, Kerf: 5mm
  //
  // Profile BOM for a 2-panel sliding (W × H):
  //   iS-0101  เฟรมบน-ล่าง (Top+Bottom Frame)  qty:2  formula: W
  //   iS-0102  เฟรมข้าง (Side Frame)            qty:2  formula: H
  //   iS-0113  ตบเฟรมบน (Top Header)            qty:1  formula: W
  //   iS-0114  ตบธรณี (Threshold)               qty:1  formula: W
  //   iS-0201  กรอบบาน 2.0 (Panel Frame Top/Bot) qty:4  formula: (W / 2) + 20
  //   iS-0201  กรอบบาน 2.0 (Panel Frame Sides)  qty:4  formula: H - 40
  //   iS-0202  คิ้วกรอบบาน (Glazing Bead Horiz) qty:4  formula: (W / 2) - 30
  //   iS-0202  คิ้วกรอบบาน (Glazing Bead Vert)  qty:4  formula: H - 100
  //   iS-0207  ตบเกี่ยว (Interlock)             qty:2  formula: H - 30
  //
  // Glass: 6mm Clear Tempered, 2 panels
  //   Width per panel:  (W / 2) - 50
  //   Height per panel: H - 110
  //   Price: 550 THB/m²
  //
  // Accessories (fixed cost per unit):
  //   ชุดล้อบานเลื่อน     qty:4  ฿350/ชุด
  //   มือจับบิด           qty:2  ฿180/อัน
  //   กุญแจล็อคบาน        qty:1  ฿280/อัน
  //   แปรงกันฝุ่น-กันลม   qty:4  ฿65/เส้น
  //   ยางกันน้ำ           qty:2  ฿85/เส้น
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding product template: บานเลื่อนสลับ 2 บาน...");

  const template = await prisma.productTemplate.upsert({
    where: { slug: "iconiq-sliding-door-2-panel" },
    update: {
      name: "บานเลื่อนสลับ 2 บาน (2-Panel Sliding Door)",
      description: "ประตูบานเลื่อนสลับ 2 บาน ไอคอนิค ยูโรซีรี่ส์ — เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 5,
    },
    create: {
      categoryId: catIconiq.id,
      name: "บานเลื่อนสลับ 2 บาน (2-Panel Sliding Door)",
      slug: "iconiq-sliding-door-2-panel",
      description: "ประตูบานเลื่อนสลับ 2 บาน ไอคอนิค ยูโรซีรี่ส์ — เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 5,
      sortOrder: 1,
    },
  });
  console.log(`   ✓ Template: ${template.name} (bar: ${template.standardBarLengthMm}mm, kerf: ${template.kerfMm}mm)`);

  // ── Delete existing children for idempotent re-seeding ────
  await prisma.templateComponent.deleteMany({ where: { templateId: template.id } });
  await prisma.glassSpecification.deleteMany({ where: { templateId: template.id } });
  await prisma.templateAccessory.deleteMany({ where: { templateId: template.id } });

  // ── Template Components ───────────────────────────────────
  type CompSeed = { code: string; label: string; formula: string; quantity: number; sortOrder: number };

  const components: CompSeed[] = [
    { code: "iS-0101", label: "เฟรมบน-ล่าง (Top/Bottom Frame)", formula: "W", quantity: 2, sortOrder: 1 },
    { code: "iS-0102", label: "เฟรมข้าง (Side Frame)", formula: "H", quantity: 2, sortOrder: 2 },
    { code: "iS-0113", label: "ตบเฟรมบน (Top Header Cover)", formula: "W", quantity: 1, sortOrder: 3 },
    { code: "iS-0114", label: "ตบธรณี (Threshold Cover)", formula: "W", quantity: 1, sortOrder: 4 },
    { code: "iS-0201", label: "กรอบบานบน-ล่าง (Panel Frame T/B)", formula: "(W / 2) + 20", quantity: 4, sortOrder: 5 },
    { code: "iS-0201", label: "กรอบบานข้าง (Panel Frame Sides)", formula: "H - 40", quantity: 4, sortOrder: 6 },
    { code: "iS-0202", label: "คิ้วกรอบบาน แนวนอน (Glazing Bead H)", formula: "(W / 2) - 30", quantity: 4, sortOrder: 7 },
    { code: "iS-0202", label: "คิ้วกรอบบาน แนวตั้ง (Glazing Bead V)", formula: "H - 100", quantity: 4, sortOrder: 8 },
    { code: "iS-0207", label: "ตบเกี่ยวบาน (Interlock)", formula: "H - 30", quantity: 2, sortOrder: 9 },
  ];

  for (const comp of components) {
    const matId = materialMap[comp.code];
    if (!matId) throw new Error(`Material ${comp.code} not found in map`);
    await prisma.templateComponent.create({
      data: {
        templateId: template.id,
        materialId: matId,
        label: comp.label,
        formula: comp.formula,
        quantity: comp.quantity,
        sortOrder: comp.sortOrder,
      },
    });
    console.log(`   ✓ Component [${comp.code}] "${comp.label}" formula="${comp.formula}" qty=${comp.quantity}`);
  }

  // ── Glass Specification ───────────────────────────────────
  await prisma.glassSpecification.create({
    data: {
      templateId: template.id,
      widthFormula: "(W / 2) - 50",
      heightFormula: "H - 110",
      panelCount: 2,
      glassType: "6mm Clear Tempered",
      pricePerSqM: 550,
    },
  });
  console.log(`   ✓ Glass: 6mm Clear Tempered, 2 panels @ ฿550/m²`);

  // ── Template Accessories ──────────────────────────────────
  type AccSeed = { name: string; quantity: number; unitCost: number; unit: string; sortOrder: number };

  const accessories: AccSeed[] = [
    { name: "ชุดล้อบานเลื่อน (Roller Set)", quantity: 4, unitCost: 350, unit: "ชุด", sortOrder: 1 },
    { name: "มือจับบิด (Twist Handle)", quantity: 2, unitCost: 180, unit: "อัน", sortOrder: 2 },
    { name: "กุญแจล็อคบาน (Panel Lock)", quantity: 1, unitCost: 280, unit: "อัน", sortOrder: 3 },
    { name: "แปรงกันฝุ่น-กันลม (Brush Seal)", quantity: 4, unitCost: 65, unit: "เส้น", sortOrder: 4 },
    { name: "ยางกันน้ำ (Weather Strip)", quantity: 2, unitCost: 85, unit: "เส้น", sortOrder: 5 },
  ];

  for (const acc of accessories) {
    await prisma.templateAccessory.create({ data: { templateId: template.id, ...acc } });
    console.log(`   ✓ Accessory: ${acc.name}  qty=${acc.quantity}  ฿${acc.unitCost}/${acc.unit}`);
  }

  // ═══════════════════════════════════════════════════════════
  // 5. TEMPLATE 2: บานช่องแสง (Fixed Glazing Window)
  //
  // A fixed, non-opening glazing panel. Uses iF- frame profiles.
  // Bar length: 6400mm, Kerf: 5mm
  //
  // Profile BOM (W × H):
  //   iF-0101  เฟรมบน (Top Frame)          qty:1  formula: W
  //   iF-0101  เฟรมข้าง (Side Frame)       qty:2  formula: H
  //   iF-0102  เฟรมล่าง (Bottom Frame)     qty:1  formula: W
  //   iF-0104  ตบช่องแสง (Cover/Trim)      qty:1  formula: W
  //   iO-0203  คิ้วกรอบบาน (Glazing Bead)  qty:2  formula: W - 40
  //   iO-0203  คิ้วกรอบบาน (Glazing Bead)  qty:2  formula: H - 60
  //
  // Glass: 6mm Clear Tempered, 1 panel
  //   Width:  W - 50
  //   Height: H - 70
  //   Price:  550 THB/m²
  //
  // Accessories:
  //   ยางกันน้ำ (Weather Strip)   qty:4  ฿85/เส้น
  //   ซิลิโคน (Silicone Sealant) qty:1  ฿120/หลอด
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding product template: บานช่องแสง (Fixed Glazing Window)...");

  const templateFixed = await prisma.productTemplate.upsert({
    where: { slug: "iconiq-fixed-glazing-window" },
    update: {
      name: "บานช่องแสง (Fixed Glazing Window)",
      description: "หน้าต่างช่องแสงติดตาย ไอคอนิค ยูโรซีรี่ส์ — ไม่เปิด เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 5,
    },
    create: {
      categoryId: catIconiq.id,
      name: "บานช่องแสง (Fixed Glazing Window)",
      slug: "iconiq-fixed-glazing-window",
      description: "หน้าต่างช่องแสงติดตาย ไอคอนิค ยูโรซีรี่ส์ — ไม่เปิด เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 5,
      sortOrder: 2,
    },
  });
  console.log(`   ✓ Template: ${templateFixed.name} (bar: ${templateFixed.standardBarLengthMm}mm, kerf: ${templateFixed.kerfMm}mm)`);

  // ── Delete existing children for idempotent re-seeding ────
  await prisma.templateComponent.deleteMany({ where: { templateId: templateFixed.id } });
  await prisma.glassSpecification.deleteMany({ where: { templateId: templateFixed.id } });
  await prisma.templateAccessory.deleteMany({ where: { templateId: templateFixed.id } });

  // ── Fixed Glazing Components ──────────────────────────────
  const fixedComponents: CompSeed[] = [
    { code: "iF-0101", label: "เฟรมบน (Top Frame)",                   formula: "W",      quantity: 1, sortOrder: 1 },
    { code: "iF-0101", label: "เฟรมข้าง (Side Frame)",                formula: "H",      quantity: 2, sortOrder: 2 },
    { code: "iF-0102", label: "เฟรมล่าง (Bottom Frame)",              formula: "W",      quantity: 1, sortOrder: 3 },
    { code: "iF-0104", label: "ตบช่องแสง (Trim Cover)",              formula: "W",      quantity: 1, sortOrder: 4 },
    { code: "iO-0203", label: "คิ้วกรอบบาน แนวนอน (Glazing Bead H)", formula: "W - 40", quantity: 2, sortOrder: 5 },
    { code: "iO-0203", label: "คิ้วกรอบบาน แนวตั้ง (Glazing Bead V)", formula: "H - 60", quantity: 2, sortOrder: 6 },
  ];

  for (const comp of fixedComponents) {
    const matId = materialMap[comp.code];
    if (!matId) throw new Error(`Material ${comp.code} not found in map`);
    await prisma.templateComponent.create({
      data: {
        templateId: templateFixed.id,
        materialId: matId,
        label: comp.label,
        formula: comp.formula,
        quantity: comp.quantity,
        sortOrder: comp.sortOrder,
      },
    });
    console.log(`   ✓ Component [${comp.code}] "${comp.label}" formula="${comp.formula}" qty=${comp.quantity}`);
  }

  // ── Glass Specification (Fixed — 1 panel, full opening) ───
  await prisma.glassSpecification.create({
    data: {
      templateId: templateFixed.id,
      widthFormula: "W - 50",
      heightFormula: "H - 70",
      panelCount: 1,
      glassType: "6mm Clear Tempered",
      pricePerSqM: 550,
    },
  });
  console.log(`   ✓ Glass: 6mm Clear Tempered, 1 panel @ ฿550/m²`);

  // ── Fixed Glazing Accessories ─────────────────────────────
  const fixedAccessories: AccSeed[] = [
    { name: "ยางกันน้ำ (Weather Strip)",     quantity: 4, unitCost: 85,  unit: "เส้น",   sortOrder: 1 },
    { name: "ซิลิโคน (Silicone Sealant)",   quantity: 1, unitCost: 120, unit: "หลอด", sortOrder: 2 },
  ];

  for (const acc of fixedAccessories) {
    await prisma.templateAccessory.create({ data: { templateId: templateFixed.id, ...acc } });
    console.log(`   ✓ Accessory: ${acc.name}  qty=${acc.quantity}  ฿${acc.unitCost}/${acc.unit}`);
  }

  // ═══════════════════════════════════════════════════════════
  // 6. TEMPLATE 3: บานเปิด (Casement Window)
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding product template: บานเปิด (Casement Window)...");

  const templateCasement = await prisma.productTemplate.upsert({
    where: { slug: "iconiq-casement-window" },
    update: {
      name: "บานเปิด (Casement Window)",
      description: "หน้าต่าง/ประตูบานเปิด ไอคอนิค ยูโรซีรี่ส์ — บานพับ เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 5,
    },
    create: {
      categoryId: catIconiq.id,
      name: "บานเปิด (Casement Window)",
      slug: "iconiq-casement-window",
      description: "หน้าต่าง/ประตูบานเปิด ไอคอนิค ยูโรซีรี่ส์ — บานพับ เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 5,
      sortOrder: 3,
    },
  });
  console.log(`   ✓ Template: ${templateCasement.name}`);

  await prisma.templateComponent.deleteMany({ where: { templateId: templateCasement.id } });
  await prisma.glassSpecification.deleteMany({ where: { templateId: templateCasement.id } });
  await prisma.templateAccessory.deleteMany({ where: { templateId: templateCasement.id } });

  const casementComponents: CompSeed[] = [
    { code: "iO-0101", label: "เฟรมบน-ล่าง (Frame Top/Bottom)",     formula: "W",      quantity: 2, sortOrder: 1 },
    { code: "iO-0101", label: "เฟรมข้าง (Frame Sides)",             formula: "H",      quantity: 2, sortOrder: 2 },
    { code: "iO-0201", label: "กรอบบานบน-ล่าง (Sash Top/Bottom)",   formula: "W - 45", quantity: 2, sortOrder: 3 },
    { code: "iO-0201", label: "กรอบบานข้าง (Sash Sides)",           formula: "H - 45", quantity: 2, sortOrder: 4 },
    { code: "iO-0203", label: "คิ้วกรอบบาน แนวนอน (Glazing Bead H)", formula: "W - 95", quantity: 2, sortOrder: 5 },
    { code: "iO-0203", label: "คิ้วกรอบบาน แนวตั้ง (Glazing Bead V)", formula: "H - 95", quantity: 2, sortOrder: 6 },
  ];

  for (const comp of casementComponents) {
    const matId = materialMap[comp.code];
    if (!matId) throw new Error(`Material ${comp.code} not found in map`);
    await prisma.templateComponent.create({
      data: {
        templateId: templateCasement.id,
        materialId: matId,
        label: comp.label,
        formula: comp.formula,
        quantity: comp.quantity,
        sortOrder: comp.sortOrder,
      },
    });
    console.log(`   ✓ Component [${comp.code}] "${comp.label}" formula="${comp.formula}" qty=${comp.quantity}`);
  }

  await prisma.glassSpecification.create({
    data: {
      templateId: templateCasement.id,
      widthFormula: "W - 105",
      heightFormula: "H - 105",
      panelCount: 1,
      glassType: "6mm Clear Tempered",
      pricePerSqM: 550,
    },
  });
  console.log(`   ✓ Glass: 6mm Clear Tempered, 1 panel @ ฿550/m²`);

  const casementAccessories: AccSeed[] = [
    { name: "บานพับ 4 นิ้ว (4\" Hinge)",         quantity: 3, unitCost: 120, unit: "อัน",   sortOrder: 1 },
    { name: "มือจับบิด (Handle)",                quantity: 1, unitCost: 280, unit: "อัน",   sortOrder: 2 },
    { name: "มัลติพอยท์ล็อก (Multi-point Lock)", quantity: 1, unitCost: 850, unit: "ชุด",   sortOrder: 3 },
    { name: "ยางกันน้ำ (Weather Strip)",          quantity: 4, unitCost: 85,  unit: "เส้น",  sortOrder: 4 },
  ];

  for (const acc of casementAccessories) {
    await prisma.templateAccessory.create({ data: { templateId: templateCasement.id, ...acc } });
    console.log(`   ✓ Accessory: ${acc.name}  qty=${acc.quantity}  ฿${acc.unitCost}/${acc.unit}`);
  }

  // ═══════════════════════════════════════════════════════════
  // 7. TEMPLATE 4: บานกระทุ้ง (Awning Window)
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding product template: บานกระทุ้ง (Awning Window)...");

  const templateAwning = await prisma.productTemplate.upsert({
    where: { slug: "iconiq-awning-window" },
    update: {
      name: "บานกระทุ้ง (Awning Window)",
      description: "หน้าต่างบานกระทุ้ง ไอคอนิค ยูโรซีรี่ส์ — เปิดออกด้านบน เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 5,
    },
    create: {
      categoryId: catIconiq.id,
      name: "บานกระทุ้ง (Awning Window)",
      slug: "iconiq-awning-window",
      description: "หน้าต่างบานกระทุ้ง ไอคอนิค ยูโรซีรี่ส์ — เปิดออกด้านบน เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 5,
      sortOrder: 4,
    },
  });
  console.log(`   ✓ Template: ${templateAwning.name}`);

  await prisma.templateComponent.deleteMany({ where: { templateId: templateAwning.id } });
  await prisma.glassSpecification.deleteMany({ where: { templateId: templateAwning.id } });
  await prisma.templateAccessory.deleteMany({ where: { templateId: templateAwning.id } });

  const awningComponents: CompSeed[] = [
    { code: "iC-0101", label: "เฟรมบน (Top Frame)",                     formula: "W",      quantity: 1, sortOrder: 1 },
    { code: "iC-0101", label: "เฟรมข้าง (Side Frame)",                  formula: "H",      quantity: 2, sortOrder: 2 },
    { code: "iC-0102", label: "เฟรมล่าง (Bottom Frame)",                formula: "W",      quantity: 1, sortOrder: 3 },
    { code: "iC-0201", label: "กรอบบานบน-ล่าง (Sash Top/Bottom)",       formula: "W - 45", quantity: 2, sortOrder: 4 },
    { code: "iC-0201", label: "กรอบบานข้าง (Sash Sides)",               formula: "H - 45", quantity: 2, sortOrder: 5 },
    { code: "iC-0105", label: "คิ้วช่องแสง แนวนอน (Glazing Bead H)",    formula: "W - 95", quantity: 2, sortOrder: 6 },
    { code: "iC-0105", label: "คิ้วช่องแสง แนวตั้ง (Glazing Bead V)",    formula: "H - 95", quantity: 2, sortOrder: 7 },
  ];

  for (const comp of awningComponents) {
    const matId = materialMap[comp.code];
    if (!matId) throw new Error(`Material ${comp.code} not found in map`);
    await prisma.templateComponent.create({
      data: {
        templateId: templateAwning.id,
        materialId: matId,
        label: comp.label,
        formula: comp.formula,
        quantity: comp.quantity,
        sortOrder: comp.sortOrder,
      },
    });
    console.log(`   ✓ Component [${comp.code}] "${comp.label}" formula="${comp.formula}" qty=${comp.quantity}`);
  }

  await prisma.glassSpecification.create({
    data: {
      templateId: templateAwning.id,
      widthFormula: "W - 105",
      heightFormula: "H - 105",
      panelCount: 1,
      glassType: "6mm Clear Tempered",
      pricePerSqM: 550,
    },
  });
  console.log(`   ✓ Glass: 6mm Clear Tempered, 1 panel @ ฿550/m²`);

  const awningAccessories: AccSeed[] = [
    { name: "บานพับค้าง Friction Stay (10\")", quantity: 2, unitCost: 350, unit: "อัน",   sortOrder: 1 },
    { name: "มือจับบิด (Handle)",              quantity: 1, unitCost: 180, unit: "อัน",   sortOrder: 2 },
    { name: "ยางกันน้ำ (Weather Strip)",       quantity: 4, unitCost: 85,  unit: "เส้น",  sortOrder: 3 },
  ];

  for (const acc of awningAccessories) {
    await prisma.templateAccessory.create({ data: { templateId: templateAwning.id, ...acc } });
    console.log(`   ✓ Accessory: ${acc.name}  qty=${acc.quantity}  ฿${acc.unitCost}/${acc.unit}`);
  }

  // ═══════════════════════════════════════════════════════════
  // SUMMARY
  // ═══════════════════════════════════════════════════════════
  console.log("\n═══════════════════════════════════════════════════════════");
  console.log("📊 Seed summary:");
  console.log(`   Colors         : 4 (ขาว, ดำ, ซาฮาร่าเกรย์, ซาฮาร่าแซนด์)`);
  console.log(`   Category       : Alumet iConiq Euro Series`);
  console.log(`   Materials      : ${materials.length} profiles, 4 color variants each`);
  console.log(`   Templates      : 4`);
  console.log(`     1. ${template.name}  (${components.length} components)`);
  console.log(`     2. ${templateFixed.name}  (${fixedComponents.length} components)`);
  console.log(`     3. ${templateCasement.name}  (${casementComponents.length} components)`);
  console.log(`     4. ${templateAwning.name}  (${awningComponents.length} components)`);
  console.log(`   Bar Length     : 6400mm (imported standard)`);
  console.log(`   Price Effective: 15 พ.ค. 2569 (ex-VAT)`);
  console.log("═══════════════════════════════════════════════════════════");
  console.log("\n✅ Alumet iConiq Euro Series seed complete.\n");
}

main()
  .catch((e) => {
    console.error("❌ Seed failed:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
