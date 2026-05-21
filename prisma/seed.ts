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

  const colorWood = await prisma.color.upsert({
    where: { name: "ลายไม้ Wood Pattern" },
    update: {},
    create: { name: "ลายไม้ Wood Pattern", hexCode: "#7B5B3A", sortOrder: 5 },
  });

  const colorSilver = await prisma.color.upsert({
    where: { name: "เงิน Silver" },
    update: {},
    create: { name: "เงิน Silver", hexCode: "#C0C0C0", sortOrder: 6 },
  });

  console.log(`   ✓ ${colorWhite.name}`);
  console.log(`   ✓ ${colorBlack.name}`);
  console.log(`   ✓ ${colorSaharaGrey.name}`);
  console.log(`   ✓ ${colorSaharaSand.name}`);
  console.log(`   ✓ ${colorWood.name}`);
  console.log(`   ✓ ${colorSilver.name}\n`);

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
    // ── New iConiq profiles from ราคาปลีกสีสต็อก_ไอคอนิค 110569 ──
    {
      code: "iS-0105",
      name: "ฝาปิดระบายน ้าหน้าเฟรม ไอคอนิค",
      weightKgM: 0,
      baseCost: 135,
      sortOrder: 102,
      variants: [{ colorId: colorWhite.id, unitCost: 135 }, { colorId: colorBlack.id, unitCost: 135 }, { colorId: colorSaharaGrey.id, unitCost: 135 }, { colorId: colorSaharaSand.id, unitCost: 145 }],
    },
    {
      code: "iS-0108",
      name: "เฟรมบน-ล่าง บานเลื่อนรางเดี่ยว ไอคอนิค",
      weightKgM: 0,
      baseCost: 1565,
      sortOrder: 105,
      variants: [{ colorId: colorWhite.id, unitCost: 1565 }, { colorId: colorBlack.id, unitCost: 1565 }, { colorId: colorSaharaGrey.id, unitCost: 1605 }, { colorId: colorSaharaSand.id, unitCost: 1685 }],
    },
    {
      code: "iS-0109",
      name: "เฟรมข้างบานเลื่อนรางเดี่ยว ไอคอนิค",
      weightKgM: 0,
      baseCost: 1010,
      sortOrder: 106,
      variants: [{ colorId: colorWhite.id, unitCost: 1010 }, { colorId: colorBlack.id, unitCost: 1010 }, { colorId: colorSaharaGrey.id, unitCost: 1035 }, { colorId: colorSaharaSand.id, unitCost: 1085 }],
    },
    {
      code: "iS-0111",
      name: "ต่อเฟรมบนล่างบานเลื่อน ไอคอนิค",
      weightKgM: 0,
      baseCost: 1945,
      sortOrder: 108,
      variants: [{ colorId: colorWhite.id, unitCost: 1945 }, { colorId: colorBlack.id, unitCost: 1945 }, { colorId: colorSaharaGrey.id, unitCost: 1995 }, { colorId: colorSaharaSand.id, unitCost: 2090 }],
    },
    {
      code: "iS-0112",
      name: "ตัวต่อเฟรมฝ่ังใน บานเลื่อน ไอคอนิค",
      weightKgM: 0,
      baseCost: 1120,
      sortOrder: 109,
      variants: [{ colorId: colorWhite.id, unitCost: 1120 }, { colorId: colorBlack.id, unitCost: 1120 }, { colorId: colorSaharaGrey.id, unitCost: 1145 }, { colorId: colorSaharaSand.id, unitCost: 1205 }],
    },
    {
      code: "iS-0116",
      name: "เสริมช่องแสงเฟรมข้างบานเลื่อน ไอคอนิค",
      weightKgM: 0,
      baseCost: 1160,
      sortOrder: 111,
      variants: [{ colorId: colorWhite.id, unitCost: 1160 }, { colorId: colorBlack.id, unitCost: 1160 }, { colorId: colorSaharaGrey.id, unitCost: 1190 }, { colorId: colorSaharaSand.id, unitCost: 1250 }],
    },
    {
      code: "iS-0117",
      name: "ตบช่องแสงล่างบานเลื่อน ไอคอนิค",
      weightKgM: 0,
      baseCost: 1695,
      sortOrder: 112,
      variants: [{ colorId: colorWhite.id, unitCost: 1695 }, { colorId: colorBlack.id, unitCost: 1695 }, { colorId: colorSaharaGrey.id, unitCost: 1740 }, { colorId: colorSaharaSand.id, unitCost: 1825 }],
    },
    {
      code: "iS-0118",
      name: "เฟรมบานเลื่อนภายใน 3 ราง ไอคอนิค",
      weightKgM: 0,
      baseCost: 1865,
      sortOrder: 113,
      variants: [{ colorId: colorWhite.id, unitCost: 1865 }, { colorId: colorBlack.id, unitCost: 1865 }, { colorId: colorSaharaGrey.id, unitCost: 1910 }, { colorId: colorSaharaSand.id, unitCost: 2010 }],
    },
    {
      code: "iS-0119",
      name: "ต่อรางเดียวบานเลื่อนภายในไอคอนิค",
      weightKgM: 0,
      baseCost: 805,
      sortOrder: 114,
      variants: [{ colorId: colorWhite.id, unitCost: 805 }, { colorId: colorBlack.id, unitCost: 805 }, { colorId: colorSaharaGrey.id, unitCost: 825 }, { colorId: colorSaharaSand.id, unitCost: 865 }],
    },
    {
      code: "iS-0120",
      name: "อเเดปเตอร์ต่อเฟรมล่างบานเลื่อนภายใน",
      weightKgM: 0,
      baseCost: 370,
      sortOrder: 115,
      variants: [{ colorId: colorWhite.id, unitCost: 370 }, { colorId: colorBlack.id, unitCost: 370 }, { colorId: colorSaharaGrey.id, unitCost: 380 }, { colorId: colorSaharaSand.id, unitCost: 400 }],
    },
    {
      code: "iS-0203",
      name: "คิ้วกรอบบาน 2.0 ร่องกระจก 16 มม. ไอคอนิค",
      weightKgM: 0,
      baseCost: 410,
      sortOrder: 118,
      variants: [{ colorId: colorWhite.id, unitCost: 410 }, { colorId: colorBlack.id, unitCost: 410 }, { colorId: colorSaharaGrey.id, unitCost: 420 }, { colorId: colorSaharaSand.id, unitCost: 445 }],
    },
    {
      code: "iS-0204",
      name: "คิ้วกรอบบาน 2.0 ร่องกระจก 23.5 มม. ไอคอนิค",
      weightKgM: 0,
      baseCost: 270,
      sortOrder: 119,
      variants: [{ colorId: colorWhite.id, unitCost: 270 }, { colorId: colorBlack.id, unitCost: 270 }, { colorId: colorSaharaGrey.id, unitCost: 280 }, { colorId: colorSaharaSand.id, unitCost: 290 }],
    },
    {
      code: "iS-0208",
      name: "ตบเกี่ยว 2 ทางบานเลื่อน ไอคอนิค",
      weightKgM: 0,
      baseCost: 1330,
      sortOrder: 121,
      variants: [{ colorId: colorWhite.id, unitCost: 1330 }, { colorId: colorBlack.id, unitCost: 1330 }, { colorId: colorSaharaGrey.id, unitCost: 1360 }, { colorId: colorSaharaSand.id, unitCost: 1430 }],
    },
    {
      code: "iS-0216",
      name: "กรอบบานเลื่อน 2.0 ร่องกระจก 12.7 มม. ไอคอนิค",
      weightKgM: 0,
      baseCost: 3210,
      sortOrder: 123,
      variants: [{ colorId: colorWhite.id, unitCost: 3210 }, { colorId: colorBlack.id, unitCost: 3210 }, { colorId: colorSaharaGrey.id, unitCost: 3295 }, { colorId: colorSaharaSand.id, unitCost: 3460 }],
    },
    {
      code: "iS-0209",
      name: "ฝาปิดสกรูตบเกี่ยว ไอคอนิค",
      weightKgM: 0,
      baseCost: 110,
      sortOrder: 124,
      variants: [{ colorId: colorWhite.id, unitCost: 110 }, { colorId: colorBlack.id, unitCost: 110 }, { colorId: colorSaharaGrey.id, unitCost: 115 }, { colorId: colorSaharaSand.id, unitCost: 120 }],
    },
    {
      code: "iS-0211",
      name: "ซอยกรอบบานเลื่อน ไอคอนิค",
      weightKgM: 0,
      baseCost: 1895,
      sortOrder: 125,
      variants: [{ colorId: colorWhite.id, unitCost: 1895 }, { colorId: colorBlack.id, unitCost: 1895 }, { colorId: colorSaharaGrey.id, unitCost: 1940 }, { colorId: colorSaharaSand.id, unitCost: 2040 }],
    },
    {
      code: "iS-0212",
      name: "อเเดปเตอร์ต่อมุมบานล็อก ไอคอนิค",
      weightKgM: 0,
      baseCost: 1750,
      sortOrder: 126,
      variants: [{ colorId: colorWhite.id, unitCost: 1750 }, { colorId: colorBlack.id, unitCost: 1750 }, { colorId: colorSaharaGrey.id, unitCost: 1795 }, { colorId: colorSaharaSand.id, unitCost: 1885 }],
    },
    {
      code: "iS-0213",
      name: "อเเดปเตอร์ต่อมุมบานรอง ไอคอนิค",
      weightKgM: 0,
      baseCost: 1350,
      sortOrder: 127,
      variants: [{ colorId: colorWhite.id, unitCost: 1350 }, { colorId: colorBlack.id, unitCost: 1350 }, { colorId: colorSaharaGrey.id, unitCost: 1385 }, { colorId: colorSaharaSand.id, unitCost: 1450 }],
    },
    {
      code: "iC-0103",
      name: "ซอยเฟรมกระทุ้ง ไอคอนิค",
      weightKgM: 0,
      baseCost: 3595,
      sortOrder: 129,
      variants: [{ colorId: colorWhite.id, unitCost: 3595 }, { colorId: colorBlack.id, unitCost: 3595 }, { colorId: colorSaharaGrey.id, unitCost: 3690 }, { colorId: colorSaharaSand.id, unitCost: 3875 }],
    },
    {
      code: "iO-0102",
      name: "เสริมธรณีเฟรมกระทุ้ง ไอคอนิค",
      weightKgM: 0,
      baseCost: 1150,
      sortOrder: 130,
      variants: [{ colorId: colorWhite.id, unitCost: 1150 }, { colorId: colorBlack.id, unitCost: 1150 }, { colorId: colorSaharaGrey.id, unitCost: 1180 }, { colorId: colorSaharaSand.id, unitCost: 1240 }],
    },
    {
      code: "SC-X104",
      name: "ตบเฟรมบานกระทุ้ง สมาร์ท เอ็กซ์",
      weightKgM: 0,
      baseCost: 1735,
      sortOrder: 131,
      variants: [{ colorId: colorWhite.id, unitCost: 1735 }, { colorId: colorBlack.id, unitCost: 1735 }, { colorId: colorSaharaGrey.id, unitCost: 1780 }, { colorId: colorSaharaSand.id, unitCost: 1870 }],
    },
    {
      code: "SC-X105",
      name: "ฝาปิดร่อง C-18 สมาร์ท เอ็กซ์",
      weightKgM: 0,
      baseCost: 125,
      sortOrder: 132,
      variants: [{ colorId: colorWhite.id, unitCost: 125 }, { colorId: colorBlack.id, unitCost: 125 }, { colorId: colorSaharaGrey.id, unitCost: 130 }, { colorId: colorSaharaSand.id, unitCost: 135 }],
    },
    {
      code: "SC-X106",
      name: "เสริมช่องแสงเฟรมบานกระทุ้ง สมาร์ท เอ็กซ์",
      weightKgM: 0,
      baseCost: 935,
      sortOrder: 133,
      variants: [{ colorId: colorWhite.id, unitCost: 935 }, { colorId: colorBlack.id, unitCost: 935 }, { colorId: colorSaharaGrey.id, unitCost: 960 }, { colorId: colorSaharaSand.id, unitCost: 1010 }],
    },
    {
      code: "iC-0106",
      name: "คิ้วช่องแสงเฟรมกระทุ้ง 32.5 ไอคอนิค",
      weightKgM: 0,
      baseCost: 365,
      sortOrder: 134,
      variants: [{ colorId: colorWhite.id, unitCost: 365 }, { colorId: colorBlack.id, unitCost: 365 }, { colorId: colorSaharaGrey.id, unitCost: 370 }, { colorId: colorSaharaSand.id, unitCost: 390 }],
    },
    {
      code: "iO-0202",
      name: "ซอยกรอบประตู ไอคอนิค",
      weightKgM: 0,
      baseCost: 2160,
      sortOrder: 135,
      variants: [{ colorId: colorWhite.id, unitCost: 2160 }, { colorId: colorBlack.id, unitCost: 2160 }, { colorId: colorSaharaGrey.id, unitCost: 2215 }, { colorId: colorSaharaSand.id, unitCost: 2330 }],
    },
    {
      code: "iC-0202",
      name: "ซอยกรอบบานกระทุ้ง ไอคอนิค",
      weightKgM: 0,
      baseCost: 1675,
      sortOrder: 136,
      variants: [{ colorId: colorWhite.id, unitCost: 1675 }, { colorId: colorBlack.id, unitCost: 1675 }, { colorId: colorSaharaGrey.id, unitCost: 1720 }, { colorId: colorSaharaSand.id, unitCost: 1805 }],
    },
    {
      code: "iO-0205",
      name: "คิ้วกรอบบาน 33.5 ไอคอนิค",
      weightKgM: 0,
      baseCost: 310,
      sortOrder: 137,
      variants: [{ colorId: colorWhite.id, unitCost: 310 }, { colorId: colorBlack.id, unitCost: 310 }, { colorId: colorSaharaGrey.id, unitCost: 315 }, { colorId: colorSaharaSand.id, unitCost: 330 }],
    },
    {
      code: "iO-0206",
      name: "เสริมขวางล่างประตูบานเปิด ไอคอนิค",
      weightKgM: 0,
      baseCost: 760,
      sortOrder: 138,
      variants: [{ colorId: colorWhite.id, unitCost: 760 }, { colorId: colorBlack.id, unitCost: 760 }, { colorId: colorSaharaGrey.id, unitCost: 780 }, { colorId: colorSaharaSand.id, unitCost: 820 }],
    },
    {
      code: "iO-0207",
      name: "ฉากขย ้ามุม ไอคอนิค",
      weightKgM: 0,
      baseCost: 2735,
      sortOrder: 139,
      variants: [{ colorId: colorWhite.id, unitCost: 2735 }, { colorId: colorBlack.id, unitCost: 2735 }],
    },
    {
      code: "SC-X202",
      name: "เสริมมุ้งบานกระทุ้ง สมาร์ท เอ็กซ์",
      weightKgM: 0,
      baseCost: 375,
      sortOrder: 140,
      variants: [{ colorId: colorWhite.id, unitCost: 375 }, { colorId: colorBlack.id, unitCost: 375 }, { colorId: colorSaharaGrey.id, unitCost: 380 }, { colorId: colorSaharaSand.id, unitCost: 400 }],
    },
    {
      code: "030038",
      name: "ก้านสไลด์ มัตติพอยท์ล็อก",
      weightKgM: 0,
      baseCost: 290,
      sortOrder: 141,
      variants: [{ colorId: colorWhite.id, unitCost: 290 }, { colorId: colorBlack.id, unitCost: 290 }, { colorId: colorSaharaSand.id, unitCost: 315 }],
    },
    {
      code: "iO-0208",
      name: "ลูกฟูกเรียบ 2 หน้า หนา 30 มม.",
      weightKgM: 0,
      baseCost: 3030,
      sortOrder: 142,
      variants: [{ colorId: colorWhite.id, unitCost: 3030 }, { colorId: colorBlack.id, unitCost: 3030 }, { colorId: colorSaharaGrey.id, unitCost: 3110 }, { colorId: colorSaharaSand.id, unitCost: 2690 }],
    },
    {
      code: "iO-0209",
      name: "กล่องระแนง 25x25 มีรูสกรู ไอคอนิค",
      weightKgM: 0,
      baseCost: 865,
      sortOrder: 143,
      variants: [{ colorId: colorWhite.id, unitCost: 865 }, { colorId: colorBlack.id, unitCost: 865 }, { colorId: colorSaharaGrey.id, unitCost: 885 }, { colorId: colorSaharaSand.id, unitCost: 930 }],
    },
    {
      code: "iO-0210",
      name: "เฟรมระแนง 30x11 ไอคนิค",
      weightKgM: 0,
      baseCost: 575,
      sortOrder: 144,
      variants: [{ colorId: colorWhite.id, unitCost: 575 }, { colorId: colorBlack.id, unitCost: 575 }, { colorId: colorSaharaGrey.id, unitCost: 590 }, { colorId: colorSaharaSand.id, unitCost: 615 }],
    },
    {
      code: "iC-0107",
      name: "เฟรมบน-ข้างกระทุ้ง ซีกรู๊ฟนอก ไอคอนิค",
      weightKgM: 0,
      baseCost: 2250,
      sortOrder: 145,
      variants: [{ colorId: colorWhite.id, unitCost: 2250 }, { colorId: colorBlack.id, unitCost: 2250 }, { colorId: colorSaharaGrey.id, unitCost: 2310 }, { colorId: colorSaharaSand.id, unitCost: 2425 }],
    },
    {
      code: "iC-0108",
      name: "เฟรมล่างกระทุ้ง ซีกรู๊ฟนอก ไอคอนิค",
      weightKgM: 0,
      baseCost: 2520,
      sortOrder: 146,
      variants: [{ colorId: colorWhite.id, unitCost: 2520 }, { colorId: colorBlack.id, unitCost: 2520 }, { colorId: colorSaharaGrey.id, unitCost: 2585 }, { colorId: colorSaharaSand.id, unitCost: 2715 }],
    },
    {
      code: "iC-0109",
      name: "ซอยเฟรมกระทุ้ง ซีกรู๊ฟนอก ไอคอนิค",
      weightKgM: 0,
      baseCost: 3470,
      sortOrder: 147,
      variants: [{ colorId: colorWhite.id, unitCost: 3470 }, { colorId: colorBlack.id, unitCost: 3470 }, { colorId: colorSaharaGrey.id, unitCost: 3560 }, { colorId: colorSaharaSand.id, unitCost: 3740 }],
    },
    {
      code: "iC-0110",
      name: "ตบเฟรมกระทุ้ง ซีกรู๊ฟนอก ไอคอนิค",
      weightKgM: 0,
      baseCost: 1885,
      sortOrder: 148,
      variants: [{ colorId: colorWhite.id, unitCost: 1885 }, { colorId: colorBlack.id, unitCost: 1885 }, { colorId: colorSaharaGrey.id, unitCost: 1935 }, { colorId: colorSaharaSand.id, unitCost: 2030 }],
    },
  ];

  const materialMap: Record<string, string>
 = {}; // code → id

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
  //   Price: 51.10 THB/sq.ft
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
      kerfMm: 0,
    },
    create: {
      categoryId: catIconiq.id,
      name: "บานเลื่อนสลับ 2 บาน (2-Panel Sliding Door)",
      slug: "iconiq-sliding-door-2-panel",
      description: "ประตูบานเลื่อนสลับ 2 บาน ไอคอนิค ยูโรซีรี่ส์ — เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 0,
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
      pricePerSqM: 51.10,
    },
  });
  console.log(`   ✓ Glass: 6mm Clear Tempered, 2 panels @ ฿51.10/sq.ft`);

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
  //   Price:  51.10 THB/sq.ft
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
      kerfMm: 0,
    },
    create: {
      categoryId: catIconiq.id,
      name: "บานช่องแสง (Fixed Glazing Window)",
      slug: "iconiq-fixed-glazing-window",
      description: "หน้าต่างช่องแสงติดตาย ไอคอนิค ยูโรซีรี่ส์ — ไม่เปิด เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 0,
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
      pricePerSqM: 51.10,
    },
  });
  console.log(`   ✓ Glass: 6mm Clear Tempered, 1 panel @ ฿51.10/sq.ft`);

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
      kerfMm: 0,
    },
    create: {
      categoryId: catIconiq.id,
      name: "บานเปิด (Casement Window)",
      slug: "iconiq-casement-window",
      description: "หน้าต่าง/ประตูบานเปิด ไอคอนิค ยูโรซีรี่ส์ — บานพับ เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 0,
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
      pricePerSqM: 51.10,
    },
  });
  console.log(`   ✓ Glass: 6mm Clear Tempered, 1 panel @ ฿51.10/sq.ft`);

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
      kerfMm: 0,
    },
    create: {
      categoryId: catIconiq.id,
      name: "บานกระทุ้ง (Awning Window)",
      slug: "iconiq-awning-window",
      description: "หน้าต่างบานกระทุ้ง ไอคอนิค ยูโรซีรี่ส์ — เปิดออกด้านบน เส้นมาตรฐาน 6.4 ม.",
      standardBarLengthMm: 6400,
      kerfMm: 0,
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
      pricePerSqM: 51.10,
    },
  });
  console.log(`   ✓ Glass: 6mm Clear Tempered, 1 panel @ ฿51.10/sq.ft`);

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
  // 8. CATEGORY: Alumet Flexi Series
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding category: Alumet Flexi Series...");

  const catFlexi = await prisma.category.upsert({
    where: { slug: "alumet-flexi-series" },
    update: { name: "Alumet Flexi Series" },
    create: {
      name: "Alumet Flexi Series",
      slug: "alumet-flexi-series",
      description: "ชุดโปรไฟล์ระแนง กล่อง และอุปกรณ์ตกแต่ง อลูเม็ท เฟล็กซี่ — ระแนงสำเร็จรูป ความยาวเส้นมาตรฐาน 6.4 ม. (ลายไม้ 6.1 ม.)",
      sortOrder: 2,
    },
  });
  console.log(`   ✓ ${catFlexi.name}\n`);

  // ═══════════════════════════════════════════════════════════
  // 9. FLEXI MATERIALS
  //    Source: ราคาขายปลีก_Flexi 010867.pdf
  //    Standard bar length: 6400mm (wood pattern: 6100mm)
  //    Prices per bar, ex-VAT. Mill = uncoated aluminum.
  //    FG-/FB-/FS- = bar profiles (per เส้น)
  //    FFA- = end-caps & clip-locks (per ชิ้น / piece)
  // ═══════════════════════════════════════════════════════════
  console.log("→ Seeding Flexi Series materials...");

  type FlexiBarSeed = {
    code: string;
    name: string;
    baseCost: number;        // White/Black price (lowest common tier)
    barLengthMm: number;     // standard bar length for this profile
    sortOrder: number;
    variants: VariantPrice[];
  };

  // Mill color (uncoated) — reuse colorWhite id as the closest proxy,
  // but we record its price under colorWhite since Mill is essentially
  // the raw-cost baseline. Admin can add a dedicated "Mill" color later.
  // White and Black share the same price tier per the price list.
  const flexiBarProfiles: FlexiBarSeed[] = [
    // ── Grill bars (FG-) ─────────────────────────────────────
    {
      code: "FG-0101",
      name: "เส้นระแนง 25×25 มม. เฟล็กซี่",
      baseCost: 560,
      barLengthMm: 6400,
      sortOrder: 1,
      variants: [
        { colorId: colorWhite.id,       unitCost: 560 },
        { colorId: colorBlack.id,       unitCost: 560 },
        { colorId: colorSaharaGrey.id,  unitCost: 575 },
        { colorId: colorSaharaSand.id,  unitCost: 605 },
        { colorId: colorWood.id,        unitCost: 745 },
      ],
    },
    {
      code: "FG-0108",
      name: "เส้นระแนง 25×42 มม. เฟล็กซี่",
      baseCost: 775,
      barLengthMm: 6400,
      sortOrder: 2,
      variants: [
        { colorId: colorWhite.id,       unitCost: 775 },
        { colorId: colorBlack.id,       unitCost: 775 },
        { colorId: colorSaharaGrey.id,  unitCost: 795 },
        { colorId: colorSaharaSand.id,  unitCost: 840 },
        { colorId: colorWood.id,        unitCost: 950 },
      ],
    },
    {
      code: "FG-0109",
      name: "เส้นระแนง 25×88 มม. เฟล็กซี่",
      baseCost: 1410,
      barLengthMm: 6400,
      sortOrder: 3,
      variants: [
        { colorId: colorWhite.id,       unitCost: 1410 },
        { colorId: colorBlack.id,       unitCost: 1410 },
        { colorId: colorSaharaGrey.id,  unitCost: 1450 },
        { colorId: colorSaharaSand.id,  unitCost: 1530 },
        { colorId: colorWood.id,        unitCost: 1885 },
      ],
    },
    {
      code: "FG-0110",
      name: "เส้นระแนง 25×88 มม. Rugby เฟล็กซี่",
      baseCost: 1290,
      barLengthMm: 6400,
      sortOrder: 4,
      variants: [
        { colorId: colorWhite.id,       unitCost: 1290 },
        { colorId: colorBlack.id,       unitCost: 1290 },
        { colorId: colorSaharaGrey.id,  unitCost: 1325 },
        { colorId: colorSaharaSand.id,  unitCost: 1400 },
        // Wood not available for this profile per price list
      ],
    },
    {
      code: "FG-0111",
      name: "เส้นระแนง 50×61.5 มม. เฟล็กซี่",
      baseCost: 1390,
      barLengthMm: 6400,
      sortOrder: 5,
      variants: [
        { colorId: colorWhite.id,       unitCost: 1390 },
        { colorId: colorBlack.id,       unitCost: 1390 },
        { colorId: colorSaharaGrey.id,  unitCost: 1430 },
        { colorId: colorSaharaSand.id,  unitCost: 1505 },
        { colorId: colorWood.id,        unitCost: 1855 },
      ],
    },
    {
      code: "FG-0112",
      name: "เส้นระแนง 50×111.5 มม. เฟล็กซี่",
      baseCost: 2455,
      barLengthMm: 6400,
      sortOrder: 6,
      variants: [
        { colorId: colorWhite.id,       unitCost: 2455 },
        { colorId: colorBlack.id,       unitCost: 2455 },
        { colorId: colorSaharaGrey.id,  unitCost: 2525 },
        { colorId: colorSaharaSand.id,  unitCost: 2665 },
        { colorId: colorWood.id,        unitCost: 3300 },
      ],
    },
    {
      code: "FG-0107",
      name: "เส้นระแนง 75×25 มม. เฟล็กซี่",
      baseCost: 1270,
      barLengthMm: 6400,
      sortOrder: 7,
      variants: [
        { colorId: colorWhite.id,       unitCost: 1270 },
        { colorId: colorBlack.id,       unitCost: 1270 },
        { colorId: colorSaharaGrey.id,  unitCost: 1305 },
        { colorId: colorSaharaSand.id,  unitCost: 1375 },
        { colorId: colorWood.id,        unitCost: 1695 },
      ],
    },
    // ── Back covers (FB-) ─────────────────────────────────────
    {
      code: "FB-0101",
      name: "ฝาปิดหลัง 25 เฟล็กซี่",
      baseCost: 425,
      barLengthMm: 6400,
      sortOrder: 10,
      variants: [
        { colorId: colorWhite.id,       unitCost: 425 },
        { colorId: colorBlack.id,       unitCost: 425 },
        { colorId: colorSaharaGrey.id,  unitCost: 435 },
        { colorId: colorSaharaSand.id,  unitCost: 460 },
        { colorId: colorWood.id,        unitCost: 560 },
      ],
    },
    {
      code: "FB-0102",
      name: "ฝาปิดหลัง 50 เฟล็กซี่",
      baseCost: 545,
      barLengthMm: 6400,
      sortOrder: 11,
      variants: [
        { colorId: colorWhite.id,       unitCost: 545 },
        { colorId: colorBlack.id,       unitCost: 545 },
        { colorId: colorSaharaGrey.id,  unitCost: 560 },
        { colorId: colorSaharaSand.id,  unitCost: 590 },
        { colorId: colorWood.id,        unitCost: 725 },
      ],
    },
    {
      code: "FB-0103",
      name: "ฝาปิดหลัง 75 เฟล็กซี่",
      baseCost: 680,
      barLengthMm: 6400,
      sortOrder: 12,
      variants: [
        { colorId: colorWhite.id,       unitCost: 680 },
        { colorId: colorBlack.id,       unitCost: 680 },
        { colorId: colorSaharaGrey.id,  unitCost: 700 },
        { colorId: colorSaharaSand.id,  unitCost: 735 },
        { colorId: colorWood.id,        unitCost: 905 },
      ],
    },
  ];

  const flexiMaterialMap: Record<string, string> = {};

  for (const mat of flexiBarProfiles) {
    const material = await prisma.material.upsert({
      where: { code: mat.code },
      update: { name: mat.name, baseCost: mat.baseCost },
      create: {
        categoryId: catFlexi.id,
        code: mat.code,
        name: mat.name,
        unit: "เส้น",
        baseCost: mat.baseCost,
        sortOrder: mat.sortOrder,
        description: `ราคาต่อเส้น ${(mat.barLengthMm / 1000).toFixed(1)} ม.`,
      },
    });
    flexiMaterialMap[mat.code] = material.id;

    for (const v of mat.variants) {
      await prisma.materialVariant.upsert({
        where: { materialId_colorId: { materialId: material.id, colorId: v.colorId } },
        update: { unitCost: v.unitCost },
        create: { materialId: material.id, colorId: v.colorId, unitCost: v.unitCost },
      });
    }
    console.log(`   ✓ [${mat.code}] ${mat.name}  ฿${mat.baseCost}/เส้น`);
  }

  // ── FS-0102 Grill Support (Anodized Black only) ───────────
  const flexiSupport = await prisma.material.upsert({
    where: { code: "FS-0102" },
    update: { name: "อุปกรณ์ยึดระแนง เฟล็กซี่", baseCost: 775 },
    create: {
      categoryId: catFlexi.id,
      code: "FS-0102",
      name: "อุปกรณ์ยึดระแนง เฟล็กซี่",
      unit: "เส้น",
      baseCost: 775,
      sortOrder: 15,
      description: "สีชุบดำ (Anodized Black 518) เท่านั้น",
    },
  });
  await prisma.materialVariant.upsert({
    where: { materialId_colorId: { materialId: flexiSupport.id, colorId: colorBlack.id } },
    update: { unitCost: 775 },
    create: { materialId: flexiSupport.id, colorId: colorBlack.id, unitCost: 775 },
  });
  console.log(`   ✓ [FS-0102] อุปกรณ์ยึดระแนง เฟล็กซี่  ฿775/เส้น (Black only)`);

  // ── FFA- End caps & clip-locks (per ชิ้น, Black only) ─────
  type AccessoryPieceSeed = { code: string; name: string; unitCost: number; sortOrder: number };

  const flexiAccessoryPieces: AccessoryPieceSeed[] = [
    // Back-cover end caps
    { code: "FFA-001", name: "ฝาปิดหัวท้าย 25×25 (Back Cover)",    unitCost: 19, sortOrder: 20 },
    { code: "FFA-002", name: "ฝาปิดหัวท้าย 25×42 (Back Cover)",    unitCost: 21, sortOrder: 21 },
    { code: "FFA-003", name: "ฝาปิดหัวท้าย 25×88 (Back Cover)",    unitCost: 28, sortOrder: 22 },
    { code: "FFA-004", name: "ฝาปิดหัวท้าย 50×61 (Back Cover)",    unitCost: 24, sortOrder: 23 },
    { code: "FFA-005", name: "ฝาปิดหัวท้าย 50×111.5 (Back Cover)", unitCost: 33, sortOrder: 24 },
    { code: "FFA-006", name: "ฝาปิดหัวท้าย 75×25 (Back Cover)",    unitCost: 19, sortOrder: 25 },
    // Clip-lock end caps
    { code: "FFA-010", name: "ฝาปิดหัวท้าย 25×33.5 (Clip Lock)",  unitCost: 20, sortOrder: 26 },
    { code: "FFA-011", name: "ฝาปิดหัวท้าย 25×50.5 (Clip Lock)",  unitCost: 20, sortOrder: 27 },
    { code: "FFA-012", name: "ฝาปิดหัวท้าย 25×96.5 (Clip Lock)",  unitCost: 28, sortOrder: 28 },
    { code: "FFA-013", name: "ฝาปิดหัวท้าย 50×70 (Clip Lock)",    unitCost: 26, sortOrder: 29 },
    { code: "FFA-014", name: "ฝาปิดหัวท้าย 50×120 (Clip Lock)",   unitCost: 35, sortOrder: 30 },
    { code: "FFA-015", name: "ฝาปิดหัวท้าย 75×33.5 (Clip Lock)",  unitCost: 23, sortOrder: 31 },
    // Clip locks
    { code: "FFA-007", name: "คลิปล็อค 25 เฟล็กซี่",              unitCost: 42, sortOrder: 32 },
    { code: "FFA-008", name: "คลิปล็อค 50 เฟล็กซี่",              unitCost: 50, sortOrder: 33 },
    { code: "FFA-009", name: "คลิปล็อค 75 เฟล็กซี่",              unitCost: 58, sortOrder: 34 },
  ];

  for (const piece of flexiAccessoryPieces) {
    const mat = await prisma.material.upsert({
      where: { code: piece.code },
      update: { name: piece.name, baseCost: piece.unitCost },
      create: {
        categoryId: catFlexi.id,
        code: piece.code,
        name: piece.name,
        unit: "ชิ้น",
        baseCost: piece.unitCost,
        sortOrder: piece.sortOrder,
        description: "สีดำเท่านั้น (Black)",
      },
    });
    await prisma.materialVariant.upsert({
      where: { materialId_colorId: { materialId: mat.id, colorId: colorBlack.id } },
      update: { unitCost: piece.unitCost },
      create: { materialId: mat.id, colorId: colorBlack.id, unitCost: piece.unitCost },
    });
    console.log(`   ✓ [${piece.code}] ${piece.name}  ฿${piece.unitCost}/ชิ้น`);
  }

  // ═══════════════════════════════════════════════════════════
  // 10. CATEGORY: Alumet Box Series
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding category: Alumet Box Series...");

  const catBox = await prisma.category.upsert({
    where: { slug: "alumet-box-series" },
    update: { name: "Alumet Box Series" },
    create: {
      name: "Alumet Box Series",
      slug: "alumet-box-series",
      description: "ชุดกล่องอลูมิเนียม ตัวยู และฝาปิด อลูเม็ท — ขนาดหลากหลาย ทั้งมิลลิเมตรและนิ้ว",
      sortOrder: 3,
    },
  });
  console.log(`   ✓ ${catBox.name}\n`);

  // ═══════════════════════════════════════════════════════════
  // 11. BOX SERIES MATERIALS
  //    Source: ราคาขายปลีก_กล่อง 010867.pdf (effective 1 Aug 2024)
  //
  //    Two bar-length groups:
  //      Rows 1-14  → 6000mm standard (Wood: 5700mm)
  //      Rows 15-22 → 6400mm standard (Wood: 6100mm)
  //
  //    Where the same catalog code appears at two thicknesses
  //    (e.g., 749-1.2 and 749-1.5) we append the thickness to
  //    the code to keep Material.code unique.
  //
  //    Prices per bar (เส้น), retail ex-VAT.
  // ═══════════════════════════════════════════════════════════
  console.log("→ Seeding Box Series materials...");

  type BoxSeed = {
    code: string;
    name: string;
    description: string;
    baseCost: number;
    barLengthMm: number;
    sortOrder: number;
    variants: VariantPrice[];
  };

  const boxProfiles: BoxSeed[] = [
    // ── Group A: 6000mm bars (rows 1-14) ──────────────────────
    {
      code: "BOX-SP826",
      name: "กล่อง 50×10 มม.",
      description: "50×10 mm, หนา 1.0 mm, ยาว 6.0 ม.",
      baseCost: 465,
      barLengthMm: 6000,
      sortOrder: 1,
      variants: [
        { colorId: colorWhite.id,      unitCost: 465 },
        { colorId: colorBlack.id,      unitCost: 465 },
        { colorId: colorSaharaGrey.id, unitCost: 475 },
        { colorId: colorSaharaSand.id, unitCost: 505 },
        { colorId: colorWood.id,       unitCost: 630 },
      ],
    },
    {
      code: "BOX-110011",
      name: "กล่อง 75×15 มม.",
      description: "75×15 mm, หนา 1.8 mm, ยาว 6.0 ม.",
      baseCost: 755,
      barLengthMm: 6000,
      sortOrder: 2,
      variants: [
        { colorId: colorWhite.id,      unitCost: 755 },
        { colorId: colorBlack.id,      unitCost: 755 },
        { colorId: colorSaharaGrey.id, unitCost: 775 },
        { colorId: colorSaharaSand.id, unitCost: 825 },
        { colorId: colorWood.id,       unitCost: 1035 },
      ],
    },
    {
      code: "BOX-709",
      name: "กล่อง 1×1 นิ้ว",
      description: "25.4×25.4 mm, หนา 1.0 mm, ยาว 6.0 ม.",
      baseCost: 430,
      barLengthMm: 6000,
      sortOrder: 3,
      variants: [
        { colorId: colorWhite.id,      unitCost: 430 },
        { colorId: colorBlack.id,      unitCost: 430 },
        { colorId: colorSaharaGrey.id, unitCost: 445 },
        { colorId: colorSaharaSand.id, unitCost: 470 },
        { colorId: colorWood.id,       unitCost: 590 },
      ],
    },
    {
      code: "BOX-724",
      name: "กล่อง 1¾×1¾ นิ้ว",
      description: "44.5×44.5 mm, หนา 1.0 mm, ยาว 6.0 ม.",
      baseCost: 675,
      barLengthMm: 6000,
      sortOrder: 4,
      variants: [
        { colorId: colorWhite.id,      unitCost: 675 },
        { colorId: colorBlack.id,      unitCost: 675 },
        { colorId: colorSaharaGrey.id, unitCost: 700 },
        { colorId: colorSaharaSand.id, unitCost: 740 },
        { colorId: colorWood.id,       unitCost: 920 },
      ],
    },
    {
      code: "BOX-816",
      name: "กล่อง 1×2 นิ้ว",
      description: "25.4×50.8 mm, หนา 1.0 mm, ยาว 6.0 ม.",
      baseCost: 750,
      barLengthMm: 6000,
      sortOrder: 5,
      variants: [
        { colorId: colorWhite.id,      unitCost: 750 },
        { colorId: colorBlack.id,      unitCost: 750 },
        { colorId: colorSaharaGrey.id, unitCost: 775 },
        { colorId: colorSaharaSand.id, unitCost: 820 },
        { colorId: colorWood.id,       unitCost: 1015 },
      ],
    },
    {
      code: "BOX-749-1.2",
      name: "กล่อง 2×2 นิ้ว (หนา 1.2 มม.)",
      description: "50.8×50.8 mm, หนา 1.2 mm, ยาว 6.0 ม.",
      baseCost: 1080,
      barLengthMm: 6000,
      sortOrder: 6,
      variants: [
        { colorId: colorWhite.id,      unitCost: 1080 },
        { colorId: colorBlack.id,      unitCost: 1080 },
        { colorId: colorSaharaGrey.id, unitCost: 1115 },
        { colorId: colorSaharaSand.id, unitCost: 1185 },
        { colorId: colorWood.id,       unitCost: 3185 },
      ],
    },
    {
      code: "BOX-749-1.5",
      name: "กล่อง 2×2 นิ้ว (หนา 1.5 มม.)",
      description: "50.8×50.8 mm, หนา 1.5 mm, ยาว 6.0 ม.",
      baseCost: 1240,
      barLengthMm: 6000,
      sortOrder: 7,
      variants: [
        { colorId: colorWhite.id,      unitCost: 1240 },
        { colorId: colorBlack.id,      unitCost: 1240 },
        { colorId: colorSaharaGrey.id, unitCost: 1280 },
        { colorId: colorSaharaSand.id, unitCost: 1355 },
        { colorId: colorWood.id,       unitCost: 3185 },
      ],
    },
    {
      code: "BOX-820-1.0",
      name: "กล่อง 3×1 นิ้ว (หนา 1.0 มม.)",
      description: "76.2×25.4 mm, หนา 1.0 mm, ยาว 6.0 ม.",
      baseCost: 925,
      barLengthMm: 6000,
      sortOrder: 8,
      variants: [
        { colorId: colorWhite.id,      unitCost: 925 },
        { colorId: colorBlack.id,      unitCost: 925 },
        { colorId: colorSaharaGrey.id, unitCost: 955 },
        { colorId: colorSaharaSand.id, unitCost: 1015 },
        { colorId: colorWood.id,       unitCost: 2685 },
      ],
    },
    {
      code: "BOX-820-1.2",
      name: "กล่อง 3×1 นิ้ว (หนา 1.2 มม.)",
      description: "76.2×25.4 mm, หนา 1.2 mm, ยาว 6.0 ม.",
      baseCost: 1025,
      barLengthMm: 6000,
      sortOrder: 9,
      variants: [
        { colorId: colorWhite.id,      unitCost: 1025 },
        { colorId: colorBlack.id,      unitCost: 1025 },
        { colorId: colorSaharaGrey.id, unitCost: 1055 },
        { colorId: colorSaharaSand.id, unitCost: 1120 },
        { colorId: colorWood.id,       unitCost: 2685 },
      ],
    },
    {
      code: "BOX-823",
      name: "กล่อง 3×1¾ นิ้ว",
      description: "76.2×44.5 mm, หนา 1.0 mm, ยาว 6.0 ม.",
      baseCost: 1170,
      barLengthMm: 6000,
      sortOrder: 10,
      variants: [
        { colorId: colorWhite.id,      unitCost: 1170 },
        { colorId: colorBlack.id,      unitCost: 1170 },
        { colorId: colorSaharaGrey.id, unitCost: 1210 },
        { colorId: colorSaharaSand.id, unitCost: 1285 },
        { colorId: colorWood.id,       unitCost: 1595 },
      ],
    },
    {
      code: "BOX-831-1.2",
      name: "กล่อง 4×1 นิ้ว (หนา 1.2 มม.)",
      description: "101.6×25.4 mm, หนา 1.2 mm, ยาว 6.0 ม.",
      baseCost: 1185,
      barLengthMm: 6000,
      sortOrder: 11,
      variants: [
        { colorId: colorWhite.id,      unitCost: 1185 },
        { colorId: colorBlack.id,      unitCost: 1185 },
        { colorId: colorSaharaGrey.id, unitCost: 1220 },
        { colorId: colorSaharaSand.id, unitCost: 1295 },
        { colorId: colorWood.id,       unitCost: 3765 },
      ],
    },
    {
      code: "BOX-831-1.5",
      name: "กล่อง 4×1 นิ้ว (หนา 1.5 มม.)",
      description: "101.6×25.4 mm, หนา 1.5 mm, ยาว 6.0 ม.",
      baseCost: 1565,
      barLengthMm: 6000,
      sortOrder: 12,
      variants: [
        { colorId: colorWhite.id,      unitCost: 1565 },
        { colorId: colorBlack.id,      unitCost: 1565 },
        { colorId: colorSaharaGrey.id, unitCost: 1615 },
        { colorId: colorSaharaSand.id, unitCost: 1715 },
        { colorId: colorWood.id,       unitCost: 3765 },
      ],
    },
    {
      code: "BOX-841",
      name: "กล่อง 4×2 นิ้ว",
      description: "101.6×50.8 mm, หนา 1.5 mm, ยาว 6.0 ม.",
      baseCost: 1900,
      barLengthMm: 6000,
      sortOrder: 13,
      variants: [
        { colorId: colorWhite.id,      unitCost: 1900 },
        { colorId: colorBlack.id,      unitCost: 1900 },
        { colorId: colorSaharaGrey.id, unitCost: 1960 },
        { colorId: colorSaharaSand.id, unitCost: 2085 },
        { colorId: colorWood.id,       unitCost: 2585 },
      ],
    },
    {
      code: "BOX-110001",
      name: "กล่อง 4×4 นิ้ว",
      description: "101.6×101.6 mm, หนา 2.0 mm, ยาว 6.0 ม.",
      baseCost: 3325,
      barLengthMm: 6000,
      sortOrder: 14,
      variants: [
        { colorId: colorWhite.id,      unitCost: 3325 },
        { colorId: colorBlack.id,      unitCost: 3325 },
        { colorId: colorSaharaGrey.id, unitCost: 3430 },
        { colorId: colorSaharaSand.id, unitCost: 3645 },
        { colorId: colorWood.id,       unitCost: 4610 },
      ],
    },
    // ── Group B: 6400mm bars (rows 15-22) ─────────────────────
    {
      code: "BOX-280032",
      name: "กล่อง 48×10 มม. (มีรูสกรู)",
      description: "48×10 mm มีรูสกรู, หนา 1.0 mm, ยาว 6.4 ม.",
      baseCost: 620,
      barLengthMm: 6400,
      sortOrder: 15,
      variants: [
        { colorId: colorWhite.id,      unitCost: 620 },
        { colorId: colorBlack.id,      unitCost: 620 },
        { colorId: colorSaharaGrey.id, unitCost: 635 },
        { colorId: colorSaharaSand.id, unitCost: 675 },
        { colorId: colorWood.id,       unitCost: 805 },
      ],
    },
    {
      code: "BOX-280033",
      name: "ตัวยู (ใช้ร่วมกับ 280032)",
      description: "50.8×15 mm, หนา 1.2 mm, ยาว 6.4 ม.",
      baseCost: 435,
      barLengthMm: 6400,
      sortOrder: 16,
      variants: [
        { colorId: colorWhite.id,      unitCost: 435 },
        { colorId: colorBlack.id,      unitCost: 435 },
        { colorId: colorSaharaGrey.id, unitCost: 450 },
        { colorId: colorSaharaSand.id, unitCost: 475 },
        { colorId: colorWood.id,       unitCost: 595 },
      ],
    },
    {
      code: "BOX-010005",
      name: "กล่อง 25.5×30 มม. (มีรูสกรู)",
      description: "25.5×30 mm มีรูสกรู, หนา 1.8 mm, ยาว 6.4 ม.",
      baseCost: 605,
      barLengthMm: 6400,
      sortOrder: 17,
      variants: [
        { colorId: colorWhite.id,      unitCost: 605 },
        { colorId: colorBlack.id,      unitCost: 605 },
        { colorId: colorSaharaGrey.id, unitCost: 620 },
        { colorId: colorSaharaSand.id, unitCost: 660 },
        { colorId: colorWood.id,       unitCost: 825 },
      ],
    },
    {
      code: "BOX-010006",
      name: "ฝาปิด (ใช้ร่วมกับ 010005)",
      description: "5.5×30 mm, หนา 1.2 mm, ยาว 6.4 ม.",
      baseCost: 220,
      barLengthMm: 6400,
      sortOrder: 18,
      variants: [
        { colorId: colorWhite.id,      unitCost: 220 },
        { colorId: colorBlack.id,      unitCost: 220 },
        { colorId: colorSaharaGrey.id, unitCost: 225 },
        { colorId: colorSaharaSand.id, unitCost: 240 },
        { colorId: colorWood.id,       unitCost: 300 },
      ],
    },
    {
      code: "BOX-280030",
      name: "กล่อง 1×1¾ นิ้ว (มีรูสกรู)",
      description: "25.5×44.5 mm มีรูสกรู, หนา 1.5 mm, ยาว 6.4 ม.",
      baseCost: 1010,
      barLengthMm: 6400,
      sortOrder: 19,
      variants: [
        { colorId: colorWhite.id,      unitCost: 1010 },
        { colorId: colorBlack.id,      unitCost: 1010 },
        { colorId: colorSaharaGrey.id, unitCost: 1040 },
        { colorId: colorSaharaSand.id, unitCost: 1105 },
        { colorId: colorWood.id,       unitCost: 1390 },
      ],
    },
    {
      code: "BOX-280031",
      name: "ฝาปิด (ใช้ร่วมกับ 280030)",
      description: "49.8×5.5 mm, หนา 1.2 mm, ยาว 6.4 ม.",
      baseCost: 325,
      barLengthMm: 6400,
      sortOrder: 20,
      variants: [
        { colorId: colorWhite.id,      unitCost: 325 },
        { colorId: colorBlack.id,      unitCost: 325 },
        { colorId: colorSaharaGrey.id, unitCost: 335 },
        { colorId: colorSaharaSand.id, unitCost: 355 },
        { colorId: colorWood.id,       unitCost: 450 },
      ],
    },
    {
      code: "BOX-3478",
      name: "กล่องช่วยยู 4×4 นิ้ว",
      description: "101.6×101.6 mm, หนา 2.0 mm, ยาว 6.4 ม.",
      baseCost: 3015,
      barLengthMm: 6400,
      sortOrder: 21,
      variants: [
        { colorId: colorWhite.id,      unitCost: 3015 },
        { colorId: colorBlack.id,      unitCost: 3015 },
        { colorId: colorSaharaGrey.id, unitCost: 3115 },
        { colorId: colorSaharaSand.id, unitCost: 3310 },
        { colorId: colorWood.id,       unitCost: 4185 },
      ],
    },
    {
      code: "BOX-3015",
      name: "ตบเรียบ (ใช้ร่วมกับ 3478)",
      description: "101.6×5.9 mm, หนา 1.2 mm, ยาว 6.4 ม.",
      baseCost: 490,
      barLengthMm: 6400,
      sortOrder: 22,
      variants: [
        { colorId: colorWhite.id,      unitCost: 490 },
        { colorId: colorBlack.id,      unitCost: 490 },
        { colorId: colorSaharaGrey.id, unitCost: 505 },
        { colorId: colorSaharaSand.id, unitCost: 535 },
        { colorId: colorWood.id,       unitCost: 665 },
      ],
    },
  ];

  for (const mat of boxProfiles) {
    const material = await prisma.material.upsert({
      where: { code: mat.code },
      update: { name: mat.name, baseCost: mat.baseCost },
      create: {
        categoryId: catBox.id,
        code: mat.code,
        name: mat.name,
        unit: "เส้น",
        baseCost: mat.baseCost,
        sortOrder: mat.sortOrder,
        description: mat.description,
      },
    });

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
  // 12. CATEGORY: Alumet Pro Smart Series
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding category: Alumet Pro Smart Series...");

  const catProSmart = await prisma.category.upsert({
    where: { slug: "alumet-pro-smart-series" },
    update: { name: "Alumet Pro Smart Series" },
    create: {
      name: "Alumet Pro Smart Series",
      slug: "alumet-pro-smart-series",
      description: "ชุดโปรไฟล์บานเฟี้ยม บานเลื่อน บานเปิด-กระทุ้ง และช่องแสง อลูเม็ท โปร สมาร์ท — ความยาวเส้น 6.4 ม.",
      sortOrder: 4,
    },
  });
  console.log(`   ✓ ${catProSmart.name}\n`);

  // ═══════════════════════════════════════════════════════════
  // 13. PRO SMART MATERIALS
  //    Source: ราคาขายปลีก_โปรสมาร์ท 010867.pdf
  //    Standard bar length: 6400mm for all profiles.
  //    Prices: White/Black (8911/8816), Sahara Grey (8820),
  //            Sahara Sand (8515), Wood pattern.
  //    baseCost = White/Black price (lowest stock-color tier).
  // ═══════════════════════════════════════════════════════════
  console.log("→ Seeding Pro Smart materials...");

  type PSeed = { code: string; name: string; baseCost: number; sortOrder: number; v: [number, number, number, number] };
  // v = [white/black, saharaGrey, saharaSand, wood]

  const psUpsert = async (items: PSeed[], categoryId: string) => {
    for (const p of items) {
      const mat = await prisma.material.upsert({
        where: { code: p.code },
        update: { name: p.name, baseCost: p.baseCost },
        create: { categoryId, code: p.code, name: p.name, unit: "เส้น", baseCost: p.baseCost, sortOrder: p.sortOrder, description: "ยาว 6.4 ม." },
      });
      const pairs: [string, number][] = [
        [colorWhite.id, p.v[0]], [colorBlack.id, p.v[0]],
        [colorSaharaGrey.id, p.v[1]], [colorSaharaSand.id, p.v[2]], [colorWood.id, p.v[3]],
      ];
      for (const [colorId, unitCost] of pairs) {
        await prisma.materialVariant.upsert({
          where: { materialId_colorId: { materialId: mat.id, colorId } },
          update: { unitCost },
          create: { materialId: mat.id, colorId, unitCost },
        });
      }
      console.log(`   ✓ [${p.code}] ${p.name}  ฿${p.baseCost}`);
    }
  };

  // ── Section 1: บานเฟี้ยม (Folding) — SB- profiles ────────
  const psFolding: PSeed[] = [
    { code: "SB-0101", name: "เสาบานเฟี้ยม สมาร์ท",                      baseCost: 4865, sortOrder: 1,  v: [4865, 5015, 5320, 6690] },
    { code: "SB-0103", name: "คานบนบานเฟี้ยม สมาร์ท",                    baseCost: 1970, sortOrder: 2,  v: [1970, 2035, 2155, 2710] },
    { code: "SB-0105", name: "คานล่างบานเฟี้ยม สมาร์ท",                  baseCost: 2045, sortOrder: 3,  v: [2045, 2110, 2235, 2810] },
    { code: "SB-0102", name: "เสาตรงบานเฟี้ยม สมาร์ท",                   baseCost: 3110, sortOrder: 4,  v: [3110, 3210, 3405, 4275] },
    { code: "SB-0115", name: "คานรั้งหลังบานเฟี้ยม สมาร์ท",              baseCost: 520,  sortOrder: 5,  v: [520,  535,  565,  705]  },
    { code: "SB-0116", name: "คานในบานเฟี้ยม",                            baseCost: 1300, sortOrder: 6,  v: [1300, 1340, 1420, 1775] },
    { code: "SB-0112", name: "คานกลางบานเฟี้ยม สมาร์ท",                  baseCost: 1025, sortOrder: 7,  v: [1025, 1055, 1115, 1395] },
    { code: "SB-0114", name: "ฝาประตูบานเฟี้ยม สมาร์ท",                  baseCost: 2025, sortOrder: 8,  v: [2025, 2090, 2215, 2785] },
    { code: "SB-0107", name: "ขวางบน-ล่างบานเฟี้ยม สมาร์ท",              baseCost: 1760, sortOrder: 9,  v: [1760, 1810, 1920, 2410] },
    { code: "SB-0111", name: "ตูดรักบานเฟี้ยม สมาร์ท",                   baseCost: 1175, sortOrder: 10, v: [1175, 1210, 1285, 1605] },
    { code: "SB-0113", name: "ฝาบานติดตายบานเฟี้ยม สมาร์ท",              baseCost: 1770, sortOrder: 11, v: [1770, 1825, 1935, 2430] },
    { code: "SB-0108", name: "คิ้วบางบานเฟี้ยม สมาร์ท",                  baseCost: 345,  sortOrder: 12, v: [345,  355,  375,  465]  },
    { code: "SB-0109", name: "คิ้วหนาบานเฟี้ยม สมาร์ท",                  baseCost: 505,  sortOrder: 13, v: [505,  520,  550,  680]  },
    { code: "SB-0110", name: "คิ้วบังใบบานเฟี้ยม สมาร์ท",                baseCost: 250,  sortOrder: 14, v: [250,  255,  270,  335]  },
    { code: "SB-0117", name: "เสริมเสาบานเปิดกลางบานเฟี้ยม สมาร์ท",     baseCost: 900,  sortOrder: 15, v: [900,  930,  985,  1230] },
    { code: "SB-0118", name: "เสริมเสามุมบานเฟี้ยม สมาร์ท",              baseCost: 1595, sortOrder: 16, v: [1595, 1645, 1740, 2185] },
  ];

  // ── Section 2: บานเลื่อน (Sliding) — SS- profiles ────────
  const psSliding: PSeed[] = [
    { code: "SS-0143", name: "เฟรมบน-ข้าง สมาร์ท 101.6 มม.",             baseCost: 1730, sortOrder: 20, v: [1730, 1785, 1890, 2385] },
    { code: "SS-0129", name: "เฟรมข้างกล่องเรียบ สมาร์ท 101.6 มม.",      baseCost: 1240, sortOrder: 21, v: [1240, 1280, 1360, 1665] },
    { code: "SS-0131", name: "เฟรมล่าง 2 ราง สมาร์ท 101.6 มม.",          baseCost: 2090, sortOrder: 22, v: [2090, 2160, 2290, 2890] },
    { code: "SS-0144", name: "เฟรมบน 3 ราง สมาร์ท 101.6 มม.",            baseCost: 1790, sortOrder: 23, v: [1790, 1845, 1960, 2470] },
    { code: "SS-0133", name: "เฟรมล่าง 3 ราง สมาร์ท 101.6 มม.",          baseCost: 2160, sortOrder: 24, v: [2160, 2230, 2370, 2985] },
    { code: "SS-0121", name: "เฟรมล่าง 3 รางภายใน สมาร์ท 101.6 มม.",    baseCost: 1170, sortOrder: 25, v: [1170, 1210, 1280, 1610] },
    { code: "SS-0142", name: "เฟรมบน-ข้าง สมาร์ท 86.5 มม.",              baseCost: 1575, sortOrder: 26, v: [1575, 1625, 1725, 2170] },
    { code: "SS-0132", name: "เฟรมข้างกล่องเรียบ สมาร์ท 86.5 มม.",       baseCost: 1020, sortOrder: 27, v: [1020, 1050, 1115, 1400] },
    { code: "SS-0136", name: "เฟรมล่าง 2 ราง สมาร์ท 86.5 มม.",           baseCost: 1870, sortOrder: 28, v: [1870, 1930, 2050, 2510] },
    { code: "SS-0126", name: "เฟรมบน-ข้าง สมาร์ท 69.7 มม.",              baseCost: 1285, sortOrder: 29, v: [1285, 1325, 1405, 1765] },
    { code: "SS-0128", name: "เฟรมข้างกล่องเรียบ สมาร์ท 69.7 มม.",       baseCost: 930,  sortOrder: 30, v: [930,  960,  1015, 1275] },
    { code: "SS-0134", name: "เฟรมล่าง 2 ราง สมาร์ท 69.7 มม.",           baseCost: 1580, sortOrder: 31, v: [1580, 1630, 1730, 2180] },
    { code: "SS-0125", name: "เฟรมล่างภายใน สมาร์ท 69.7 มม.",            baseCost: 775,  sortOrder: 32, v: [775,  800,  850,  1060] },
    { code: "SS-0117", name: "ฝาปิดเสริมเสากุญแจตัวผู้ สมาร์ท",          baseCost: 235,  sortOrder: 33, v: [235,  245,  255,  320]  },
    { code: "SS-0120", name: "เสริมปิดเฟรมข้างกล่องเรียบ สมาร์ท",        baseCost: 280,  sortOrder: 34, v: [280,  290,  305,  375]  },
    { code: "SS-0145", name: "ตบธรณี สมาร์ท",                             baseCost: 490,  sortOrder: 35, v: [490,  505,  535,  670]  },
    { code: "SS-0127", name: "ตบเฟรมบน-ข้างบานเลื่อน สมาร์ท",            baseCost: 1395, sortOrder: 36, v: [1395, 1435, 1525, 1915] },
    { code: "SS-0104", name: "เสริมช่องแสงบานเลื่อน 2 ราง สมาร์ท",       baseCost: 935,  sortOrder: 37, v: [935,  960,  1020, 1280] },
    { code: "SS-0137", name: "เสริมช่องแสงบานเลื่อน 3 ราง สมาร์ท",       baseCost: 985,  sortOrder: 38, v: [985,  1015, 1080, 1350] },
    { code: "SS-0147", name: "เสากุญแจ สมาร์ท",                           baseCost: 1005, sortOrder: 39, v: [1005, 1035, 1095, 1375] },
    { code: "SS-0123", name: "ตบเสาเกี่ยว สมาร์ท",                        baseCost: 460,  sortOrder: 40, v: [460,  475,  505,  630]  },
    { code: "SS-0114", name: "ตบเสาเกี่ยว 2 ทาง สมาร์ท",                 baseCost: 715,  sortOrder: 41, v: [715,  735,  780,  980]  },
    { code: "SS-0116", name: "เสริมเสากุญแจตัวผู้ สมาร์ท 15 มม.",         baseCost: 390,  sortOrder: 42, v: [390,  405,  430,  535]  },
    { code: "SS-0138", name: "เสากุญแจมัลติพ้อยท์ สมาร์ท",               baseCost: 1260, sortOrder: 43, v: [1260, 1300, 1375, 1725] },
    { code: "SS-0139", name: "ตบเกี่ยวเสามัลติพ้อยท์ สมาร์ท",            baseCost: 505,  sortOrder: 44, v: [505,  520,  550,  685]  },
    { code: "SS-0140", name: "ตบเกี่ยว 2 ทางเสามัลติพ้อยท์ สมาร์ท",     baseCost: 805,  sortOrder: 45, v: [805,  825,  875,  1100] },
    { code: "SS-0141", name: "เสริมเสากุญแจตัวผู้ สมาร์ท 20 มม.",         baseCost: 610,  sortOrder: 46, v: [610,  630,  665,  835]  },
    { code: "SS-0106", name: "เสาเกี่ยว สมาร์ท",                          baseCost: 915,  sortOrder: 47, v: [915,  945,  1000, 1255] },
    { code: "SS-0107", name: "เสาเกี่ยวมีอจับ สมาร์ท",                    baseCost: 1240, sortOrder: 48, v: [1240, 1275, 1355, 1670] },
    { code: "SS-0105", name: "ขวางบน-ล่าง สมาร์ท",                        baseCost: 1055, sortOrder: 49, v: [1055, 1090, 1155, 1445] },
    { code: "SS-0124", name: "ขวางล่างภายใน สมาร์ท",                      baseCost: 890,  sortOrder: 50, v: [890,  920,  975,  1220] },
    { code: "PS-2044",  name: "เสริมมุ้งบานเลื่อน",                        baseCost: 215,  sortOrder: 51, v: [215,  220,  235,  295]  },
  ];

  // ── Section 3: บานกระทุ้ง/บานเปิด (Awning/Casement) — SC- ─
  const psAwning: PSeed[] = [
    { code: "SC-0211", name: "กรอบนอกบานกระทุ้ง สมาร์ท",                baseCost: 650,  sortOrder: 55, v: [650,  670,  710,  890]  },
    { code: "SC-0210", name: "กรอบบานกระทุ้ง สมาร์ท",                    baseCost: 1365, sortOrder: 56, v: [1365, 1405, 1490, 1875] },
    { code: "SC-0212", name: "เสริมเสาบานเปิดคู่ สมาร์ท",               baseCost: 910,  sortOrder: 57, v: [910,  935,  995,  1245] },
    { code: "SC-0213", name: "ฝาตบกล่องเรียบ สมาร์ท",                    baseCost: 710,  sortOrder: 58, v: [710,  730,  775,  960]  },
    { code: "SC-0301", name: "กล่องกำแพงบานกระทุ้ง สมาร์ท 86.5 มม.",     baseCost: 1210, sortOrder: 59, v: [1210, 1250, 1325, 1665] },
    { code: "SC-0302", name: "กล่องกำแพงบานกระทุ้ง 2 ทาง สมาร์ท 86.5", baseCost: 2060, sortOrder: 60, v: [2060, 2125, 2260, 2850] },
    { code: "SC-0303", name: "เฟรมล่างกล่องกำแพงบานกระทุ้ง สมาร์ท 86.5",baseCost: 1340, sortOrder: 61, v: [1340, 1380, 1465, 1845] },
    { code: "SC-0206", name: "เฟรมบานกระทุ้ง สมาร์ท 101.6 มม.",          baseCost: 1675, sortOrder: 62, v: [1675, 1730, 1835, 2230] },
    { code: "SC-0205", name: "ซอยกลางกระทุ้ง สมาร์ท 101.6 มม.",          baseCost: 1845, sortOrder: 63, v: [1845, 1905, 2020, 2540] },
    { code: "SC-0209", name: "เฟรมบานกระทุ้ง สมาร์ท 86.5 มม.",           baseCost: 1420, sortOrder: 64, v: [1420, 1465, 1550, 1950] },
    { code: "SC-0202", name: "ตบกระทุ้ง สมาร์ท",                          baseCost: 680,  sortOrder: 65, v: [680,  700,  740,  930]  },
    { code: "SC-0201", name: "กรอบบานกระทุ้ง สมาร์ท",                    baseCost: 1330, sortOrder: 66, v: [1330, 1370, 1455, 1825] },
    { code: "SC-0207", name: "เสริมเสาบานเปิดคู่ สมาร์ท 2",              baseCost: 1450, sortOrder: 67, v: [1450, 1495, 1585, 1995] },
    { code: "SC-0103", name: "เสริมช่องแสงกระทุ้ง สมาร์ท",               baseCost: 715,  sortOrder: 68, v: [715,  735,  780,  975]  },
  ];

  // ── Section 4: ช่องแสง (Fixed glazing) — SF- profiles ─────
  const psFixed: PSeed[] = [
    { code: "SF-0105", name: "เฟรมช่องแสง สมาร์ท 101.6 มม.",             baseCost: 1730, sortOrder: 72, v: [1730, 1785, 1890, 2385] },
    { code: "SF-0108", name: "เฟรมช่องแสง สมาร์ท 86.5 มม.",              baseCost: 1495, sortOrder: 73, v: [1495, 1545, 1640, 2060] },
    { code: "SF-0104", name: "ซอยกลางช่องแสง สมาร์ท 86.5 มม.",           baseCost: 1700, sortOrder: 74, v: [1700, 1755, 1865, 2345] },
    { code: "SF-0103", name: "ตบช่องแสง สมาร์ท",                          baseCost: 765,  sortOrder: 75, v: [765,  785,  835,  1045] },
    { code: "SF-0102", name: "คิ้วช่องแสง-กระทุ้ง สมาร์ท",               baseCost: 355,  sortOrder: 76, v: [355,  370,  390,  485]  },
  ];

  await psUpsert(psFolding,  catProSmart.id);
  await psUpsert(psSliding,  catProSmart.id);
  await psUpsert(psAwning,   catProSmart.id);
  await psUpsert(psFixed,    catProSmart.id);

  const psTotal = psFolding.length + psSliding.length + psAwning.length + psFixed.length;

  // ═══════════════════════════════════════════════════════════
  // 14. CATEGORY: Alumet Vista Series
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding category: Alumet Vista Series...");

  const catVista = await prisma.category.upsert({
    where: { slug: "alumet-vista-series" },
    update: { name: "Alumet Vista Series" },
    create: {
      name: "Alumet Vista Series",
      slug: "alumet-vista-series",
      description: "ชุดโปรไฟล์ระแนงบานเปิด ใบระแนง และเฟรม อลูเม็ท วิสต้า — ความยาวเส้น 6.4 ม.",
      sortOrder: 5,
    },
  });
  console.log(`   ✓ ${catVista.name}\n`);

  // ═══════════════════════════════════════════════════════════
  // 15. VISTA SERIES MATERIALS
  //    Source: ราคาขายปลีก_วิสต้า 010867.pdf (effective 1 Aug 2024)
  //    Standard bar length: 6400mm (Wood double-coat: 6100mm)
  //    All prices per bar (เส้น), retail ex-VAT.
  //    baseCost = White/Black (8911/8816) — lowest stock-color tier.
  //    SC-X105 and 030038 are shared cross-series profiles included
  //    in this price list; stored under Vista to avoid duplication.
  // ═══════════════════════════════════════════════════════════
  console.log("→ Seeding Vista Series materials...");

  const vistaProfiles: PSeed[] = [
    // v = [white/black, saharaGrey, saharaSand, wood]
    { code: "VF-0101",    name: "เฟรมนอกบังใบระแนง วิสต้า",        baseCost: 2380, sortOrder: 1, v: [2380, 2450, 2585, 3195] },
    { code: "VF-0102",    name: "เฟรมนอกกล่องระแนง วิสต้า",         baseCost: 2305, sortOrder: 2, v: [2305, 2370, 2500, 3095] },
    { code: "VF-0103",    name: "เฟรมในระแนง วิสต้า",               baseCost: 1220, sortOrder: 3, v: [1220, 1255, 1325, 1630] },
    { code: "VF-0104",    name: "ปิดร่องเฟรมในระแนง วิสต้า",        baseCost: 105,  sortOrder: 4, v: [105,  110,  115,  150]  },
    { code: "VF-SC-X105", name: "ฝาปิดร่อง C-18 สมาร์ท เอ็กซ์ (Vista)", baseCost: 65, sortOrder: 5, v: [65,   70,   75,   85]   },
    { code: "VF-0201",    name: "ใบระแนง วิสต้า 25×48.6 มม.",       baseCost: 1180, sortOrder: 6, v: [1180, 1210, 1280, 1575] },
    { code: "VF-030038",  name: "ก้านสไลด์ มัลติพ้อยท์ล็อก (Vista)", baseCost: 230, sortOrder: 7, v: [230,  235,  250,  305]  },
  ];

  await psUpsert(vistaProfiles, catVista.id);

  // ═══════════════════════════════════════════════════════════
  // 16. CATEGORY: Alumet Smart X Series
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding category: Alumet Smart X Series...");

  const catSmartX = await prisma.category.upsert({
    where: { slug: "alumet-smart-x-series" },
    update: { name: "Alumet Smart X Series" },
    create: {
      name: "Alumet Smart X Series",
      slug: "alumet-smart-x-series",
      description:
        "ชุดโปรไฟล์อลูมิเนียม อลูเม็ท โปร สมาร์ท เอ็กซ์ — บานเลื่อน บานกระทุ้ง บานเปิด และช่องแสง ความยาวเส้น 6.4 ม.",
      sortOrder: 6,
    },
  });
  console.log(`   ✓ ${catSmartX.name}\n`);

  // ═══════════════════════════════════════════════════════════
  // 17. SMART X SERIES MATERIALS
  //    Source: ราคาขายปลีก_สมาร์ทเอ็กซ์ 010867.pdf
  //    Effective: 1 ส.ค. 2567 – 31 ธ.ค. 2567
  //    Standard bar length: 6400 mm/เส้น, prices ex-VAT 7%
  //
  //    Price tiers used for stock-color variants:
  //      P1 → White (8911) / Black (8816)  ← baseCost
  //      P2 → Sahara Grey (8820)
  //      P4 → Sahara Sand (8515)
  //      W  → Wood Grain
  //
  //    Shared non-X codes that also appear in Pro Smart are
  //    prefixed "SMX-" to keep Material.code @unique.
  //    (e.g. SS-0117 → SMX-SS-0117)
  // ═══════════════════════════════════════════════════════════
  console.log("→ Seeding Smart X Series materials...");

  // Re-use the psUpsert helper defined above for Pro Smart.
  // PSeed type: { code, name, baseCost, sortOrder, v: [P1, P2, P4, W] }
  // v[0]=white/black, v[1]=saharaGrey, v[2]=saharaSand, v[3]=wood

  const smartXProfiles: PSeed[] = [
    // ══════════════════════════════════════════════════════════
    // PAGE 1 — ชุดบานเลื่อน โปร สมาร์ท เอ็กซ์ (Sliding Series)
    // ══════════════════════════════════════════════════════════
    // Genuine X-series profiles (SS-X***)
    { code: "SS-X101", name: "เฟรมบนบานเลื่อน 3 ราง สมาร์ท เอ็กซ์",              baseCost: 2030, sortOrder: 1,  v: [2030, 2095, 2220, 2790] },
    { code: "SS-X102", name: "เฟรมล่างบานเลื่อน 3 ราง สมาร์ท เอ็กซ์",             baseCost: 2680, sortOrder: 2,  v: [2680, 2765, 2930, 3685] },
    { code: "SS-X103", name: "เฟรมข้างกล่องเรียบ สมาร์ท เอ็กซ์",                  baseCost: 1440, sortOrder: 3,  v: [1440, 1485, 1570, 1970] },
    { code: "SS-X104", name: "ตบเฟรม 3 รางบานเลื่อนต่อช่องแสง สมาร์ท เอ็กซ์",    baseCost: 1515, sortOrder: 4,  v: [1515, 1560, 1655, 2070] },
    { code: "SS-X201", name: "เสากุญแจบานเลื่อน สมาร์ท เอ็กซ์",                   baseCost: 1415, sortOrder: 9,  v: [1415, 1460, 1550, 1940] },
    { code: "SS-X202", name: "เสากุญแจมือจับบานเลื่อน สมาร์ท เอ็กซ์",             baseCost: 1815, sortOrder: 10, v: [1815, 1870, 1985, 2490] },
    { code: "SS-X203", name: "ขวางบน-ล่าง บานเลื่อน สมาร์ท เอ็กซ์",               baseCost: 1440, sortOrder: 11, v: [1440, 1485, 1575, 1970] },
    { code: "SS-X204", name: "เสริมร่องกระจก 9.5 mm. บานเลื่อน สมาร์ท เอ็กซ์",   baseCost: 270,  sortOrder: 12, v: [270,  280,  295,  365]  },
    { code: "SS-X205", name: "เสริมมุ้งนิรภัยบานเลื่อน สมาร์ท เอ็กซ์",            baseCost: 180,  sortOrder: 13, v: [180,  180,  180,  180]  },
    { code: "SS-X206", name: "ฝาปิดเสริมมุ้งนิรภัยบานเลื่อน สมาร์ท เอ็กซ์",      baseCost: 125,  sortOrder: 14, v: [125,  130,  135,  160]  },
    { code: "SS-X207", name: "เสริมเสามือจับใหญ่บานเลื่อน สมาร์ท เอ็กซ์",         baseCost: 1790, sortOrder: 15, v: [1790, 1850, 1960, 2460] },

    // Shared profiles that appear in both Pro Smart & Smart X price lists.
    // Prefixed "SMX-" to avoid @unique collision on Material.code.
    { code: "SMX-SS-0117", name: "ฝาปิดเสริมเสากุญแจตัวผู้ สมาร์ท (Smart X list)", baseCost: 235, sortOrder: 20, v: [235, 245, 255, 320] },
    { code: "SMX-SS-0120", name: "เสริมปีกเฟรมข้างกล่องเรียบ สมาร์ท (Smart X list)", baseCost: 280, sortOrder: 21, v: [280, 290, 305, 375] },
    { code: "SMX-SS-0145", name: "ตบบรรณ สมาร์ท (Smart X list)",                    baseCost: 490,  sortOrder: 22, v: [490,  505,  535,  670]  },
    { code: "SMX-SC-0103", name: "เสริมช่องแสงกระทุ้ง สมาร์ท (Smart X list)",       baseCost: 715,  sortOrder: 23, v: [715,  735,  780,  975]  },
    { code: "SMX-SS-0139", name: "ตบเกี่ยวเสามัลทีพอยท์ สมาร์ท (Smart X list)",    baseCost: 505,  sortOrder: 24, v: [505,  520,  550,  685]  },
    { code: "SMX-SS-0140", name: "ตบเกี่ยว 2 ทาง เสามัลติพอยท์ สมาร์ท (Smart X list)", baseCost: 805, sortOrder: 25, v: [805, 825, 875, 1100] },
    { code: "SMX-SS-0141", name: "เสริมเสากุญแจตัวผู้ สมาร์ท 20 มม. (Smart X list)", baseCost: 610, sortOrder: 26, v: [610, 630, 665, 835] },
    { code: "SMX-2044",    name: "เสริมมุ้งบานเลื่อน (Smart X list)",               baseCost: 215,  sortOrder: 27, v: [215,  220,  235,  295]  },
    { code: "SMX-030038",  name: "ก้านสไลด์ มัลติพอยท์ล็อค (Smart X list)",        baseCost: 230,  sortOrder: 28, v: [230,  235,  250,  305]  },

    // ══════════════════════════════════════════════════════════
    // PAGE 2 — ชุดบานกระทุ้ง บานเปิด & ช่องแสง (Awning/Casement/Fixed)
    // ══════════════════════════════════════════════════════════
    // Awning frame profiles (SC-X***)
    { code: "SC-X101", name: "เฟรมบน-ข้างบานกระทุ้ง สมาร์ท เอ็กซ์",               baseCost: 1535, sortOrder: 30, v: [1535, 1580, 1675, 2095] },
    { code: "SC-X102", name: "เฟรมบานกระทุ้ง สมาร์ท เอ็กซ์",                       baseCost: 1745, sortOrder: 31, v: [1745, 1800, 1905, 2395] },
    { code: "SC-X103", name: "ซอยเฟรมบานกระทุ้ง สมาร์ท เอ็กซ์",                    baseCost: 2420, sortOrder: 32, v: [2420, 2495, 2645, 3310] },
    { code: "SC-X104", name: "ตบเฟรมบานกระทุ้ง สมาร์ท เอ็กซ์",                     baseCost: 1370, sortOrder: 33, v: [1370, 1410, 1495, 1875] },
    { code: "SC-X105", name: "ฝาปิดร่อง C-18 สมาร์ท เอ็กซ์",                       baseCost: 65,   sortOrder: 34, v: [65,   70,   75,   85]   },
    { code: "SC-X106", name: "เสริมช่องแสงเฟรมบานกระทุ้ง สมาร์ท เอ็กซ์",           baseCost: 730,  sortOrder: 35, v: [730,  755,  800,  995]  },
    { code: "SC-X201", name: "กรอบบานกระทุ้ง สมาร์ท เอ็กซ์",                       baseCost: 1540, sortOrder: 36, v: [1540, 1590, 1685, 2110] },
    { code: "SC-X202", name: "เสริมมุ้งบานกระทุ้ง สมาร์ท เอ็กซ์",                  baseCost: 285,  sortOrder: 37, v: [285,  295,  315,  390]  },

    // Shared awning/casement trim profiles — prefixed to avoid collision
    { code: "SMX-A30274",  name: "คิ้วช่องแสงเฟรมกระทุ้ง พรีเมี่ยม (Smart X list)", baseCost: 445, sortOrder: 38, v: [445, 460, 485, 600] },
    { code: "SMX-SF-0102", name: "คิ้วช่องแสง-กระทุ้ง สมาร์ท (Smart X list)",       baseCost: 355, sortOrder: 39, v: [355, 370, 390, 485] },

    // Fixed glazing profiles (SF-X***)
    { code: "SF-X101", name: "เฟรมช่องแสง สมาร์ท เอ็กซ์",                          baseCost: 1560, sortOrder: 40, v: [1560, 1610, 1705, 2135] },
    { code: "SF-X102", name: "เฟรมซอยช่องแสง สมาร์ท เอ็กซ์",                       baseCost: 2085, sortOrder: 41, v: [2085, 2150, 2280, 2865] },
    { code: "SF-X103", name: "ตบช่องแสง สมาร์ท เอ็กซ์",                             baseCost: 975,  sortOrder: 42, v: [975,  1005, 1060, 1330] },

    // Misc shared profiles — prefixed
    { code: "SMX-2005", name: "เส้นคาดกลางมุ้ง (Smart X list)", baseCost: 165, sortOrder: 50, v: [165, 170, 180, 0] },

    // ── New Smart X profiles from ราคาปลีกสีสต็อก_สมาร์X110569 ล่าสุด ──
    { code: "SS-X109", name: "เฟรมล่างบานเลื่อน 3 ราง หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 3010, sortOrder: 201, v: [3010, 3085, 3245, 3995] },
    { code: "SS-X110", name: "เฟรมบนบานเลื่อน 3 ราง หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 2410, sortOrder: 202, v: [2410, 2470, 2600, 0] },
    { code: "SS-X111", name: "เฟรมข้างกล่องเรียบ หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1645, sortOrder: 203, v: [1645, 1685, 1770, 2215] },
    { code: "SS-0121", name: "เฟรมล่าง 3 ราง (ภายใน) สมาร์ท เอ็กซ์", baseCost: 1530, sortOrder: 204, v: [1530, 1570, 1650, 2060] },
    { code: "SS-X105", name: "ตบกรีดเสริมมุมมาตรฐาน (ล่าง) บานเลื่อน สมาร์ท เอ็กซ์", baseCost: 655, sortOrder: 205, v: [655, 670, 705, 895] },
    { code: "SS-X106", name: "ตบกรีดเสริมมุมมาตรฐาน (บน) บานเลื่อน สมาร์ท เอ็กซ์", baseCost: 755, sortOrder: 206, v: [755, 775, 815, 1035] },
    { code: "SS-X108", name: "ตบกรีด สมาร์ท เอ็กซ์", baseCost: 665, sortOrder: 207, v: [665, 680, 0, 905] },
    { code: "SS-X107", name: "เสริมคีบเฟรมข้างกล่องเรียบ (มีกั้น) สมาร์ท เอ็กซ์", baseCost: 595, sortOrder: 208, v: [595, 610, 640, 895] },
    { code: "SS-X113", name: "รางเนื้อยึดบนด้านบนในห้อง สมาร์ท เอ็กซ์", baseCost: 2105, sortOrder: 209, v: [2105, 2160, 2270, 2800] },
    { code: "SS-X114", name: "ฝาครอบติดรางเนื้อ สมาร์ท เอ็กซ์", baseCost: 615, sortOrder: 210, v: [615, 630, 665, 845] },
    { code: "SS-X115", name: "เสริมยึดล่อรางเนื้อ สมาร์ท เอ็กซ์", baseCost: 810, sortOrder: 211, v: [810, 835, 875, 1100] },
    { code: "SS-X116", name: "รางเนื้อยึดบนด้านข้าง สมาร์ท เอ็กซ์", baseCost: 2700, sortOrder: 212, v: [2700, 2770, 2915, 3595] },
    { code: "SS-0147", name: "เสาบานเแกลิเลือก ร่อง 9.5 หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1315, sortOrder: 213, v: [1315, 1350, 1420, 0] },
    { code: "SS-0123", name: "ตบเคียวทางเดียว (เสาคิลเลือก) สมาร์ท เอ็กซ์", baseCost: 640, sortOrder: 214, v: [640, 660, 690, 880] },
    { code: "SS-0114", name: "ตบเคียวสองทาง (เสาคิลเลือก) สมาร์ท เอ็กซ์", baseCost: 900, sortOrder: 215, v: [900, 920, 965, 1210] },
    { code: "SS-0116", name: "เสริมเสาบานตัวเมีย (เสาคิลเลือก) สมาร์ท เอ็กซ์", baseCost: 500, sortOrder: 216, v: [500, 510, 535, 690] },
    { code: "SS-0138", name: "เสาบานเแกมัลติพอยท์ ร่อง 9.5 หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1640, sortOrder: 217, v: [1640, 1680, 1765, 2150] },
    { code: "SS-0139", name: "ตบเคียวทางเดียว (เสามัลติพอยท์) สมาร์ท เอ็กซ์", baseCost: 645, sortOrder: 218, v: [645, 660, 695, 845] },
    { code: "SS-0140", name: "ตบเคียวสองทาง (เสามัลติพอยท์) สมาร์ท เอ็กซ์", baseCost: 1030, sortOrder: 219, v: [1030, 1055, 1110, 1370] },
    { code: "SS-0141", name: "เสริมเสาบานตัวเมีย มัลติพอยท์ล็อก สมาร์ท เอ็กซ์", baseCost: 805, sortOrder: 220, v: [805, 825, 870, 1090] },
    { code: "SS-X217", name: "งวางบน-ล่าง (ล็อตลัก) ร่อง 9.5 หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1680, sortOrder: 221, v: [1680, 1725, 1810, 2245] },
    { code: "SS-0105", name: "งวางบน-ล่าง (ล็อตลาด) ร่อง 9.5 หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1355, sortOrder: 222, v: [1355, 1390, 1460, 1815] },
    { code: "SS-0124", name: "งวางล่าง (ภายใน) ร่อง 9.5 หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1230, sortOrder: 223, v: [1230, 1265, 1330, 1650] },
    { code: "SS-0146", name: "เสริมงวางล่างไส้ล็อตลัก สมาร์ท เอ็กซ์", baseCost: 860, sortOrder: 224, v: [860, 0, 0, 0] },
    { code: "SS-X209", name: "เสาบานเแกมัลติพอยท์ ร่อง 9.5 หนา 1.5 มม. สมาร์ท เอ็กซ์", baseCost: 1860, sortOrder: 225, v: [1860, 1910, 2005, 2445] },
    { code: "SS-X210", name: "งวางบน-ล่าง (ล็อตลัก) ร่อง 9.5 หนา 1.5 มม. สมาร์ท เอ็กซ์", baseCost: 1905, sortOrder: 226, v: [1905, 1955, 2055, 2540] },
    { code: "SS-X218", name: "ขอยลูกกั้นบานเลื่อน ร่อง 16 หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1205, sortOrder: 227, v: [1205, 1235, 1300, 1615] },
    { code: "SS-X208", name: "เสริมเสามือกั้นเล็ก บานเลื่อน สมาร์ท เอ็กซ์", baseCost: 1705, sortOrder: 228, v: [1705, 1750, 1840, 2340] },
    { code: "SC-X107", name: "เฟรมบน-ข้างบานกระทุ้ง คีบรูปขอบ สมาร์ท เอ็กซ์", baseCost: 2000, sortOrder: 229, v: [2000, 2055, 2160, 2750] },
    { code: "SC-X108", name: "เฟรมล่างบานกระทุ้ง คีบรูปขอบ สมาร์ท เอ็กซ์", baseCost: 2245, sortOrder: 230, v: [2245, 2305, 2420, 3085] },
    { code: "SC-X109", name: "ขอยเฟรมบานกระทุ้ง คีบรูปขอบ สมาร์ท เอ็กซ์", baseCost: 3070, sortOrder: 231, v: [3070, 3150, 3310, 4075] },
    { code: "SC-X110", name: "เสริมร่องคีบรูปเท สมาร์ท เอ็กซ์", baseCost: 375, sortOrder: 232, v: [375, 385, 405, 515] },
    { code: "SO-X201", name: "กรอบบานประตูบานเปิด 165 มม. หนา 1.5 มม. สมาร์ท เอ็กซ์", baseCost: 4080, sortOrder: 233, v: [4080, 4190, 4405, 5410] },
    { code: "SO-X202", name: "กรอบบานประตูบานเปิด 100 มม. หนา 1.5 มม. สมาร์ท เอ็กซ์", baseCost: 2925, sortOrder: 234, v: [2925, 3000, 3155, 3885] },
    { code: "SC-X203", name: "ขอยกรอบบานกระทุ้ง หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1665, sortOrder: 235, v: [1665, 1705, 1795, 2220] },
    { code: "SC-X204", name: "กรอบบานกระทุ้ง 85 มม. หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 2425, sortOrder: 236, v: [2425, 2485, 2615, 3225] },
    { code: "SC-0212", name: "เสริมเสาบานเปิดคู่ สมาร์ท เอ็กซ์", baseCost: 1225, sortOrder: 237, v: [1225, 1255, 1320, 1600] },
    { code: "SC-X205", name: "เสริมมุมบานกระทุ้ง สมาร์ท เอ็กซ์", baseCost: 430, sortOrder: 238, v: [430, 440, 465, 600] },
    { code: "SF-X110", name: "เฟรมบน-ข้างช่องแสง หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1655, sortOrder: 239, v: [1655, 1700, 1785, 2210] },
    { code: "SF-X109", name: "เฟรมล่างช่องแสง สมาร์ท เอ็กซ์", baseCost: 2015, sortOrder: 240, v: [2015, 2070, 2175, 2685] },
    { code: "SF-X107", name: "ขอยเฟรมช่องแสง หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 2675, sortOrder: 241, v: [2675, 2745, 2885, 3560] },
    { code: "SF-X104", name: "ตบเฟรมช่องแสง หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 1190, sortOrder: 242, v: [1190, 1220, 1280, 0] },
    { code: "SF-X108", name: "คิ้วช่องแสง,บานเปิด ร่อง 12.7 มม. สมาร์ท เอ็กซ์", baseCost: 530, sortOrder: 243, v: [530, 545, 570, 695] },
    { code: "SF-X111", name: "คิ้วช่องแสง,บานเปิด ร่อง 20 มม. สมาร์ท เอ็กซ์", baseCost: 495, sortOrder: 244, v: [495, 505, 530, 685] },
    { code: "SF-X106", name: "คิ้วช่องแสง,บานเปิด ร่อง 32.5 มม. สมาร์ท เอ็กซ์", baseCost: 350, sortOrder: 245, v: [350, 360, 380, 500] },
    { code: "SF-X105", name: "เสริมช่องแสงเฟรมกระทุ้ง สมาร์ท เอ็กซ์", baseCost: 865, sortOrder: 246, v: [865, 885, 930, 0] },
    { code: "SB-0101", name: "เฟรมบนบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 6070, sortOrder: 247, v: [6070, 6230, 6550, 8025] },
    { code: "SB-0105", name: "เฟรมข้างบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 2630, sortOrder: 248, v: [2630, 2700, 2840, 3500] },
    { code: "SB-0103", name: "เฟรมล่างบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 2455, sortOrder: 249, v: [2455, 2520, 2650, 3270] },
    { code: "SB-0102", name: "เฟรมบนบานเฟี้ยม (ภายใน) สมาร์ท เอ็กซ์", baseCost: 3795, sortOrder: 250, v: [3795, 3895, 4095, 5030] },
    { code: "SB-0112", name: "เฟรมข้างบานเฟี้ยม (ภายใน) สมาร์ท เอ็กซ์", baseCost: 1310, sortOrder: 251, v: [1310, 1340, 1410, 1750] },
    { code: "SB-0116", name: "เฟรมล่างบานเฟี้ยม (ภายใน) สมาร์ท เอ็กซ์", baseCost: 1645, sortOrder: 252, v: [1645, 1685, 1770, 2195] },
    { code: "SB-0115", name: "รางกั้นพื้นบานเฟี้ยม (ภายใน) สมาร์ท เอ็กซ์", baseCost: 670, sortOrder: 253, v: [670, 685, 720, 915] },
    { code: "SB-0114", name: "เสาประตูบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 2570, sortOrder: 254, v: [2570, 2635, 2775, 3380] },
    { code: "SB-0107", name: "งวางบน-ล่างบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 2225, sortOrder: 255, v: [2225, 2285, 2400, 2965] },
    { code: "SB-0111", name: "ขอยลูกกั้นบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 1490, sortOrder: 256, v: [1490, 1530, 1605, 1990] },
    { code: "SB-0108", name: "คิ้วบานบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 435, sortOrder: 257, v: [435, 445, 465, 565] },
    { code: "SB-0109", name: "คิ้วหนาบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 660, sortOrder: 258, v: [660, 675, 710, 900] },
    { code: "SB-0110", name: "คิ้วกั้นเนือบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 305, sortOrder: 259, v: [305, 310, 325, 435] },
    { code: "SB-0117", name: "เสริมเสาบานเปิดกลาง บานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 1150, sortOrder: 260, v: [1150, 1180, 1240, 1505] },
    { code: "SB-0113", name: "เสาบานเปิดคู่บานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 2225, sortOrder: 261, v: [2225, 2280, 2400, 2960] },
    { code: "SB-0118", name: "เสริมเสามุมบานเฟี้ยม สมาร์ท เอ็กซ์", baseCost: 2070, sortOrder: 262, v: [2070, 2125, 2235, 2760] },
    { code: "iS-0209", name: "ฝาปิดสกรูตบเคียว อไอคอนิค", baseCost: 110, sortOrder: 263, v: [110, 115, 120, 145] },
    { code: "iO-0102-SMX", name: "เสริมกรีดเฟรมกระทุ้ง อไอคอนิค (Smart X list)", baseCost: 1150, sortOrder: 264, v: [1150, 1180, 1240, 1540] },
    { code: "iC-0110-SMX", name: "ตบเฟรมกระทุ้ง คีบรูปขอบ อไอคอนิค (Smart X list)", baseCost: 1885, sortOrder: 265, v: [1885, 1935, 2030, 2465] },
    { code: "iO-0206-SMX", name: "เสริมงวางล้ำกระทุ้งบานเปิด อไอคอนิค (Smart X list)", baseCost: 760, sortOrder: 266, v: [760, 780, 820, 1030] },
    { code: "iO-0207-SMX", name: "ฝาตัดมุม อไอคอนิค (Smart X list)", baseCost: 2735, sortOrder: 267, v: [2735, 0, 0, 0] },
    { code: "iO-0208-SMX", name: "ลูกบูบเรียบ 2 หน้า หนา 30 มม. อไอคอนิค (Smart X list)", baseCost: 3030, sortOrder: 268, v: [3030, 3110, 2690, 3975] },
    { code: "iO-0209-SMX", name: "กล่องระหว่าง 25x25 มีสกรู อไอคอนิค (Smart X list)", baseCost: 865, sortOrder: 269, v: [865, 885, 930, 0] },
    { code: "iO-0210-SMX", name: "เฟรมระแนง 30x11 อไอคอนิค (Smart X list)", baseCost: 575, sortOrder: 270, v: [575, 590, 615, 785] },

    // ── Missing profiles identified via Smart X Catalogue 2026 cross-reference ──
    // Source: Smart X_Catalogue 2026_100369.pdf — not in stock price list (prices estimated from catalogue weight × 120 THB/kg)
    { code: "SF-X112", name: "คิ้วลอยช่องแสง สมาร์ท เอ็กซ์",                           baseCost: 250, sortOrder: 271, v: [250, 250, 250, 0] },
    { code: "SF-X113", name: "ตบเรียบ สมาร์ท เอ็กซ์",                                  baseCost: 295, sortOrder: 272, v: [295, 295, 295, 0] },
    { code: "SS-X211", name: "เสริมเกี่ยวสองทาง สมาร์ท เอ็กซ์",                        baseCost: 143, sortOrder: 273, v: [143, 143, 143, 0] },
    { code: "SS-X212", name: "เสากุญแจเข้ามุม 45 ร่อง 9.5 หนา 1.2 มม. สมาร์ท เอ็กซ์", baseCost: 694, sortOrder: 274, v: [694, 694, 694, 0] },
    { code: "SS-X213", name: "เสริมเสากุญแจเข้ามุม (ตัวเมีย) สมาร์ท เอ็กซ์",            baseCost: 319, sortOrder: 275, v: [319, 319, 319, 0] },
    { code: "SS-X214", name: "เสริมเสากุญแจเข้ามุม (ตัวผู้) สมาร์ท เอ็กซ์",            baseCost: 291, sortOrder: 276, v: [291, 291, 291, 0] },
    { code: "SS-X215", name: "ตบเกี่ยวสองทาง (เสา 45 องศา) สมาร์ท เอ็กซ์",             baseCost: 361, sortOrder: 277, v: [361, 361, 361, 0] },
    { code: "SS-X216", name: "ตบเกี่ยวทางเดียว (เสา 45 องศา) สมาร์ท เอ็กซ์",           baseCost: 224, sortOrder: 278, v: [224, 224, 224, 0] },
  ];

  await psUpsert(smartXProfiles, catSmartX.id);

  // ═══════════════════════════════════════════════════════════
  // 18. CATEGORY: Alumet Accessories
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding category: Alumet Accessories...");

  const catAcc = await prisma.category.upsert({
    where: { slug: "alumet-accessories" },
    update: { name: "Alumet Accessories" },
    create: {
      name: "Alumet Accessories",
      slug: "alumet-accessories",
      description: "อุปกรณ์ประกอบอลูมิเนียม Alumet — บานพับ มือจับ ล้อ กุญแจ ยาง และอุปกรณ์ติดตั้งทั่วไป",
      sortOrder: 7,
    },
  });
  console.log(`   ✓ ${catAcc.name}\n`);

  // ═══════════════════════════════════════════════════════════
  // 19. ACCESSORIES MATERIALS
  //    Source: ราคาขายปลีกอุปกรณ์ 030368.pdf
  //    Effective: 3 มี.ค. 2568 – 31 ธ.ค. 2568 (ex-VAT 7%)
  //    118 items across Baan Fiam, EuroCasement, Multi-Slide sections
  // ═══════════════════════════════════════════════════════════
  console.log("→ Seeding Accessories materials...");

  type AccSeedItem = {
    code: string; name: string; unit: string; baseCost: number;
    sortOrder: number; variants: { colorId: string; unitCost: number }[];
  };

  const accItems: AccSeedItem[] = [
    { code: "AKL-SMBF001", name: "บานพับล้อบนบานเฟ้ียม", unit: "ชิ้น", baseCost: 450, sortOrder: 1, variants: [{ colorId: colorWhite.id, unitCost: 125 }, { colorId: colorBlack.id, unitCost: 125 }] },
    { code: "AKL-SMBF002", name: "บานพับไกด์ล่างบานเฟ้ียม", unit: "ชิ้น", baseCost: 385, sortOrder: 2, variants: [{ colorId: colorWhite.id, unitCost: 385 }, { colorId: colorBlack.id, unitCost: 385 }] },
    { code: "AKL-SMBF003", name: "บานพับบานเฟ้ียม", unit: "ชิ้น", baseCost: 105, sortOrder: 3, variants: [{ colorId: colorWhite.id, unitCost: 105 }, { colorId: colorBlack.id, unitCost: 105 }] },
    { code: "AKL-SMBF004", name: "บานพับมือจับบานเฟ้ียม", unit: "ชิ้น", baseCost: 170, sortOrder: 4, variants: [{ colorId: colorWhite.id, unitCost: 170 }, { colorId: colorBlack.id, unitCost: 170 }] },
    { code: "AKL-SMBF005", name: "CDQ 20 สองทาง", unit: "ชิ้น", baseCost: 105, sortOrder: 5, variants: [{ colorId: colorWhite.id, unitCost: 105 }] },
    { code: "AKL-SMBF009", name: "ก้านล็อคบน-ล่าง (50 ซม.)", unit: "ชิ้น", baseCost: 215, sortOrder: 6, variants: [{ colorId: colorWhite.id, unitCost: 215 }, { colorId: colorBlack.id, unitCost: 215 }] },
    { code: "AKL-SMBF010", name: "ตัวรับล็อกเฟรมบานเฟ้ียม", unit: "ชิ้น", baseCost: 30, sortOrder: 7, variants: [{ colorId: colorWhite.id, unitCost: 30 }] },
    { code: "AKL-SMBF013", name: "ไส้กุญแจทางเดียว (37/37 มม.)", unit: "ชิ้น", baseCost: 270, sortOrder: 8, variants: [{ colorId: colorWhite.id, unitCost: 270 }] },
    { code: "AKL-SMBF017", name: "ใส้กุญแจ 2 ทาง (37/37 มม.)", unit: "ชิ้น", baseCost: 260, sortOrder: 9, variants: [{ colorId: colorWhite.id, unitCost: 260 }] },
    { code: "AKL-SMBF018", name: "เสื้อกุญแจ #32-85 ซิงเกิล", unit: "ชิ้น", baseCost: 345, sortOrder: 10, variants: [{ colorId: colorWhite.id, unitCost: 345 }] },
    { code: "AKL-SMBF019", name: "ล้อบนบานเฟ้ียมคู่", unit: "ชิ้น", baseCost: 510, sortOrder: 11, variants: [{ colorId: colorWhite.id, unitCost: 510 }, { colorId: colorBlack.id, unitCost: 510 }] },
    { code: "AKL-SMBF020", name: "ไกด์ล่างบานเฟ้ียมคู่", unit: "ชิ้น", baseCost: 390, sortOrder: 12, variants: [{ colorId: colorWhite.id, unitCost: 390 }, { colorId: colorBlack.id, unitCost: 390 }] },
    { code: "AKL-SMBF021", name: "ยางลูกโป่งบานเฟ้ียม (100 เมตร)", unit: "ม้วน", baseCost: 1150, sortOrder: 13, variants: [{ colorId: colorBlack.id, unitCost: 1150 }] },
    { code: "AKL-SMBF022", name: "เสื้อกุญแจ #32-85 มัลติพ้อยท์ล็อก", unit: "ชิ้น", baseCost: 395, sortOrder: 14, variants: [{ colorId: colorWhite.id, unitCost: 395 }] },
    { code: "AKL-SMBF023", name: "มือจับประตู", unit: "ชิ้น", baseCost: 280, sortOrder: 15, variants: [{ colorId: colorWhite.id, unitCost: 280 }, { colorId: colorBlack.id, unitCost: 280 }] },
    { code: "AKL-SMBF024", name: "มือจับประตูดัมมี่", unit: "ชิ้น", baseCost: 290, sortOrder: 16, variants: [{ colorId: colorWhite.id, unitCost: 290 }, { colorId: colorBlack.id, unitCost: 290 }] },
    { code: "AKL-SMBF025", name: "ตลับกุญแจใหญ่ (CDQ30/I)", unit: "ชิ้น", baseCost: 315, sortOrder: 17, variants: [{ colorId: colorWhite.id, unitCost: 315 }] },
    { code: "AKL-SMBF026", name: "ฝาครอบกุญแจ", unit: "ชิ้น", baseCost: 45, sortOrder: 18, variants: [{ colorId: colorWhite.id, unitCost: 45 }, { colorId: colorBlack.id, unitCost: 45 }] },
    { code: "AKL-SMBF027", name: "มือจับบานกระทุ้ง (Spindle L30)", unit: "ชิ้น", baseCost: 190, sortOrder: 19, variants: [{ colorId: colorWhite.id, unitCost: 190 }, { colorId: colorBlack.id, unitCost: 190 }] },
    { code: "AKL-SMBF028", name: "มือจับ (ปากเป็ด)", unit: "ชิ้น", baseCost: 120, sortOrder: 20, variants: [{ colorId: colorWhite.id, unitCost: 120 }, { colorId: colorBlack.id, unitCost: 120 }] },
    { code: "AKL-SMBF029", name: "เพลทรับกลอนประตู", unit: "ชิ้น", baseCost: 40, sortOrder: 21, variants: [{ colorId: colorWhite.id, unitCost: 40 }] },
    { code: "AKL-SMBF030", name: "ปลายกลอน บานเฟ้ียม", unit: "ชิ้น", baseCost: 105, sortOrder: 22, variants: [{ colorId: colorWhite.id, unitCost: 105 }] },
    { code: "AKL-SMBF031", name: "มือจับ (ปากเป็ด)", unit: "ชิ้น", baseCost: 300, sortOrder: 23, variants: [{ colorId: colorWhite.id, unitCost: 300 }, { colorId: colorBlack.id, unitCost: 300 }, { colorId: colorSilver.id, unitCost: 300 }] },
    { code: "ACF-EUCA001", name: "บานพับ Hinge 80 กก.", unit: "ชิ้น", baseCost: 180, sortOrder: 24, variants: [{ colorId: colorWhite.id, unitCost: 180 }, { colorId: colorBlack.id, unitCost: 180 }, { colorId: colorSilver.id, unitCost: 180 }] },
    { code: "AKL-EUCA002", name: "บานพับ Hinge 55 กก. (ซ้าย)", unit: "ชิ้น", baseCost: 130, sortOrder: 25, variants: [{ colorId: colorWhite.id, unitCost: 130 }, { colorId: colorBlack.id, unitCost: 130 }, { colorId: colorSilver.id, unitCost: 130 }] },
    { code: "AKL-EUCA003", name: "บานพับ Hinge 55 กก. (ขวา)", unit: "ชิ้น", baseCost: 130, sortOrder: 26, variants: [{ colorId: colorWhite.id, unitCost: 130 }, { colorId: colorBlack.id, unitCost: 130 }, { colorId: colorSilver.id, unitCost: 130 }] },
    { code: "AKL-EUCA004", name: "บานพับ Hinge 120 กก. (ซ้าย)", unit: "ชิ้น", baseCost: 330, sortOrder: 27, variants: [{ colorId: colorWhite.id, unitCost: 330 }, { colorId: colorBlack.id, unitCost: 330 }, { colorId: colorSilver.id, unitCost: 330 }] },
    { code: "AKL-EUCA005", name: "บานพับ Hinge 120 กก. (ขวา)", unit: "ชิ้น", baseCost: 330, sortOrder: 28, variants: [{ colorId: colorWhite.id, unitCost: 330 }, { colorId: colorBlack.id, unitCost: 330 }, { colorId: colorSilver.id, unitCost: 330 }] },
    { code: "AKL-EUCA006", name: "บานพับซ่อน 8 นิ้ว 65 กก. (ซ้าย)", unit: "ชิ้น", baseCost: 215, sortOrder: 29, variants: [{ colorId: colorWhite.id, unitCost: 215 }] },
    { code: "AKL-EUCA007", name: "บานพับซ่อน 8 นิ้ว 65 กก. (ขวา)", unit: "ชิ้น", baseCost: 215, sortOrder: 30, variants: [{ colorId: colorWhite.id, unitCost: 215 }] },
    { code: "ACF-EUCA014", name: "ขาค ้าบานเปิด 16 นิ้ว", unit: "ชิ้น", baseCost: 120, sortOrder: 31, variants: [{ colorId: colorWhite.id, unitCost: 120 }] },
    { code: "ACF-EUCA017", name: "มือจับ (Fork)", unit: "ชิ้น", baseCost: 215, sortOrder: 32, variants: [{ colorId: colorWhite.id, unitCost: 215 }, { colorId: colorBlack.id, unitCost: 215 }, { colorId: colorSilver.id, unitCost: 215 }] },
    { code: "ACF-EUCA018", name: "มือจับ (Spindle L30)", unit: "ชิ้น", baseCost: 206, sortOrder: 33, variants: [{ colorId: colorWhite.id, unitCost: 206 }, { colorId: colorBlack.id, unitCost: 206 }, { colorId: colorSilver.id, unitCost: 206 }] },
    { code: "AKL-EUCA019", name: "มือจับ ประตูบานเปิด #85", unit: "ชิ้น", baseCost: 500, sortOrder: 34, variants: [{ colorId: colorWhite.id, unitCost: 500 }, { colorId: colorBlack.id, unitCost: 500 }, { colorId: colorSilver.id, unitCost: 500 }] },
    { code: "AKL-EUCA020", name: "มือจับดัมมี่ ประตูบานเปิด #85", unit: "ชิ้น", baseCost: 500, sortOrder: 35, variants: [{ colorId: colorWhite.id, unitCost: 500 }, { colorId: colorBlack.id, unitCost: 500 }, { colorId: colorSilver.id, unitCost: 500 }] },
    { code: "AKL-EUCA021", name: "ไกด์ซับพอร์ทข้าง-วงกบ", unit: "ชิ้น", baseCost: 35, sortOrder: 36, variants: [{ colorId: colorWhite.id, unitCost: 35 }] },
    { code: "AKL-EUCA023", name: "บานพับกระทุ้ง 12 นิ้ว 40 กก.", unit: "ชิ้น", baseCost: 140, sortOrder: 37, variants: [{ colorId: colorWhite.id, unitCost: 140 }] },
    { code: "AKL-EUCA024", name: "บานพับกระทุ้ง 16 นิ้ว 65 กก.", unit: "ชิ้น", baseCost: 215, sortOrder: 38, variants: [{ colorId: colorWhite.id, unitCost: 215 }] },
    { code: "AKL-EUCA025", name: "กันลมตี 10 นิ้ว (ซ้าย)", unit: "ชิ้น", baseCost: 120, sortOrder: 39, variants: [{ colorId: colorWhite.id, unitCost: 120 }] },
    { code: "AKL-EUCA026", name: "กันลมตี 10 นิ้ว (ขวา)", unit: "ชิ้น", baseCost: 120, sortOrder: 40, variants: [{ colorId: colorWhite.id, unitCost: 120 }] },
    { code: "AKL-EUCA027", name: "ใส้กุญแจทางเดียว 35/35", unit: "ชิ้น", baseCost: 270, sortOrder: 41, variants: [{ colorId: colorWhite.id, unitCost: 270 }] },
    { code: "AKL-EUCA028", name: "ปลายกลอนบานเปิด", unit: "ชิ้น", baseCost: 30, sortOrder: 42, variants: [{ colorId: colorWhite.id, unitCost: 30 }] },
    { code: "AKL-EUCA029", name: "ตัวรับปลายกลอนบานเปิด", unit: "ชิ้น", baseCost: 25, sortOrder: 43, variants: [{ colorId: colorWhite.id, unitCost: 25 }] },
    { code: "AKL-EUCA030", name: "รับกลอนสแตนเลส (แบบฝังพื้น)", unit: "ชิ้น", baseCost: 75, sortOrder: 44, variants: [{ colorId: colorWhite.id, unitCost: 75 }] },
    { code: "ACF-EUCA031", name: "เพลทรับกลอนประตู", unit: "ชิ้น", baseCost: 140, sortOrder: 45, variants: [{ colorId: colorWhite.id, unitCost: 140 }] },
    { code: "ACF-EUCA032", name: "ขาค ้าบานเปิด 12 นิ้ว", unit: "ชิ้น", baseCost: 100, sortOrder: 46, variants: [{ colorId: colorWhite.id, unitCost: 100 }] },
    { code: "AAL-EUCA034", name: "ฉากสแตนเลส 6.6 มม.(100 ชิ้น/แพค)", unit: "แพค", baseCost: 200, sortOrder: 47, variants: [{ colorId: colorWhite.id, unitCost: 200 }] },
    { code: "ACF-EUCA035", name: "มือจับบานกระทุ้ง Nordic Series", unit: "ชิ้น", baseCost: 206, sortOrder: 48, variants: [{ colorId: colorWhite.id, unitCost: 206 }, { colorId: colorBlack.id, unitCost: 206 }, { colorId: colorSilver.id, unitCost: 206 }] },
    { code: "ACF-EUCA036", name: "มือจับหลบมุ้ง Nordic Series (ซ้าย)", unit: "ชิ้น", baseCost: 206, sortOrder: 49, variants: [{ colorId: colorWhite.id, unitCost: 206 }, { colorId: colorBlack.id, unitCost: 206 }, { colorId: colorSilver.id, unitCost: 206 }] },
    { code: "ACF-EUCA037", name: "มือจับหลบมุ้ง Nordic Series (ขวา)", unit: "ชิ้น", baseCost: 206, sortOrder: 50, variants: [{ colorId: colorWhite.id, unitCost: 206 }, { colorId: colorBlack.id, unitCost: 206 }, { colorId: colorSilver.id, unitCost: 206 }] },
    { code: "ACF-EUCA038", name: "มือจับกระทุ้ง/บานมุ้ง Nordic Series", unit: "ชิ้น", baseCost: 265, sortOrder: 51, variants: [{ colorId: colorWhite.id, unitCost: 265 }, { colorId: colorBlack.id, unitCost: 265 }, { colorId: colorSilver.id, unitCost: 265 }] },
    { code: "ACF-EUCA039", name: "บาบพับมุ้งซ่อน 10 Kg ซ้าย", unit: "ชิ้น", baseCost: 150, sortOrder: 52, variants: [{ colorId: colorWhite.id, unitCost: 150 }] },
    { code: "ACF-EUCA040", name: "บาบพับมุ้งซ่อน 10 Kg ขวา", unit: "ชิ้น", baseCost: 150, sortOrder: 53, variants: [{ colorId: colorWhite.id, unitCost: 150 }] },
    { code: "ACF-EUCA041", name: "บานซ่อน 12\" 60 Kg ซ้าย", unit: "ชิ้น", baseCost: 270, sortOrder: 54, variants: [{ colorId: colorWhite.id, unitCost: 270 }] },
    { code: "ACF-EUCA042", name: "บานซ่อน 12\" 60 Kg ขวา", unit: "ชิ้น", baseCost: 270, sortOrder: 55, variants: [{ colorId: colorWhite.id, unitCost: 270 }] },
    { code: "ACF-EUCA044", name: "CDQ 27.5 (ยิงสกรูยึด)", unit: "ชิ้น", baseCost: 200, sortOrder: 56, variants: [{ colorId: colorBlack.id, unitCost: 200 }] },
    { code: "ACF-EUCA045", name: "หมุดล็อกกระดุมต่อปลาย 8 มม.", unit: "ชิ้น", baseCost: 45, sortOrder: 57, variants: [{ colorId: colorBlack.id, unitCost: 45 }] },
    { code: "ACF-EUCA046", name: "หมุดล็อกกระดุมต่อกลาง 8 มม.", unit: "ชิ้น", baseCost: 45, sortOrder: 58, variants: [{ colorId: colorBlack.id, unitCost: 45 }] },
    { code: "ACF-EUCA047", name: "ตัวรับล็อกกระดุม 8 มม.", unit: "ชิ้น", baseCost: 25, sortOrder: 59, variants: [{ colorId: colorBlack.id, unitCost: 25 }] },
    { code: "ACF-EUCA048", name: "ตัวรับล็อกมัลติพ้อยท์ล็อก", unit: "ชิ้น", baseCost: 35, sortOrder: 60, variants: [{ colorId: colorBlack.id, unitCost: 35 }] },
    { code: "ACF-EUCA049", name: "ตัวล็อกดึงบาน", unit: "ชิ้น", baseCost: 65, sortOrder: 61, variants: [{ colorId: colorBlack.id, unitCost: 65 }] },
    { code: "ACF-EUCA050", name: "ไกด์ซับพอร์ทข้าง-วงกบ", unit: "ชิ้น", baseCost: 35, sortOrder: 62, variants: [{ colorId: colorBlack.id, unitCost: 35 }] },
    { code: "AKL-EUCA051", name: "ไกด์ซับพอร์ทข้าง-กรอบบาน", unit: "ชิ้น", baseCost: 5, sortOrder: 63, variants: [{ colorId: colorBlack.id, unitCost: 5 }] },
    { code: "AKL-EUCA053", name: "แกนสปินเดิล 7 x 65 มม.", unit: "ชิ้น", baseCost: 10, sortOrder: 64, variants: [{ colorId: colorWhite.id, unitCost: 10 }] },
    { code: "ACF-EUCA056", name: "บานพับ Hinge 120 Kg ซ้าย Cifial", unit: "ชิ้น", baseCost: 345, sortOrder: 65, variants: [{ colorId: colorWhite.id, unitCost: 345 }, { colorId: colorBlack.id, unitCost: 345 }, { colorId: colorSilver.id, unitCost: 345 }] },
    { code: "ACF-EUCA057", name: "บานพับ Hinge 120 Kg ขวา Cifial", unit: "ชิ้น", baseCost: 345, sortOrder: 66, variants: [{ colorId: colorWhite.id, unitCost: 345 }, { colorId: colorBlack.id, unitCost: 345 }, { colorId: colorSilver.id, unitCost: 345 }] },
    { code: "AKL-EUCA058", name: "ยางปิดร่อง C-Groove สีด า (50เมตร/ม้วน) (TPE)", unit: "ม้วน", baseCost: 550, sortOrder: 67, variants: [{ colorId: colorBlack.id, unitCost: 550 }] },
    { code: "AKL-EUCA059", name: "ยางกดบานเปิด, บานกระทุ้ง สีด า 50 เมตร/ม้วน (55320)", unit: "ม้วน", baseCost: 500, sortOrder: 68, variants: [{ colorId: colorBlack.id, unitCost: 500 }] },
    { code: "ACF-EUCA060", name: "หมุดล็อกปลาย 64 มม. ไม่มีสี (ZGB15M)", unit: "ชิ้น", baseCost: 35, sortOrder: 69, variants: [{ colorId: colorWhite.id, unitCost: 35 }] },
    { code: "ACF-EUCA061", name: "ตัวรับล็อกด้านเดียว ไม่มีสี (ZLP120)", unit: "ชิ้น", baseCost: 30, sortOrder: 70, variants: [{ colorId: colorWhite.id, unitCost: 30 }] },
    { code: "AKL-EUCA064", name: "Corner Device (ZA1)", unit: "ชิ้น", baseCost: 120, sortOrder: 71, variants: [{ colorId: colorWhite.id, unitCost: 120 }] },
    { code: "AGU-EUCA055", name: "ขาค ้าบานเปิดข้าง", unit: "ชิ้น", baseCost: 250, sortOrder: 72, variants: [{ colorId: colorWhite.id, unitCost: 250 }] },
    { code: "ACF-EUOP001", name: "มือจับ ประตูบานเปิด #92", unit: "ชิ้น", baseCost: 450, sortOrder: 73, variants: [{ colorId: colorWhite.id, unitCost: 450 }, { colorId: colorBlack.id, unitCost: 450 }, { colorId: colorSilver.id, unitCost: 450 }] },
    { code: "ACF-EUOP002", name: "มือจับ ประตูบานเปิด (ดัมมี่) #92", unit: "ชิ้น", baseCost: 495, sortOrder: 74, variants: [{ colorId: colorWhite.id, unitCost: 495 }, { colorId: colorBlack.id, unitCost: 495 }, { colorId: colorSilver.id, unitCost: 495 }] },
    { code: "ACF-EUOP003", name: "มือจับ ประตูบานเปิดหลบมุ้ง #92", unit: "ชิ้น", baseCost: 450, sortOrder: 75, variants: [{ colorId: colorWhite.id, unitCost: 450 }, { colorId: colorBlack.id, unitCost: 450 }, { colorId: colorSilver.id, unitCost: 450 }] },
    { code: "ACF-EUOP004", name: "มือจับ ประตูบานเปิดหลบมุ้ง (ดัมมี่) #92", unit: "ชิ้น", baseCost: 495, sortOrder: 76, variants: [{ colorId: colorWhite.id, unitCost: 495 }, { colorId: colorBlack.id, unitCost: 495 }, { colorId: colorSilver.id, unitCost: 495 }] },
    { code: "AKL-EUOP006", name: "แกนสปินเดิล 8 x 90 มม.", unit: "ชิ้น", baseCost: 20, sortOrder: 77, variants: [{ colorId: colorWhite.id, unitCost: 20 }] },
    { code: "ACF-EUOP007", name: "เสื้อกุญแจ #38-92 สองทาง", unit: "ชิ้น", baseCost: 725, sortOrder: 78, variants: [{ colorId: colorWhite.id, unitCost: 725 }] },
    { code: "AAL-MTSL001", name: "ฝาปิดเสากุญแจ", unit: "ชิ้น", baseCost: 10, sortOrder: 79, variants: [{ colorId: colorWhite.id, unitCost: 10 }, { colorId: colorBlack.id, unitCost: 10 }] },
    { code: "AAL-MTSL002", name: "ยางกันชน", unit: "ชิ้น", baseCost: 10, sortOrder: 80, variants: [{ colorId: colorWhite.id, unitCost: 10 }, { colorId: colorBlack.id, unitCost: 10 }] },
    { code: "AAL-MTSL004", name: "สต๊อบเปอร์ (ยางบานตาย)", unit: "ชิ้น", baseCost: 10, sortOrder: 81, variants: [{ colorId: colorWhite.id, unitCost: 10 }, { colorId: colorBlack.id, unitCost: 10 }] },
    { code: "AAL-MTSL005", name: "ยางกันลม (ยางกันบานยก)", unit: "ชิ้น", baseCost: 10, sortOrder: 82, variants: [{ colorId: colorBlack.id, unitCost: 10 }] },
    { code: "AAL-MTSL006", name: "ฝาปิดน ้าเข้า", unit: "ชิ้น", baseCost: 10, sortOrder: 83, variants: [{ colorId: colorWhite.id, unitCost: 10 }, { colorId: colorBlack.id, unitCost: 10 }] },
    { code: "AAL-MTSL007", name: "ฝาปิดน ้าออก", unit: "ชิ้น", baseCost: 10, sortOrder: 84, variants: [{ colorId: colorWhite.id, unitCost: 10 }, { colorId: colorBlack.id, unitCost: 10 }] },
    { code: "AAL-MTSL022", name: "ตัวรับกลอน 19 มิล", unit: "ชิ้น", baseCost: 30, sortOrder: 85, variants: [{ colorId: colorWhite.id, unitCost: 30 }, { colorId: colorBlack.id, unitCost: 30 }] },
    { code: "AAL-MTSL024", name: "ตะขอล็อก", unit: "ชิ้น", baseCost: 30, sortOrder: 86, variants: [{ colorId: colorWhite.id, unitCost: 30 }] },
    { code: "AKL-MTSL025", name: "มือจับฝังล็อก+กุญแจ", unit: "ชิ้น", baseCost: 210, sortOrder: 87, variants: [{ colorId: colorWhite.id, unitCost: 210 }, { colorId: colorBlack.id, unitCost: 210 }] },
    { code: "AKL-MTSL026", name: "มือจับฝังล็อก+ดัมมี่", unit: "ชิ้น", baseCost: 165, sortOrder: 88, variants: [{ colorId: colorWhite.id, unitCost: 165 }, { colorId: colorBlack.id, unitCost: 165 }] },
    { code: "AKL-MTSL027", name: "มือจับฝังดัมมี่", unit: "ชิ้น", baseCost: 70, sortOrder: 89, variants: [{ colorId: colorWhite.id, unitCost: 70 }, { colorId: colorBlack.id, unitCost: 70 }] },
    { code: "AKL-MTSL028", name: "มือจับฝังล็อก", unit: "ชิ้น", baseCost: 110, sortOrder: 90, variants: [{ colorId: colorWhite.id, unitCost: 110 }, { colorId: colorBlack.id, unitCost: 110 }] },
    { code: "AKL-MTSL029", name: "ตัว T มัลติพ้อยท์ล็อก (ยาว 23 มม.) ไม่มีสี", unit: "ชิ้น", baseCost: 45, sortOrder: 91, variants: [{ colorId: colorWhite.id, unitCost: 45 }] },
    { code: "AKL-MTSL030", name: "ล้อ 1624 (80 กก./คู่)", unit: "ชิ้น", baseCost: 135, sortOrder: 92, variants: [{ colorId: colorWhite.id, unitCost: 135 }] },
    { code: "AKL-MTSL031", name: "ล้อ 1522 (180 กก./คู่)", unit: "ชิ้น", baseCost: 220, sortOrder: 93, variants: [{ colorId: colorWhite.id, unitCost: 220 }] },
    { code: "AAL-MTSL032", name: "ฝาปิดหัวเสา SS-X207", unit: "ชิ้น", baseCost: 20, sortOrder: 94, variants: [{ colorId: colorWhite.id, unitCost: 20 }] },
    { code: "ASP-MTSL035", name: "ยางปิดสกรูเสาเกี่ยว (50 เมตร)", unit: "ม้วน", baseCost: 595, sortOrder: 95, variants: [{ colorId: colorBlack.id, unitCost: 595 }] },
    { code: "AKL-MTSL036", name: "สักหลาด 6X4 มม. (300 เมตร)", unit: "ม้วน", baseCost: 750, sortOrder: 96, variants: [{ colorId: colorBlack.id, unitCost: 750 }] },
    { code: "AKL-MTSL037", name: "สักหลาด 6X8 มม. (350 เมตร)", unit: "ม้วน", baseCost: 950, sortOrder: 97, variants: [{ colorId: colorBlack.id, unitCost: 950 }] },
    { code: "ADC-MTSL038", name: "มือจับฝังล็อก (HD)", unit: "ชิ้น", baseCost: 150, sortOrder: 98, variants: [{ colorId: colorWhite.id, unitCost: 150 }, { colorId: colorBlack.id, unitCost: 150 }, { colorId: colorSilver.id, unitCost: 150 }] },
    { code: "ADC-MTSL039", name: "มือจับฝังดัมมี่ (HD)", unit: "ชิ้น", baseCost: 90, sortOrder: 99, variants: [{ colorId: colorWhite.id, unitCost: 90 }, { colorId: colorBlack.id, unitCost: 90 }, { colorId: colorSilver.id, unitCost: 90 }] },
    { code: "AAL-MTSL040", name: "ล้อ 1622 (30 กก./คู่)", unit: "ชิ้น", baseCost: 45, sortOrder: 100, variants: [{ colorId: colorWhite.id, unitCost: 45 }] },
    { code: "ACF-MTSL041", name: "ตัว T มัลติพ้อยท์ล็อก (ยาว 23 มม.) สีด า", unit: "ชิ้น", baseCost: 50, sortOrder: 101, variants: [{ colorId: colorBlack.id, unitCost: 50 }] },
    { code: "AGU-MTSL042", name: "มือจับกุญแจ SN-G-U", unit: "ชิ้น", baseCost: 920, sortOrder: 102, variants: [{ colorId: colorWhite.id, unitCost: 920 }, { colorId: colorBlack.id, unitCost: 920 }] },
    { code: "AGU-MTSL043", name: "มือจับล็อก SN-G-U", unit: "ชิ้น", baseCost: 1080, sortOrder: 103, variants: [{ colorId: colorWhite.id, unitCost: 1080 }, { colorId: colorBlack.id, unitCost: 1080 }] },
    { code: "AGU-MTSL044", name: "มือจับดัมมี่ SN-G-U", unit: "ชิ้น", baseCost: 675, sortOrder: 104, variants: [{ colorId: colorWhite.id, unitCost: 675 }, { colorId: colorBlack.id, unitCost: 675 }] },
    { code: "AGU-MTSL046", name: "ตัว T มัลติพ้อยท์ล็อก G-U", unit: "ชิ้น", baseCost: 145, sortOrder: 105, variants: [{ colorId: colorWhite.id, unitCost: 145 }] },
    { code: "AHD-ICSL047", name: "สปิก็อตบานเลื่อนยูโร 10.5X24", unit: "ชิ้น", baseCost: 45, sortOrder: 106, variants: [{ colorId: colorWhite.id, unitCost: 45 }] },
    { code: "AHD-MTSL048", name: "ยางกันชนบานเลื่อน", unit: "ชิ้น", baseCost: 20, sortOrder: 107, variants: [{ colorId: colorBlack.id, unitCost: 20 }] },
    { code: "AHD-MTSL049", name: "ยางกันลม (HD1035A)", unit: "ชิ้น", baseCost: 15, sortOrder: 108, variants: [{ colorId: colorBlack.id, unitCost: 15 }] },
    { code: "AHD-ICSL050", name: "รับล็อกบานเลื่อน (HD-1127)", unit: "ชิ้น", baseCost: 30, sortOrder: 109, variants: [{ colorId: colorBlack.id, unitCost: 30 }] },
    { code: "AHD-ICSL051", name: "ฝาปิดเสากุญแจบานเลื่อน ไอคอนิค (HD-1034)", unit: "ชิ้น", baseCost: 10, sortOrder: 110, variants: [{ colorId: colorBlack.id, unitCost: 10 }] },
    { code: "ASP-ICSL052", name: "ยางกันชนเสาเกี่ยว (100 เมตร/ม้วน)", unit: "ชิ้น", baseCost: 595, sortOrder: 111, variants: [{ colorId: colorBlack.id, unitCost: 595 }] },
    { code: "AAL-ICSL053", name: "รางสแตนเลส SUS304 (6 เมตร/เส้น)", unit: "เส้น", baseCost: 260, sortOrder: 112, variants: [{ colorId: colorWhite.id, unitCost: 260 }] },
    { code: "ACF-ICSL054", name: "ตัว T มัลติพ้อยท์ล็อก (ยาว 30 มม.) สีด า", unit: "ชิ้น", baseCost: 60, sortOrder: 113, variants: [{ colorId: colorBlack.id, unitCost: 60 }] },
    { code: "ACF-MTSL055", name: "มือจับล็อก Cifial", unit: "ชิ้น", baseCost: 500, sortOrder: 114, variants: [{ colorId: colorWhite.id, unitCost: 500 }, { colorId: colorBlack.id, unitCost: 500 }] },
    { code: "ACF-MTSL056", name: "มือจับดัมมี่ Cifial", unit: "ชิ้น", baseCost: 390, sortOrder: 115, variants: [{ colorId: colorWhite.id, unitCost: 390 }, { colorId: colorBlack.id, unitCost: 390 }] },
    { code: "ACF-MTSL057", name: "มือจับล็อก+กุญแจ Cifial", unit: "ชิ้น", baseCost: 860, sortOrder: 116, variants: [{ colorId: colorWhite.id, unitCost: 860 }, { colorId: colorBlack.id, unitCost: 860 }] },
    { code: "ACF-MTSL058", name: "ล้อบานเลื่อน ( 300 Kg/2Pcs )", unit: "ชิ้น", baseCost: 970, sortOrder: 117, variants: [{ colorId: colorWhite.id, unitCost: 970 }] },
    { code: "AAL-SMSL018", name: "ฝาปิดเสาเกี่ยว", unit: "ชิ้น", baseCost: 10, sortOrder: 118, variants: [{ colorId: colorWhite.id, unitCost: 10 }, { colorId: colorBlack.id, unitCost: 10 }] },
  ];

  for (const acc of accItems) {
    const mat = await prisma.material.upsert({
      where: { code: acc.code },
      update: { name: acc.name, baseCost: acc.baseCost },
      create: {
        categoryId: catAcc.id,
        code: acc.code,
        name: acc.name,
        unit: acc.unit,
        baseCost: acc.baseCost,
        sortOrder: acc.sortOrder,
      },
    });
    for (const v of acc.variants) {
      await prisma.materialVariant.upsert({
        where: { materialId_colorId: { materialId: mat.id, colorId: v.colorId } },
        update: { unitCost: v.unitCost },
        create: { materialId: mat.id, colorId: v.colorId, unitCost: v.unitCost },
      });
    }
    console.log(`   ✓ [${acc.code}] ${acc.name}  ฿${acc.baseCost}/${acc.unit}`);
  }

  // ═══════════════════════════════════════════════════════════
  // SUMMARY
  // ═══════════════════════════════════════════════════════════
  // 19. CATEGORY: Alumet Standard Series
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding category: Alumet Standard Series...");

  const catStd = await prisma.category.upsert({
    where: { slug: "alumet-standard-series" },
    update: { name: "Alumet Standard Series" },
    create: {
      name: "Alumet Standard Series",
      slug: "alumet-standard-series",
      description: "โปรไฟล์อลูมิเนียมชุดมาตรฐานตลาด Mini Catalogue Ver.2020",
      sortOrder: 8,
    },
  });
  console.log(`   ✓ ${catStd.name}\n`);

  type StdItem = { code:string; name:string; baseCost:number; sortOrder:number;
    variants: { colorId:string; unitCost:number }[]; };

  const stdItems: StdItem[] = [
    { code: "STD-010009-1.0", name: "คิ้วลอยเทเหลี่ยม", baseCost: 219, sortOrder: 1, variants: [{ colorId: colorWhite.id, unitCost: 219 }, { colorId: colorBlack.id, unitCost: 219 }, { colorId: colorSilver.id, unitCost: 238 }] },
    { code: "STD-010010-1.0", name: "คิ้วตบเหลี่ยม", baseCost: 132, sortOrder: 2, variants: [{ colorId: colorWhite.id, unitCost: 132 }, { colorId: colorBlack.id, unitCost: 132 }, { colorId: colorSilver.id, unitCost: 143 }] },
    { code: "STD-010013-1.5", name: "เสาประตูบานพับ", baseCost: 901, sortOrder: 3, variants: [{ colorId: colorWhite.id, unitCost: 901 }, { colorId: colorBlack.id, unitCost: 901 }, { colorId: colorSilver.id, unitCost: 975 }] },
    { code: "STD-010040-1.2", name: "กลองรอง มีรูสกรู", baseCost: 729, sortOrder: 4, variants: [{ colorId: colorWhite.id, unitCost: 729 }, { colorId: colorBlack.id, unitCost: 729 }, { colorId: colorSilver.id, unitCost: 807 }] },
    { code: "STD-010041-1.2", name: "กลองเรียบ มีรูสกรู", baseCost: 652, sortOrder: 5, variants: [{ colorId: colorWhite.id, unitCost: 652 }, { colorId: colorBlack.id, unitCost: 652 }, { colorId: colorSilver.id, unitCost: 705 }] },
    { code: "STD-010042-1.2", name: "กลองเปด มีรูสกรู", baseCost: 736, sortOrder: 6, variants: [{ colorId: colorWhite.id, unitCost: 736 }, { colorId: colorBlack.id, unitCost: 736 }, { colorId: colorSilver.id, unitCost: 797 }] },
    { code: "STD-010043-1.2", name: "าเปดปด มีรูสกรู", baseCost: 233, sortOrder: 7, variants: [{ colorId: colorWhite.id, unitCost: 233 }, { colorId: colorBlack.id, unitCost: 233 }, { colorId: colorSilver.id, unitCost: 252 }] },
    { code: "STD-010076-1.5", name: "วงกบม มีรูกสรู", baseCost: 814, sortOrder: 8, variants: [{ colorId: colorWhite.id, unitCost: 814 }, { colorId: colorBlack.id, unitCost: 814 }, { colorId: colorSilver.id, unitCost: 882 }] },
    { code: "STD-010125-1.5", name: "กลองรอง", baseCost: 811, sortOrder: 9, variants: [{ colorId: colorWhite.id, unitCost: 811 }, { colorId: colorBlack.id, unitCost: 811 }, { colorId: colorSilver.id, unitCost: 878 }] },
    { code: "STD-010126-1.2", name: "าเปดปด", baseCost: 239, sortOrder: 10, variants: [{ colorId: colorWhite.id, unitCost: 239 }, { colorId: colorBlack.id, unitCost: 239 }, { colorId: colorSilver.id, unitCost: 259 }] },
    { code: "STD-010127-1.5", name: "กลองเรียบ", baseCost: 599, sortOrder: 11, variants: [{ colorId: colorWhite.id, unitCost: 599 }, { colorId: colorBlack.id, unitCost: 599 }, { colorId: colorSilver.id, unitCost: 649 }] },
    { code: "STD-010128-1.2", name: "กลองเปด", baseCost: 582, sortOrder: 12, variants: [{ colorId: colorWhite.id, unitCost: 582 }, { colorId: colorBlack.id, unitCost: 582 }, { colorId: colorSilver.id, unitCost: 630 }] },
    { code: "STD-010129-1.1", name: "คิ้วประตูเหลี่ยม", baseCost: 134, sortOrder: 13, variants: [{ colorId: colorWhite.id, unitCost: 134 }, { colorId: colorBlack.id, unitCost: 134 }, { colorId: colorSilver.id, unitCost: 146 }] },
    { code: "STD-020043-1.5", name: "เรมลาง ราง มมีปก ายน", baseCost: 571, sortOrder: 14, variants: [{ colorId: colorWhite.id, unitCost: 571 }, { colorId: colorBlack.id, unitCost: 571 }, { colorId: colorSilver.id, unitCost: 571 }] },
    { code: "STD-020052-1.3", name: "เรมลาง ราง มีปก ายนอก", baseCost: 556, sortOrder: 15, variants: [{ colorId: colorWhite.id, unitCost: 556 }, { colorId: colorBlack.id, unitCost: 556 }, { colorId: colorSilver.id, unitCost: 602 }] },
    { code: "STD-020070-1.2", name: "เรมบน ติดกลอง", baseCost: 761, sortOrder: 16, variants: [{ colorId: colorWhite.id, unitCost: 761 }, { colorId: colorBlack.id, unitCost: 761 }, { colorId: colorSilver.id, unitCost: 824 }] },
    { code: "STD-020071-1.2", name: "เรมขาง ติดกลอง", baseCost: 641, sortOrder: 17, variants: [{ colorId: colorWhite.id, unitCost: 641 }, { colorId: colorBlack.id, unitCost: 641 }, { colorId: colorSilver.id, unitCost: 695 }] },
    { code: "STD-020072-1.2", name: "เรมลาง ติดกลอง", baseCost: 646, sortOrder: 18, variants: [{ colorId: colorWhite.id, unitCost: 646 }, { colorId: colorBlack.id, unitCost: 646 }, { colorId: colorSilver.id, unitCost: 699 }] },
    { code: "STD-020099-1.8", name: "เรมลาง ราง บิกเรม มมีมุง", baseCost: 892, sortOrder: 19, variants: [{ colorId: colorWhite.id, unitCost: 892 }, { colorId: colorBlack.id, unitCost: 892 }, { colorId: colorSilver.id, unitCost: 967 }] },
    { code: "STD-020132-1.8", name: "เรมบนบิกเรม มีมุง", baseCost: 1192, sortOrder: 20, variants: [{ colorId: colorWhite.id, unitCost: 1192 }, { colorId: colorBlack.id, unitCost: 1192 }, { colorId: colorSilver.id, unitCost: 1290 }] },
    { code: "STD-020133-1.8", name: "เรมลางบิกเรม มีมุง", baseCost: 1129, sortOrder: 21, variants: [{ colorId: colorWhite.id, unitCost: 1129 }, { colorId: colorBlack.id, unitCost: 1129 }, { colorId: colorSilver.id, unitCost: 1222 }] },
    { code: "STD-020134-1.8", name: "รางขางขวา", baseCost: 1200, sortOrder: 22, variants: [{ colorId: colorWhite.id, unitCost: 1200 }, { colorId: colorBlack.id, unitCost: 1200 }, { colorId: colorSilver.id, unitCost: 1299 }] },
    { code: "STD-020135-1.8", name: "รางขางาย", baseCost: 1199, sortOrder: 23, variants: [{ colorId: colorWhite.id, unitCost: 1199 }, { colorId: colorBlack.id, unitCost: 1199 }, { colorId: colorSilver.id, unitCost: 1299 }] },
    { code: "STD-020143-1.5", name: "เสาประตูบานเปด มีบังบ", baseCost: 902, sortOrder: 24, variants: [{ colorId: colorWhite.id, unitCost: 902 }, { colorId: colorBlack.id, unitCost: 902 }, { colorId: colorSilver.id, unitCost: 977 }] },
    { code: "STD-020234-1.2", name: "เสากุแจตัวเมีย มม.", baseCost: 526, sortOrder: 25, variants: [{ colorId: colorWhite.id, unitCost: 526 }, { colorId: colorBlack.id, unitCost: 526 }, { colorId: colorSilver.id, unitCost: 570 }] },
    { code: "STD-020291-2.0", name: "เสาประตูบน", baseCost: 1162, sortOrder: 26, variants: [{ colorId: colorWhite.id, unitCost: 1162 }, { colorId: colorBlack.id, unitCost: 1162 }, { colorId: colorSilver.id, unitCost: 1259 }] },
    { code: "STD-020292-2.0", name: "เสาประตู", baseCost: 1195, sortOrder: 27, variants: [{ colorId: colorWhite.id, unitCost: 1195 }, { colorId: colorBlack.id, unitCost: 1195 }, { colorId: colorSilver.id, unitCost: 1295 }] },
    { code: "STD-020562-1.8", name: "เสริมเรมขาง บิกเรม", baseCost: 597, sortOrder: 28, variants: [{ colorId: colorWhite.id, unitCost: 597 }, { colorId: colorBlack.id, unitCost: 597 }, { colorId: colorSilver.id, unitCost: 646 }] },
    { code: "STD-020563-1.8", name: "เสริมเรมบน บิกเรม", baseCost: 485, sortOrder: 29, variants: [{ colorId: colorWhite.id, unitCost: 485 }, { colorId: colorBlack.id, unitCost: 485 }, { colorId: colorSilver.id, unitCost: 525 }] },
    { code: "STD-020564-1.8", name: "เรมลาง ราง บิกเรม", baseCost: 1217, sortOrder: 30, variants: [{ colorId: colorWhite.id, unitCost: 1217 }, { colorId: colorBlack.id, unitCost: 1217 }, { colorId: colorSilver.id, unitCost: 1318 }] },
    { code: "STD-030064-1.2", name: "าตบกลองกาน กระทุง", baseCost: 460, sortOrder: 31, variants: [{ colorId: colorWhite.id, unitCost: 460 }, { colorId: colorBlack.id, unitCost: 460 }, { colorId: colorSilver.id, unitCost: 498 }] },
    { code: "STD-030065-1.3", name: "กลองกาน กระทุง", baseCost: 704, sortOrder: 32, variants: [{ colorId: colorWhite.id, unitCost: 704 }, { colorId: colorBlack.id, unitCost: 704 }, { colorId: colorSilver.id, unitCost: 762 }] },
    { code: "STD-10258-1.2", name: "าเปดปด", baseCost: 257, sortOrder: 33, variants: [{ colorId: colorWhite.id, unitCost: 257 }, { colorId: colorBlack.id, unitCost: 257 }, { colorId: colorSilver.id, unitCost: 278 }] },
    { code: "STD-10259-1.2", name: "กลองเปด", baseCost: 670, sortOrder: 34, variants: [{ colorId: colorWhite.id, unitCost: 670 }, { colorId: colorBlack.id, unitCost: 670 }, { colorId: colorSilver.id, unitCost: 726 }] },
    { code: "STD-10260-1.2", name: "กลองรอง", baseCost: 640, sortOrder: 35, variants: [{ colorId: colorWhite.id, unitCost: 640 }, { colorId: colorBlack.id, unitCost: 640 }, { colorId: colorSilver.id, unitCost: 703 }] },
    { code: "STD-10261-1.2", name: "ตบรอง", baseCost: 385, sortOrder: 36, variants: [{ colorId: colorWhite.id, unitCost: 385 }, { colorId: colorBlack.id, unitCost: 385 }, { colorId: colorSilver.id, unitCost: 417 }] },
    { code: "STD-10262-1.2", name: "กลองเรียบ", baseCost: 533, sortOrder: 37, variants: [{ colorId: colorWhite.id, unitCost: 533 }, { colorId: colorBlack.id, unitCost: 533 }, { colorId: colorSilver.id, unitCost: 577 }] },
    { code: "STD-105-1.5", name: "กลองเรียบ มม.", baseCost: 744, sortOrder: 38, variants: [{ colorId: colorWhite.id, unitCost: 744 }, { colorId: colorBlack.id, unitCost: 744 }, { colorId: colorSilver.id, unitCost: 806 }] },
    { code: "STD-134-1.2", name: "กลองกาน กระทุง", baseCost: 756, sortOrder: 39, variants: [{ colorId: colorWhite.id, unitCost: 756 }, { colorId: colorBlack.id, unitCost: 756 }, { colorId: colorSilver.id, unitCost: 819 }] },
    { code: "STD-135-1.3", name: "เสามุม", baseCost: 836, sortOrder: 40, variants: [{ colorId: colorWhite.id, unitCost: 836 }, { colorId: colorBlack.id, unitCost: 836 }, { colorId: colorSilver.id, unitCost: 906 }] },
    { code: "STD-14003-1.5", name: "เสากุแจตัวเมีย มม.", baseCost: 639, sortOrder: 41, variants: [{ colorId: colorWhite.id, unitCost: 639 }, { colorId: colorBlack.id, unitCost: 639 }, { colorId: colorSilver.id, unitCost: 692 }] },
    { code: "STD-14004-1.5", name: "เสากุแจตัวผู", baseCost: 714, sortOrder: 42, variants: [{ colorId: colorWhite.id, unitCost: 714 }, { colorId: colorBlack.id, unitCost: 714 }, { colorId: colorSilver.id, unitCost: 775 }] },
    { code: "STD-14005-1.3", name: "เสาเกี่ยว", baseCost: 652, sortOrder: 43, variants: [{ colorId: colorWhite.id, unitCost: 652 }, { colorId: colorBlack.id, unitCost: 652 }, { colorId: colorSilver.id, unitCost: 705 }] },
    { code: "STD-14005-1.5", name: "เสาเกี่ยว", baseCost: 652, sortOrder: 44, variants: [{ colorId: colorWhite.id, unitCost: 652 }, { colorId: colorBlack.id, unitCost: 652 }, { colorId: colorSilver.id, unitCost: 705 }] },
    { code: "STD-14007-1.5", name: "เสาเกี่ยว ทาง", baseCost: 627, sortOrder: 45, variants: [{ colorId: colorWhite.id, unitCost: 627 }, { colorId: colorBlack.id, unitCost: 627 }, { colorId: colorSilver.id, unitCost: 679 }] },
    { code: "STD-14008-1.5", name: "เรมลาง ราง มีตบรณี", baseCost: 556, sortOrder: 46, variants: [{ colorId: colorWhite.id, unitCost: 556 }, { colorId: colorBlack.id, unitCost: 556 }, { colorId: colorSilver.id, unitCost: 601 }] },
    { code: "STD-14009-1.3", name: "เรมขาง ราง", baseCost: 650, sortOrder: 47, variants: [{ colorId: colorWhite.id, unitCost: 650 }, { colorId: colorBlack.id, unitCost: 650 }, { colorId: colorSilver.id, unitCost: 703 }] },
    { code: "STD-14009-1.5", name: "เรมขาง ราง", baseCost: 650, sortOrder: 48, variants: [{ colorId: colorWhite.id, unitCost: 650 }, { colorId: colorBlack.id, unitCost: 650 }, { colorId: colorSilver.id, unitCost: 703 }] },
    { code: "STD-14010-1.2", name: "เรมบน ราง", baseCost: 713, sortOrder: 49, variants: [{ colorId: colorWhite.id, unitCost: 713 }, { colorId: colorBlack.id, unitCost: 713 }, { colorId: colorSilver.id, unitCost: 772 }] },
    { code: "STD-14010-1.3", name: "เรมบน ราง", baseCost: 713, sortOrder: 50, variants: [{ colorId: colorWhite.id, unitCost: 713 }, { colorId: colorBlack.id, unitCost: 713 }, { colorId: colorSilver.id, unitCost: 772 }] },
    { code: "STD-14091-1.6", name: "เสาเกี่ยวมือจับ", baseCost: 904, sortOrder: 51, variants: [{ colorId: colorWhite.id, unitCost: 904 }, { colorId: colorBlack.id, unitCost: 904 }] },
    { code: "STD-2001-1.0", name: "เสนหนาตาง มีปก", baseCost: 102, sortOrder: 52, variants: [{ colorId: colorWhite.id, unitCost: 102 }, { colorId: colorBlack.id, unitCost: 102 }, { colorId: colorSilver.id, unitCost: 115 }] },
    { code: "STD-2003-1.0", name: "เสนประตูมีปก", baseCost: 191, sortOrder: 53, variants: [{ colorId: colorWhite.id, unitCost: 191 }, { colorId: colorBlack.id, unitCost: 191 }, { colorId: colorSilver.id, unitCost: 207 }] },
    { code: "STD-2005-1.0", name: "เสนคาดกลางมุง", baseCost: 77, sortOrder: 54, variants: [{ colorId: colorWhite.id, unitCost: 77 }, { colorId: colorBlack.id, unitCost: 77 }, { colorId: colorSilver.id, unitCost: 84 }] },
    { code: "STD-2006-1.0", name: "กรอบมุง", baseCost: 234, sortOrder: 55, variants: [{ colorId: colorWhite.id, unitCost: 234 }, { colorId: colorBlack.id, unitCost: 234 }, { colorId: colorSilver.id, unitCost: 256 }] },
    { code: "STD-2044-1.0", name: "เสริมมุงบานเลื่อน", baseCost: 77, sortOrder: 56, variants: [{ colorId: colorWhite.id, unitCost: 77 }, { colorId: colorBlack.id, unitCost: 77 }, { colorId: colorSilver.id, unitCost: 84 }] },
    { code: "STD-259-2.0", name: "ากกันตก", baseCost: 101, sortOrder: 57, variants: [{ colorId: colorWhite.id, unitCost: 101 }, { colorId: colorBlack.id, unitCost: 101 }, { colorId: colorSilver.id, unitCost: 109 }] },
    { code: "STD-261-1.0", name: "กรอบนอก ขาเทา", baseCost: 318, sortOrder: 58, variants: [{ colorId: colorWhite.id, unitCost: 318 }, { colorId: colorBlack.id, unitCost: 318 }, { colorId: colorSilver.id, unitCost: 358 }] },
    { code: "STD-261-1.2", name: "กรอบนอก ขาเทา", baseCost: 318, sortOrder: 59, variants: [{ colorId: colorWhite.id, unitCost: 318 }, { colorId: colorBlack.id, unitCost: 318 }, { colorId: colorSilver.id, unitCost: 358 }] },
    { code: "STD-261-1.8", name: "กรอบนอก ขาเทา", baseCost: 318, sortOrder: 60, variants: [{ colorId: colorWhite.id, unitCost: 318 }, { colorId: colorBlack.id, unitCost: 318 }, { colorId: colorSilver.id, unitCost: 358 }] },
    { code: "STD-262-1.0", name: "คิ้วบานกระทุง", baseCost: 123, sortOrder: 61, variants: [{ colorId: colorWhite.id, unitCost: 123 }, { colorId: colorBlack.id, unitCost: 123 }, { colorId: colorSilver.id, unitCost: 135 }] },
    { code: "STD-3001-1.0", name: "กลองรอง", baseCost: 522, sortOrder: 62, variants: [{ colorId: colorWhite.id, unitCost: 522 }, { colorId: colorBlack.id, unitCost: 522 }, { colorId: colorSilver.id, unitCost: 567 }] },
    { code: "STD-3001-1.2", name: "กลองรอง", baseCost: 522, sortOrder: 63, variants: [{ colorId: colorWhite.id, unitCost: 522 }, { colorId: colorBlack.id, unitCost: 522 }, { colorId: colorSilver.id, unitCost: 567 }] },
    { code: "STD-3002-1.0", name: "กลองเรียบ", baseCost: 432, sortOrder: 64, variants: [{ colorId: colorWhite.id, unitCost: 432 }, { colorId: colorBlack.id, unitCost: 432 }, { colorId: colorSilver.id, unitCost: 456 }] },
    { code: "STD-3002-1.2", name: "กลองเรียบ", baseCost: 432, sortOrder: 65, variants: [{ colorId: colorWhite.id, unitCost: 432 }, { colorId: colorBlack.id, unitCost: 432 }, { colorId: colorSilver.id, unitCost: 456 }] },
    { code: "STD-3003-1.0", name: "ตบรอง", baseCost: 264, sortOrder: 66, variants: [{ colorId: colorWhite.id, unitCost: 264 }, { colorId: colorBlack.id, unitCost: 264 }, { colorId: colorSilver.id, unitCost: 284 }] },
    { code: "STD-3003-1.2", name: "ตบรอง", baseCost: 264, sortOrder: 67, variants: [{ colorId: colorWhite.id, unitCost: 264 }, { colorId: colorBlack.id, unitCost: 264 }, { colorId: colorSilver.id, unitCost: 284 }] },
    { code: "STD-3004-1.1", name: "ตบเรียบ", baseCost: 160, sortOrder: 68, variants: [{ colorId: colorWhite.id, unitCost: 160 }, { colorId: colorBlack.id, unitCost: 160 }, { colorId: colorSilver.id, unitCost: 173 }] },
    { code: "STD-3005-1.2", name: "กลองเปดปด", baseCost: 490, sortOrder: 69, variants: [{ colorId: colorWhite.id, unitCost: 490 }, { colorId: colorBlack.id, unitCost: 490 }, { colorId: colorSilver.id, unitCost: 531 }] },
    { code: "STD-3006-1.2", name: "าเปดปด", baseCost: 183, sortOrder: 70, variants: [{ colorId: colorWhite.id, unitCost: 183 }, { colorId: colorBlack.id, unitCost: 183 }, { colorId: colorSilver.id, unitCost: 198 }] },
    { code: "STD-3012-1.0", name: "กลองรอง", baseCost: 903, sortOrder: 71, variants: [{ colorId: colorWhite.id, unitCost: 903 }, { colorId: colorBlack.id, unitCost: 903 }, { colorId: colorSilver.id, unitCost: 1006 }] },
    { code: "STD-3012-1.2", name: "กลองรอง", baseCost: 903, sortOrder: 72, variants: [{ colorId: colorWhite.id, unitCost: 903 }, { colorId: colorBlack.id, unitCost: 903 }, { colorId: colorSilver.id, unitCost: 1006 }] },
    { code: "STD-3012-1.5", name: "กลองรอง", baseCost: 903, sortOrder: 73, variants: [{ colorId: colorWhite.id, unitCost: 903 }, { colorId: colorBlack.id, unitCost: 903 }, { colorId: colorSilver.id, unitCost: 1006 }] },
    { code: "STD-3012-1.8", name: "กลองรอง", baseCost: 903, sortOrder: 74, variants: [{ colorId: colorWhite.id, unitCost: 903 }, { colorId: colorBlack.id, unitCost: 903 }, { colorId: colorSilver.id, unitCost: 1006 }] },
    { code: "STD-3012-2.0", name: "กลองรอง", baseCost: 903, sortOrder: 75, variants: [{ colorId: colorWhite.id, unitCost: 903 }, { colorId: colorBlack.id, unitCost: 903 }, { colorId: colorSilver.id, unitCost: 1006 }] },
    { code: "STD-3013-1.0", name: "กลองเรียบ", baseCost: 720, sortOrder: 76, variants: [{ colorId: colorWhite.id, unitCost: 720 }, { colorId: colorBlack.id, unitCost: 720 }, { colorId: colorSilver.id, unitCost: 803 }] },
    { code: "STD-3013-1.2", name: "กลองเรียบ", baseCost: 720, sortOrder: 77, variants: [{ colorId: colorWhite.id, unitCost: 720 }, { colorId: colorBlack.id, unitCost: 720 }, { colorId: colorSilver.id, unitCost: 803 }] },
    { code: "STD-3013-1.5", name: "กลองเรียบ", baseCost: 720, sortOrder: 78, variants: [{ colorId: colorWhite.id, unitCost: 720 }, { colorId: colorBlack.id, unitCost: 720 }, { colorId: colorSilver.id, unitCost: 803 }] },
    { code: "STD-3013-1.8", name: "กลองเรียบ", baseCost: 720, sortOrder: 79, variants: [{ colorId: colorWhite.id, unitCost: 720 }, { colorId: colorBlack.id, unitCost: 720 }, { colorId: colorSilver.id, unitCost: 803 }] },
    { code: "STD-3013-2.0", name: "กลองเรียบ", baseCost: 720, sortOrder: 80, variants: [{ colorId: colorWhite.id, unitCost: 720 }, { colorId: colorBlack.id, unitCost: 720 }, { colorId: colorSilver.id, unitCost: 803 }] },
    { code: "STD-3014-1.0", name: "ตบรอง", baseCost: 390, sortOrder: 81, variants: [{ colorId: colorWhite.id, unitCost: 390 }, { colorId: colorBlack.id, unitCost: 390 }, { colorId: colorSilver.id, unitCost: 432 }] },
    { code: "STD-3014-1.2", name: "ตบรอง", baseCost: 390, sortOrder: 82, variants: [{ colorId: colorWhite.id, unitCost: 390 }, { colorId: colorBlack.id, unitCost: 390 }, { colorId: colorSilver.id, unitCost: 432 }] },
    { code: "STD-3014-1.5", name: "ตบรอง", baseCost: 390, sortOrder: 83, variants: [{ colorId: colorWhite.id, unitCost: 390 }, { colorId: colorBlack.id, unitCost: 390 }, { colorId: colorSilver.id, unitCost: 432 }] },
    { code: "STD-3015-1.0", name: "ตบเรียบ", baseCost: 345, sortOrder: 84, variants: [{ colorId: colorWhite.id, unitCost: 345 }, { colorId: colorBlack.id, unitCost: 345 }, { colorId: colorSilver.id, unitCost: 297 }] },
    { code: "STD-3015-1.2", name: "ตบเรียบ", baseCost: 345, sortOrder: 85, variants: [{ colorId: colorWhite.id, unitCost: 345 }, { colorId: colorBlack.id, unitCost: 345 }, { colorId: colorSilver.id, unitCost: 297 }] },
    { code: "STD-3015-1.5", name: "ตบเรียบ", baseCost: 345, sortOrder: 86, variants: [{ colorId: colorWhite.id, unitCost: 345 }, { colorId: colorBlack.id, unitCost: 345 }, { colorId: colorSilver.id, unitCost: 297 }] },
    { code: "STD-3016-1.0", name: "กลองเปดปด", baseCost: 732, sortOrder: 87, variants: [{ colorId: colorWhite.id, unitCost: 732 }, { colorId: colorBlack.id, unitCost: 732 }, { colorId: colorSilver.id, unitCost: 817 }] },
    { code: "STD-3016-1.2", name: "กลองเปดปด", baseCost: 732, sortOrder: 88, variants: [{ colorId: colorWhite.id, unitCost: 732 }, { colorId: colorBlack.id, unitCost: 732 }, { colorId: colorSilver.id, unitCost: 817 }] },
    { code: "STD-3016-1.5", name: "กลองเปดปด", baseCost: 732, sortOrder: 89, variants: [{ colorId: colorWhite.id, unitCost: 732 }, { colorId: colorBlack.id, unitCost: 732 }, { colorId: colorSilver.id, unitCost: 817 }] },
    { code: "STD-3016-1.8", name: "กลองเปดปด", baseCost: 732, sortOrder: 90, variants: [{ colorId: colorWhite.id, unitCost: 732 }, { colorId: colorBlack.id, unitCost: 732 }, { colorId: colorSilver.id, unitCost: 817 }] },
    { code: "STD-3016-2.0", name: "กลองเปดปด", baseCost: 732, sortOrder: 91, variants: [{ colorId: colorWhite.id, unitCost: 732 }, { colorId: colorBlack.id, unitCost: 732 }, { colorId: colorSilver.id, unitCost: 817 }] },
    { code: "STD-3017-1.0", name: "าเปดปด", baseCost: 273, sortOrder: 92, variants: [{ colorId: colorWhite.id, unitCost: 273 }, { colorId: colorBlack.id, unitCost: 273 }, { colorId: colorSilver.id, unitCost: 2092 }] },
    { code: "STD-3017-1.2", name: "าเปดปด", baseCost: 273, sortOrder: 93, variants: [{ colorId: colorWhite.id, unitCost: 273 }, { colorId: colorBlack.id, unitCost: 273 }, { colorId: colorSilver.id, unitCost: 2092 }] },
    { code: "STD-3017-1.5", name: "าเปดปด", baseCost: 273, sortOrder: 94, variants: [{ colorId: colorWhite.id, unitCost: 273 }, { colorId: colorBlack.id, unitCost: 273 }, { colorId: colorSilver.id, unitCost: 2092 }] },
    { code: "STD-3018-1.0", name: "คิ้วลอยเทเล็ก", baseCost: 90, sortOrder: 95, variants: [{ colorId: colorWhite.id, unitCost: 90 }, { colorId: colorBlack.id, unitCost: 90 }, { colorId: colorSilver.id, unitCost: 101 }] },
    { code: "STD-3019-1.0", name: "คิ้วลอยเทห", baseCost: 147, sortOrder: 96, variants: [{ colorId: colorWhite.id, unitCost: 147 }, { colorId: colorBlack.id, unitCost: 147 }, { colorId: colorSilver.id, unitCost: 155 }] },
    { code: "STD-3020-1.0", name: "คิ้วประตู", baseCost: 84, sortOrder: 97, variants: [{ colorId: colorWhite.id, unitCost: 84 }, { colorId: colorBlack.id, unitCost: 84 }, { colorId: colorSilver.id, unitCost: 94 }] },
    { code: "STD-3026-1.2", name: "กลองแจกสัน", baseCost: 708, sortOrder: 98, variants: [{ colorId: colorWhite.id, unitCost: 708 }, { colorId: colorBlack.id, unitCost: 708 }, { colorId: colorSilver.id, unitCost: 783 }] },
    { code: "STD-3026-1.5", name: "กลองแจกสัน", baseCost: 708, sortOrder: 99, variants: [{ colorId: colorWhite.id, unitCost: 708 }, { colorId: colorBlack.id, unitCost: 708 }, { colorId: colorSilver.id, unitCost: 783 }] },
    { code: "STD-3026-1.8", name: "กลองแจกสัน", baseCost: 708, sortOrder: 100, variants: [{ colorId: colorWhite.id, unitCost: 708 }, { colorId: colorBlack.id, unitCost: 708 }, { colorId: colorSilver.id, unitCost: 783 }] },
    { code: "STD-3027-1.0", name: "าแจกสัน", baseCost: 357, sortOrder: 101, variants: [{ colorId: colorWhite.id, unitCost: 357 }, { colorId: colorBlack.id, unitCost: 357 }, { colorId: colorSilver.id, unitCost: 395 }] },
    { code: "STD-3027-1.5", name: "าแจกสัน", baseCost: 357, sortOrder: 102, variants: [{ colorId: colorWhite.id, unitCost: 357 }, { colorId: colorBlack.id, unitCost: 357 }, { colorId: colorSilver.id, unitCost: 395 }] },
    { code: "STD-3027-2.0", name: "าแจกสัน", baseCost: 357, sortOrder: 103, variants: [{ colorId: colorWhite.id, unitCost: 357 }, { colorId: colorBlack.id, unitCost: 357 }, { colorId: colorSilver.id, unitCost: 395 }] },
    { code: "STD-3030-1.0", name: "เสาประตู", baseCost: 726, sortOrder: 104, variants: [{ colorId: colorWhite.id, unitCost: 726 }, { colorId: colorBlack.id, unitCost: 726 }, { colorId: colorSilver.id, unitCost: 803 }] },
    { code: "STD-3030-1.2", name: "เสาประตู", baseCost: 726, sortOrder: 105, variants: [{ colorId: colorWhite.id, unitCost: 726 }, { colorId: colorBlack.id, unitCost: 726 }, { colorId: colorSilver.id, unitCost: 803 }] },
    { code: "STD-3030-1.5", name: "เสาประตู", baseCost: 726, sortOrder: 106, variants: [{ colorId: colorWhite.id, unitCost: 726 }, { colorId: colorBlack.id, unitCost: 726 }, { colorId: colorSilver.id, unitCost: 803 }] },
    { code: "STD-3030-2.0", name: "เสาประตู", baseCost: 726, sortOrder: 107, variants: [{ colorId: colorWhite.id, unitCost: 726 }, { colorId: colorBlack.id, unitCost: 726 }, { colorId: colorSilver.id, unitCost: 803 }] },
    { code: "STD-3031-1.2", name: "เสาประตูบน", baseCost: 678, sortOrder: 108, variants: [{ colorId: colorWhite.id, unitCost: 678 }, { colorId: colorBlack.id, unitCost: 678 }, { colorId: colorSilver.id, unitCost: 756 }] },
    { code: "STD-3031-1.5", name: "เสาประตูบน", baseCost: 678, sortOrder: 109, variants: [{ colorId: colorWhite.id, unitCost: 678 }, { colorId: colorBlack.id, unitCost: 678 }, { colorId: colorSilver.id, unitCost: 756 }] },
    { code: "STD-3031-1.8", name: "เสาประตูบน", baseCost: 678, sortOrder: 110, variants: [{ colorId: colorWhite.id, unitCost: 678 }, { colorId: colorBlack.id, unitCost: 678 }, { colorId: colorSilver.id, unitCost: 756 }] },
    { code: "STD-3031-2.0", name: "เสาประตูบน", baseCost: 678, sortOrder: 111, variants: [{ colorId: colorWhite.id, unitCost: 678 }, { colorId: colorBlack.id, unitCost: 678 }, { colorId: colorSilver.id, unitCost: 756 }] },
    { code: "STD-3032-1.2", name: "เสาประตูลาง", baseCost: 840, sortOrder: 112, variants: [{ colorId: colorWhite.id, unitCost: 840 }, { colorId: colorBlack.id, unitCost: 840 }, { colorId: colorSilver.id, unitCost: 932 }] },
    { code: "STD-3032-1.5", name: "เสาประตูลาง", baseCost: 840, sortOrder: 113, variants: [{ colorId: colorWhite.id, unitCost: 840 }, { colorId: colorBlack.id, unitCost: 840 }, { colorId: colorSilver.id, unitCost: 932 }] },
    { code: "STD-3032-1.8", name: "เสาประตูลาง", baseCost: 840, sortOrder: 114, variants: [{ colorId: colorWhite.id, unitCost: 840 }, { colorId: colorBlack.id, unitCost: 840 }, { colorId: colorSilver.id, unitCost: 932 }] },
    { code: "STD-3047-1.3", name: "อยลูกก", baseCost: 391, sortOrder: 115, variants: [{ colorId: colorWhite.id, unitCost: 391 }, { colorId: colorBlack.id, unitCost: 391 }, { colorId: colorSilver.id, unitCost: 424 }] },
    { code: "STD-3058-1.0", name: "คิ้วเทเล็ก", baseCost: 108, sortOrder: 116, variants: [{ colorId: colorWhite.id, unitCost: 108 }, { colorId: colorBlack.id, unitCost: 108 }, { colorId: colorSilver.id, unitCost: 117 }] },
    { code: "STD-3060-1.5", name: "รางแขวนห", baseCost: 454, sortOrder: 117, variants: [{ colorId: colorWhite.id, unitCost: 454 }, { colorId: colorBlack.id, unitCost: 454 }, { colorId: colorSilver.id, unitCost: 492 }] },
    { code: "STD-3061-1.8", name: "รางแขวนเล็ก", baseCost: 337, sortOrder: 118, variants: [{ colorId: colorWhite.id, unitCost: 337 }, { colorId: colorBlack.id, unitCost: 337 }, { colorId: colorSilver.id, unitCost: 364 }] },
    { code: "STD-3062-2.2", name: "มือจับยาว", baseCost: 646, sortOrder: 119, variants: [{ colorId: colorWhite.id, unitCost: 646 }, { colorId: colorBlack.id, unitCost: 646 }, { colorId: colorSilver.id, unitCost: 700 }] },
    { code: "STD-3063-1.0", name: "คิ้วเทห", baseCost: 90, sortOrder: 120, variants: [{ colorId: colorWhite.id, unitCost: 90 }, { colorId: colorBlack.id, unitCost: 90 }, { colorId: colorSilver.id, unitCost: 97 }] },
    { code: "STD-3064-1.5", name: "เสามุม ทาง", baseCost: 1874, sortOrder: 121, variants: [{ colorId: colorWhite.id, unitCost: 1874 }, { colorId: colorBlack.id, unitCost: 1874 }, { colorId: colorSilver.id, unitCost: 2032 }] },
    { code: "STD-3067-1.3", name: "รณีสวิง", baseCost: 686, sortOrder: 122, variants: [{ colorId: colorWhite.id, unitCost: 686 }, { colorId: colorBlack.id, unitCost: 686 }, { colorId: colorSilver.id, unitCost: 743 }] },
    { code: "STD-3067-1.5", name: "รณีสวิง", baseCost: 686, sortOrder: 123, variants: [{ colorId: colorWhite.id, unitCost: 686 }, { colorId: colorBlack.id, unitCost: 686 }, { colorId: colorSilver.id, unitCost: 743 }] },
    { code: "STD-3092-1.4", name: "เสาประตูบานเปด", baseCost: 708, sortOrder: 124, variants: [{ colorId: colorWhite.id, unitCost: 708 }, { colorId: colorBlack.id, unitCost: 708 }, { colorId: colorSilver.id, unitCost: 768 }] },
    { code: "STD-3092-1.5", name: "เสาประตูบานเปด", baseCost: 708, sortOrder: 125, variants: [{ colorId: colorWhite.id, unitCost: 708 }, { colorId: colorBlack.id, unitCost: 708 }, { colorId: colorSilver.id, unitCost: 768 }] },
    { code: "STD-3093-1.4", name: "เสาประตูบนลาง บานเปด", baseCost: 1025, sortOrder: 126, variants: [{ colorId: colorWhite.id, unitCost: 1025 }, { colorId: colorBlack.id, unitCost: 1025 }, { colorId: colorSilver.id, unitCost: 1112 }] },
    { code: "STD-3093-3.6", name: "เสาประตูบนลาง บานเปด", baseCost: 1025, sortOrder: 127, variants: [{ colorId: colorWhite.id, unitCost: 1025 }, { colorId: colorBlack.id, unitCost: 1025 }, { colorId: colorSilver.id, unitCost: 1112 }] },
    { code: "STD-3094-1.4", name: "เสาประตูบนลาง บานเปด", baseCost: 816, sortOrder: 128, variants: [{ colorId: colorWhite.id, unitCost: 816 }, { colorId: colorBlack.id, unitCost: 816 }, { colorId: colorSilver.id, unitCost: 884 }] },
    { code: "STD-3094-2.5", name: "เสาประตูบนลาง บานเปด", baseCost: 816, sortOrder: 129, variants: [{ colorId: colorWhite.id, unitCost: 816 }, { colorId: colorBlack.id, unitCost: 816 }, { colorId: colorSilver.id, unitCost: 884 }] },
    { code: "STD-3095-1.0", name: "คิ้วประตูบานเปด", baseCost: 82, sortOrder: 130, variants: [{ colorId: colorWhite.id, unitCost: 82 }, { colorId: colorBlack.id, unitCost: 82 }, { colorId: colorSilver.id, unitCost: 89 }] },
    { code: "STD-3096-1.4", name: "เสาประตูบานเปด มีบังบ", baseCost: 768, sortOrder: 131, variants: [{ colorId: colorWhite.id, unitCost: 768 }, { colorId: colorBlack.id, unitCost: 768 }, { colorId: colorSilver.id, unitCost: 834 }] },
    { code: "STD-3096-1.5", name: "เสาประตูบานเปด มีบังบ", baseCost: 768, sortOrder: 132, variants: [{ colorId: colorWhite.id, unitCost: 768 }, { colorId: colorBlack.id, unitCost: 768 }, { colorId: colorSilver.id, unitCost: 834 }] },
    { code: "STD-3097-1.0", name: "วงกบม มม. มมีติ่ง", baseCost: 796, sortOrder: 133, variants: [{ colorId: colorWhite.id, unitCost: 796 }, { colorId: colorBlack.id, unitCost: 796 }, { colorId: colorSilver.id, unitCost: 863 }] },
    { code: "STD-3174-1.5", name: "วงกบมมีติ่ง มม.", baseCost: 764, sortOrder: 134, variants: [{ colorId: colorWhite.id, unitCost: 764 }, { colorId: colorBlack.id, unitCost: 764 }, { colorId: colorSilver.id, unitCost: 827 }] },
    { code: "STD-3174-2.0", name: "วงกบมมีติ่ง มม.", baseCost: 764, sortOrder: 135, variants: [{ colorId: colorWhite.id, unitCost: 764 }, { colorId: colorBlack.id, unitCost: 764 }, { colorId: colorSilver.id, unitCost: 827 }] },
    { code: "STD-3185-1.2", name: "คิ้วชองแสงบานเปด", baseCost: 207, sortOrder: 136, variants: [{ colorId: colorWhite.id, unitCost: 207 }, { colorId: colorBlack.id, unitCost: 207 }, { colorId: colorSilver.id, unitCost: 224 }] },
    { code: "STD-3325-2.3", name: "เสาประตู", baseCost: 1494, sortOrder: 137, variants: [{ colorId: colorWhite.id, unitCost: 1494 }, { colorId: colorBlack.id, unitCost: 1494 }, { colorId: colorSilver.id, unitCost: 1618 }] },
    { code: "STD-3344-1.0", name: "ชนกลางรางแขวน", baseCost: 410, sortOrder: 138, variants: [{ colorId: colorWhite.id, unitCost: 410 }, { colorId: colorBlack.id, unitCost: 410 }, { colorId: colorSilver.id, unitCost: 445 }] },
    { code: "STD-3344-1.5", name: "ชนกลางรางแขวน", baseCost: 410, sortOrder: 139, variants: [{ colorId: colorWhite.id, unitCost: 410 }, { colorId: colorBlack.id, unitCost: 410 }, { colorId: colorSilver.id, unitCost: 445 }] },
    { code: "STD-3545-2.0", name: "เสาประตูบานพับ", baseCost: 1219, sortOrder: 140, variants: [{ colorId: colorWhite.id, unitCost: 1219 }, { colorId: colorBlack.id, unitCost: 1219 }, { colorId: colorSilver.id, unitCost: 1320 }] },
    { code: "STD-3546-1.7", name: "เสาประตูบานเปด", baseCost: 1196, sortOrder: 141, variants: [{ colorId: colorWhite.id, unitCost: 1196 }, { colorId: colorBlack.id, unitCost: 1196 }, { colorId: colorSilver.id, unitCost: 1296 }] },
    { code: "STD-4001-1.0", name: "เรมบน บานเลื่อน", baseCost: 510, sortOrder: 142, variants: [{ colorId: colorWhite.id, unitCost: 510 }, { colorId: colorBlack.id, unitCost: 510 }, { colorId: colorSilver.id, unitCost: 634 }] },
    { code: "STD-4001-1.5", name: "เรมบน บานเลื่อน", baseCost: 510, sortOrder: 143, variants: [{ colorId: colorWhite.id, unitCost: 510 }, { colorId: colorBlack.id, unitCost: 510 }, { colorId: colorSilver.id, unitCost: 634 }] },
    { code: "STD-4003-1.0", name: "เรมขาง บานเลื่อน", baseCost: 435, sortOrder: 144, variants: [{ colorId: colorWhite.id, unitCost: 435 }, { colorId: colorBlack.id, unitCost: 435 }, { colorId: colorSilver.id, unitCost: 486 }] },
    { code: "STD-4003-1.2", name: "เรมขาง บานเลื่อน", baseCost: 435, sortOrder: 145, variants: [{ colorId: colorWhite.id, unitCost: 435 }, { colorId: colorBlack.id, unitCost: 435 }, { colorId: colorSilver.id, unitCost: 486 }] },
    { code: "STD-4004-1.0", name: "เรมบน", baseCost: 462, sortOrder: 146, variants: [{ colorId: colorWhite.id, unitCost: 462 }, { colorId: colorBlack.id, unitCost: 462 }, { colorId: colorSilver.id, unitCost: 486 }] },
    { code: "STD-4005-1.1", name: "เรมลาง", baseCost: 362, sortOrder: 147, variants: [{ colorId: colorWhite.id, unitCost: 362 }, { colorId: colorBlack.id, unitCost: 362 }, { colorId: colorSilver.id, unitCost: 392 }] },
    { code: "STD-4006-1.0", name: "เรมขาง", baseCost: 357, sortOrder: 148, variants: [{ colorId: colorWhite.id, unitCost: 357 }, { colorId: colorBlack.id, unitCost: 357 }, { colorId: colorSilver.id, unitCost: 385 }] },
    { code: "STD-4006-1.2", name: "เรมขาง", baseCost: 357, sortOrder: 149, variants: [{ colorId: colorWhite.id, unitCost: 357 }, { colorId: colorBlack.id, unitCost: 357 }, { colorId: colorSilver.id, unitCost: 385 }] },
    { code: "STD-4010-1.0", name: "เรมลาง บานเลื่อน", baseCost: 444, sortOrder: 150, variants: [{ colorId: colorWhite.id, unitCost: 444 }, { colorId: colorBlack.id, unitCost: 444 }, { colorId: colorSilver.id, unitCost: 486 }] },
    { code: "STD-4010-1.2", name: "ตบรณี", baseCost: 168, sortOrder: 151, variants: [{ colorId: colorWhite.id, unitCost: 168 }, { colorId: colorBlack.id, unitCost: 168 }, { colorId: colorSilver.id, unitCost: 182 }] },
    { code: "STD-4010-1.5", name: "เรมลาง บานเลื่อน", baseCost: 444, sortOrder: 152, variants: [{ colorId: colorWhite.id, unitCost: 444 }, { colorId: colorBlack.id, unitCost: 444 }, { colorId: colorSilver.id, unitCost: 486 }] },
    { code: "STD-4011-1.0", name: "เสากุแจ", baseCost: 513, sortOrder: 153, variants: [{ colorId: colorWhite.id, unitCost: 513 }, { colorId: colorBlack.id, unitCost: 513 }, { colorId: colorSilver.id, unitCost: 570 }] },
    { code: "STD-4011-1.5", name: "เสากุแจ", baseCost: 513, sortOrder: 154, variants: [{ colorId: colorWhite.id, unitCost: 513 }, { colorId: colorBlack.id, unitCost: 513 }, { colorId: colorSilver.id, unitCost: 570 }] },
    { code: "STD-4011-1.8", name: "เสากุแจ", baseCost: 513, sortOrder: 155, variants: [{ colorId: colorWhite.id, unitCost: 513 }, { colorId: colorBlack.id, unitCost: 513 }, { colorId: colorSilver.id, unitCost: 570 }] },
    { code: "STD-4012-1.0", name: "เสาเกี่ยว", baseCost: 507, sortOrder: 156, variants: [{ colorId: colorWhite.id, unitCost: 507 }, { colorId: colorBlack.id, unitCost: 507 }, { colorId: colorSilver.id, unitCost: 493 }] },
    { code: "STD-4012-1.5", name: "เสาเกี่ยว", baseCost: 507, sortOrder: 157, variants: [{ colorId: colorWhite.id, unitCost: 507 }, { colorId: colorBlack.id, unitCost: 507 }, { colorId: colorSilver.id, unitCost: 493 }] },
    { code: "STD-4012-2.0", name: "เสาเกี่ยว", baseCost: 507, sortOrder: 158, variants: [{ colorId: colorWhite.id, unitCost: 507 }, { colorId: colorBlack.id, unitCost: 507 }, { colorId: colorSilver.id, unitCost: 493 }] },
    { code: "STD-4013-1.0", name: "เสาตาย", baseCost: 294, sortOrder: 159, variants: [{ colorId: colorWhite.id, unitCost: 294 }, { colorId: colorBlack.id, unitCost: 294 }, { colorId: colorSilver.id, unitCost: 324 }] },
    { code: "STD-4013-1.5", name: "เสาตาย", baseCost: 294, sortOrder: 160, variants: [{ colorId: colorWhite.id, unitCost: 294 }, { colorId: colorBlack.id, unitCost: 294 }, { colorId: colorSilver.id, unitCost: 324 }] },
    { code: "STD-4014-1.0", name: "ขวางบน", baseCost: 351, sortOrder: 161, variants: [{ colorId: colorWhite.id, unitCost: 351 }, { colorId: colorBlack.id, unitCost: 351 }, { colorId: colorSilver.id, unitCost: 392 }] },
    { code: "STD-4014-1.2", name: "ขวางบน", baseCost: 351, sortOrder: 162, variants: [{ colorId: colorWhite.id, unitCost: 351 }, { colorId: colorBlack.id, unitCost: 351 }, { colorId: colorSilver.id, unitCost: 392 }] },
    { code: "STD-4014-1.5", name: "ขวางบน", baseCost: 351, sortOrder: 163, variants: [{ colorId: colorWhite.id, unitCost: 351 }, { colorId: colorBlack.id, unitCost: 351 }, { colorId: colorSilver.id, unitCost: 392 }] },
    { code: "STD-4015-1.0", name: "ขวางลาง", baseCost: 444, sortOrder: 164, variants: [{ colorId: colorWhite.id, unitCost: 444 }, { colorId: colorBlack.id, unitCost: 444 }, { colorId: colorSilver.id, unitCost: 493 }] },
    { code: "STD-4015-1.2", name: "ขวางลาง", baseCost: 444, sortOrder: 165, variants: [{ colorId: colorWhite.id, unitCost: 444 }, { colorId: colorBlack.id, unitCost: 444 }, { colorId: colorSilver.id, unitCost: 493 }] },
    { code: "STD-4016-1.0", name: "ประกบกลาง", baseCost: 184, sortOrder: 166, variants: [{ colorId: colorWhite.id, unitCost: 184 }, { colorId: colorBlack.id, unitCost: 184 }, { colorId: colorSilver.id, unitCost: 200 }] },
    { code: "STD-4017-1.2", name: "ชนกลางมุง", baseCost: 131, sortOrder: 167, variants: [{ colorId: colorWhite.id, unitCost: 131 }, { colorId: colorBlack.id, unitCost: 131 }, { colorId: colorSilver.id, unitCost: 142 }] },
    { code: "STD-4018-1.0", name: "เสนแบงกลาง", baseCost: 318, sortOrder: 168, variants: [{ colorId: colorWhite.id, unitCost: 318 }, { colorId: colorBlack.id, unitCost: 318 }, { colorId: colorSilver.id, unitCost: 344 }] },
    { code: "STD-4018-1.2", name: "เสนแบงกลาง", baseCost: 318, sortOrder: 169, variants: [{ colorId: colorWhite.id, unitCost: 318 }, { colorId: colorBlack.id, unitCost: 318 }, { colorId: colorSilver.id, unitCost: 344 }] },
    { code: "STD-4024-3.6", name: "ขาบานเปลือย", baseCost: 2394, sortOrder: 170, variants: [{ colorId: colorSilver.id, unitCost: 2394 }] },
    { code: "STD-4051-1.8", name: "เสากุแจตัวผู บิกเรม", baseCost: 911, sortOrder: 171, variants: [{ colorId: colorWhite.id, unitCost: 911 }, { colorId: colorBlack.id, unitCost: 911 }, { colorId: colorSilver.id, unitCost: 987 }] },
    { code: "STD-4053-1.8", name: "ขวางลางนอก บิกเรม", baseCost: 1216, sortOrder: 172, variants: [{ colorId: colorWhite.id, unitCost: 1216 }, { colorId: colorBlack.id, unitCost: 1216 }, { colorId: colorSilver.id, unitCost: 1316 }] },
    { code: "STD-4054-1.8", name: "เสากุแจตัวเมีย บิกเรม", baseCost: 1378, sortOrder: 173, variants: [{ colorId: colorWhite.id, unitCost: 1378 }, { colorId: colorBlack.id, unitCost: 1378 }, { colorId: colorSilver.id, unitCost: 1492 }] },
    { code: "STD-4055-3.0", name: "เรมลาง บิกเรม", baseCost: 1399, sortOrder: 174, variants: [{ colorId: colorWhite.id, unitCost: 1399 }, { colorId: colorBlack.id, unitCost: 1399 }, { colorId: colorSilver.id, unitCost: 1515 }] },
    { code: "STD-4056-2.0", name: "เรมบนบิกเรม", baseCost: 1060, sortOrder: 175, variants: [{ colorId: colorWhite.id, unitCost: 1060 }, { colorId: colorBlack.id, unitCost: 1060 }, { colorId: colorSilver.id, unitCost: 1147 }] },
    { code: "STD-4057-1.8", name: "เสาตาย บิกเรม", baseCost: 677, sortOrder: 176, variants: [{ colorId: colorWhite.id, unitCost: 677 }, { colorId: colorBlack.id, unitCost: 677 }, { colorId: colorSilver.id, unitCost: 734 }] },
    { code: "STD-4058-2.0", name: "เรมขางบิกเรม", baseCost: 1126, sortOrder: 177, variants: [{ colorId: colorWhite.id, unitCost: 1126 }, { colorId: colorBlack.id, unitCost: 1126 }, { colorId: colorSilver.id, unitCost: 1220 }] },
    { code: "STD-4059-1.8", name: "เสาเกี่ยว บิกเรม", baseCost: 1159, sortOrder: 178, variants: [{ colorId: colorWhite.id, unitCost: 1159 }, { colorId: colorBlack.id, unitCost: 1159 }, { colorId: colorSilver.id, unitCost: 1255 }] },
    { code: "STD-4060-1.8", name: "ขวางบน บิกเรม", baseCost: 596, sortOrder: 179, variants: [{ colorId: colorWhite.id, unitCost: 596 }, { colorId: colorBlack.id, unitCost: 596 }, { colorId: colorSilver.id, unitCost: 645 }] },
    { code: "STD-4112-1.3", name: "เรมลาง ขั้นบันด", baseCost: 622, sortOrder: 180, variants: [{ colorId: colorWhite.id, unitCost: 622 }, { colorId: colorBlack.id, unitCost: 622 }, { colorId: colorSilver.id, unitCost: 673 }] },
    { code: "STD-4112-1.8", name: "เรมลาง ขั้นบันด", baseCost: 622, sortOrder: 181, variants: [{ colorId: colorWhite.id, unitCost: 622 }, { colorId: colorBlack.id, unitCost: 622 }, { colorId: colorSilver.id, unitCost: 673 }] },
    { code: "STD-4484-1.1", name: "เรมลางขาสูง มมีากกันตก", baseCost: 684, sortOrder: 182, variants: [{ colorId: colorWhite.id, unitCost: 684 }, { colorId: colorBlack.id, unitCost: 684 }, { colorId: colorSilver.id, unitCost: 732 }] },
    { code: "STD-4484-1.2", name: "เรมลางขาสูง มมีากกันตก", baseCost: 684, sortOrder: 183, variants: [{ colorId: colorWhite.id, unitCost: 684 }, { colorId: colorBlack.id, unitCost: 684 }, { colorId: colorSilver.id, unitCost: 732 }] },
    { code: "STD-4484-1.5", name: "เรมลางขาสูง มมีากกันตก", baseCost: 684, sortOrder: 184, variants: [{ colorId: colorWhite.id, unitCost: 684 }, { colorId: colorBlack.id, unitCost: 684 }, { colorId: colorSilver.id, unitCost: 732 }] },
    { code: "STD-4799-1.2", name: "ตบรณีขาสูง", baseCost: 214, sortOrder: 185, variants: [{ colorId: colorWhite.id, unitCost: 214 }, { colorId: colorBlack.id, unitCost: 214 }, { colorId: colorSilver.id, unitCost: 231 }] },
    { code: "STD-4799-1.5", name: "เรมลางขาสูง มีากกันตก", baseCost: 845, sortOrder: 186, variants: [{ colorId: colorWhite.id, unitCost: 845 }, { colorId: colorBlack.id, unitCost: 845 }, { colorId: colorSilver.id, unitCost: 915 }] },
    { code: "STD-4799-1.8", name: "เรมลางขาสูง มีากกันตก", baseCost: 845, sortOrder: 187, variants: [{ colorId: colorWhite.id, unitCost: 845 }, { colorId: colorBlack.id, unitCost: 845 }, { colorId: colorSilver.id, unitCost: 915 }] },
    { code: "STD-4869-1.0", name: "เรมขาง ติดกลอง", baseCost: 834, sortOrder: 188, variants: [{ colorId: colorWhite.id, unitCost: 834 }, { colorId: colorBlack.id, unitCost: 834 }, { colorId: colorSilver.id, unitCost: 915 }] },
    { code: "STD-4869-1.5", name: "เรมขาง ติดกลอง", baseCost: 834, sortOrder: 189, variants: [{ colorId: colorWhite.id, unitCost: 834 }, { colorId: colorBlack.id, unitCost: 834 }, { colorId: colorSilver.id, unitCost: 915 }] },
    { code: "STD-4869-1.9", name: "เรมขาง ติดกลอง", baseCost: 834, sortOrder: 190, variants: [{ colorId: colorWhite.id, unitCost: 834 }, { colorId: colorBlack.id, unitCost: 834 }, { colorId: colorSilver.id, unitCost: 915 }] },
    { code: "STD-4870-1.0", name: "เรมบน ติดกลอง", baseCost: 957, sortOrder: 191, variants: [{ colorId: colorWhite.id, unitCost: 957 }, { colorId: colorBlack.id, unitCost: 957 }, { colorId: colorSilver.id, unitCost: 1050 }] },
    { code: "STD-4870-1.5", name: "เรมบน ติดกลอง", baseCost: 957, sortOrder: 192, variants: [{ colorId: colorWhite.id, unitCost: 957 }, { colorId: colorBlack.id, unitCost: 957 }, { colorId: colorSilver.id, unitCost: 1050 }] },
    { code: "STD-4870-1.8", name: "เรมบน ติดกลอง", baseCost: 957, sortOrder: 193, variants: [{ colorId: colorWhite.id, unitCost: 957 }, { colorId: colorBlack.id, unitCost: 957 }, { colorId: colorSilver.id, unitCost: 1050 }] },
    { code: "STD-4872-1.0", name: "เรมลาง ติดกลอง", baseCost: 993, sortOrder: 194, variants: [{ colorId: colorWhite.id, unitCost: 993 }, { colorId: colorBlack.id, unitCost: 993 }, { colorId: colorSilver.id, unitCost: 1080 }] },
    { code: "STD-4872-1.2", name: "เรมลาง ติดกลอง", baseCost: 993, sortOrder: 195, variants: [{ colorId: colorWhite.id, unitCost: 993 }, { colorId: colorBlack.id, unitCost: 993 }, { colorId: colorSilver.id, unitCost: 1080 }] },
    { code: "STD-4872-2.0", name: "เรมลาง ติดกลอง", baseCost: 993, sortOrder: 196, variants: [{ colorId: colorWhite.id, unitCost: 993 }, { colorId: colorBlack.id, unitCost: 993 }, { colorId: colorSilver.id, unitCost: 1080 }] },
    { code: "STD-5005-1.0", name: "คิ้วบานกระทุง", baseCost: 116, sortOrder: 197, variants: [{ colorId: colorWhite.id, unitCost: 116 }, { colorId: colorBlack.id, unitCost: 116 }, { colorId: colorSilver.id, unitCost: 127 }] },
    { code: "STD-5008-1.2", name: "คิ้วกระทุง ชองแสง", baseCost: 209, sortOrder: 198, variants: [{ colorId: colorWhite.id, unitCost: 209 }, { colorId: colorBlack.id, unitCost: 209 }, { colorId: colorSilver.id, unitCost: 227 }] },
    { code: "STD-5009-1.3", name: "อยกลาง กระทุง", baseCost: 453, sortOrder: 199, variants: [{ colorId: colorWhite.id, unitCost: 453 }, { colorId: colorBlack.id, unitCost: 453 }, { colorId: colorSilver.id, unitCost: 490 }] },
    { code: "STD-5025-1.2", name: "กรอบนอก กระทุง", baseCost: 444, sortOrder: 200, variants: [{ colorId: colorWhite.id, unitCost: 444 }, { colorId: colorBlack.id, unitCost: 444 }, { colorId: colorSilver.id, unitCost: 493 }] },
    { code: "STD-5025-1.5", name: "กรอบนอก กระทุง", baseCost: 444, sortOrder: 201, variants: [{ colorId: colorWhite.id, unitCost: 444 }, { colorId: colorBlack.id, unitCost: 444 }, { colorId: colorSilver.id, unitCost: 493 }] },
    { code: "STD-5025-2.0", name: "กรอบนอก กระทุง", baseCost: 444, sortOrder: 202, variants: [{ colorId: colorWhite.id, unitCost: 444 }, { colorId: colorBlack.id, unitCost: 444 }, { colorId: colorSilver.id, unitCost: 493 }] },
    { code: "STD-5076-1.6", name: "กรอบนอก บานกระทุง", baseCost: 407, sortOrder: 203, variants: [{ colorId: colorWhite.id, unitCost: 407 }, { colorId: colorBlack.id, unitCost: 407 }, { colorId: colorSilver.id, unitCost: 441 }] },
    { code: "STD-5080-1.6", name: "กรอบนอกขาเทา", baseCost: 312, sortOrder: 204, variants: [{ colorId: colorWhite.id, unitCost: 312 }, { colorId: colorBlack.id, unitCost: 312 }, { colorId: colorSilver.id, unitCost: 338 }] },
    { code: "STD-5499-1.2", name: "อยกลาง กระทุง", baseCost: 635, sortOrder: 205, variants: [{ colorId: colorWhite.id, unitCost: 635 }, { colorId: colorBlack.id, unitCost: 635 }, { colorId: colorSilver.id, unitCost: 688 }] },
    { code: "STD-9295-2.0", name: "กรอบบานกระทุง", baseCost: 729, sortOrder: 206, variants: [{ colorId: colorWhite.id, unitCost: 729 }, { colorId: colorBlack.id, unitCost: 729 }, { colorId: colorSilver.id, unitCost: 789 }] },
    { code: "STD-9296-2.0", name: "กรอบนอก กระทุงเปลือย", baseCost: 345, sortOrder: 207, variants: [{ colorId: colorWhite.id, unitCost: 345 }, { colorId: colorBlack.id, unitCost: 345 }, { colorId: colorSilver.id, unitCost: 374 }] },
  ];

  for (const item of stdItems) {
    const mat = await prisma.material.upsert({
      where: { code: item.code },
      update: { name: item.name, baseCost: item.baseCost },
      create: { categoryId: catStd.id, code: item.code, name: item.name,
        unit: "เส้น", baseCost: item.baseCost, sortOrder: item.sortOrder },
    });
    for (const v of item.variants) {
      await prisma.materialVariant.upsert({
        where: { materialId_colorId: { materialId: mat.id, colorId: v.colorId } },
        update: { unitCost: v.unitCost },
        create: { materialId: mat.id, colorId: v.colorId, unitCost: v.unitCost },
      });
    }
  }
  console.log(`   ✓ Alumet Standard Series: ${stdItems.length} profiles seeded`);

  // ═══════════════════════════════════════════════════════════
  // 21. SMART X PRODUCT TEMPLATES
  //     Source: Smart X_Catalogue 2026_100369.pdf
  //     Bar length: 6000 mm (Smart X standard stock)
  // ═══════════════════════════════════════════════════════════
  console.log("\n→ Seeding Smart X ProductTemplates...");

  // Helper: look up a Material by code, throw if missing
  const mat = async (code: string) => {
    const m = await prisma.material.findUnique({ where: { code }, select: { id: true } });
    if (!m) throw new Error(`Material not found: ${code}`);
    return m.id;
  };

  // ── Template 1: Smart X Sliding Door/Window 2-Panel ─────────
  const tmplSliding = await prisma.productTemplate.upsert({
    where: { slug: "smartx-sliding-2panel" },
    update: { name: "Smart X Sliding Door/Window 2-Panel" },
    create: {
      categoryId: catSmartX.id,
      name: "Smart X Sliding Door/Window 2-Panel",
      slug: "smartx-sliding-2panel",
      description: "บานเลื่อนสลับ 2 บาน ระบบ Smart X — 3-track outer frame, 2 sliding panels",
      standardBarLengthMm: 6000,
      kerfMm: 0,
      sortOrder: 10,
    },
  });
  // Delete old components so upsert is idempotent
  await prisma.templateComponent.deleteMany({ where: { templateId: tmplSliding.id } });
  await prisma.templateComponent.createMany({
    data: [
      // Outer frame — horizontal (top + bottom track)
      { templateId: tmplSliding.id, materialId: await mat("SS-X101"), label: "เฟรมบน (Track Top)",      formula: "W",           quantity: 1, sortOrder: 1 },
      { templateId: tmplSliding.id, materialId: await mat("SS-X102"), label: "เฟรมล่าง (Track Bottom)",  formula: "W",           quantity: 1, sortOrder: 2 },
      // Outer frame — vertical (sides)
      { templateId: tmplSliding.id, materialId: await mat("SS-X103"), label: "เฟรมข้าง (Side Jamb)",    formula: "H",           quantity: 2, sortOrder: 3 },
      // Panel top/bottom bars — each panel = W/2 + 20mm overlap
      { templateId: tmplSliding.id, materialId: await mat("SS-X203"), label: "ขวางบน-ล่างบาน (Panel Top/Bot)", formula: "W / 2 + 20", quantity: 4, sortOrder: 4 },
      // Panel lock stile (SS-X201) and handle stile (SS-X202) — each panel height
      { templateId: tmplSliding.id, materialId: await mat("SS-X201"), label: "เสากุญแจ (Lock Stile)",   formula: "H - 45",      quantity: 2, sortOrder: 5 },
      { templateId: tmplSliding.id, materialId: await mat("SS-X202"), label: "เสามือจับ (Handle Stile)", formula: "H - 45",      quantity: 2, sortOrder: 6 },
      // Glass bead — 4 sides per panel × 2 panels
      { templateId: tmplSliding.id, materialId: await mat("SS-X204"), label: "เสริมร่องกระจก (Glass Bead H)", formula: "H - 45",  quantity: 4, sortOrder: 7 },
      { templateId: tmplSliding.id, materialId: await mat("SS-X204"), label: "เสริมร่องกระจก (Glass Bead W)", formula: "W / 2 + 20 - 60", quantity: 4, sortOrder: 8 },
    ],
  });
  // Glass spec — each pane
  await prisma.glassSpecification.deleteMany({ where: { templateId: tmplSliding.id } });
  await prisma.glassSpecification.create({
    data: { templateId: tmplSliding.id, label: "กระจกบานเลื่อน", widthFormula: "W / 2 - 30", heightFormula: "H - 80", panelCount: 2, glassType: "5mm Clear Tempered", pricePerSqM: 41.81, sortOrder: 0 },
  });
  // Accessories
  await prisma.templateAccessory.deleteMany({ where: { templateId: tmplSliding.id } });
  await prisma.templateAccessory.createMany({
    data: [
      { templateId: tmplSliding.id, name: "ล้อบานเลื่อน (Roller Set)", quantity: 4, unitCost: 85,  unit: "ชิ้น", sortOrder: 1 },
      { templateId: tmplSliding.id, name: "มือจับบานเลื่อน (Handle)",  quantity: 2, unitCost: 120, unit: "ชิ้น", sortOrder: 2 },
      { templateId: tmplSliding.id, name: "แมกเนติกซีล (Brush Seal)", quantity: 2, unitCost: 45,  unit: "เส้น", sortOrder: 3 },
    ],
  });
  console.log(`   ✓ ${tmplSliding.name}`);

  // ── Template 2: Smart X Fixed Glazing / Picture Window ──────
  const tmplFixed = await prisma.productTemplate.upsert({
    where: { slug: "smartx-fixed-glazing" },
    update: { name: "Smart X Fixed Glazing (ช่องแสงติดตาย)" },
    create: {
      categoryId: catSmartX.id,
      name: "Smart X Fixed Glazing (ช่องแสงติดตาย)",
      slug: "smartx-fixed-glazing",
      description: "บานช่องแสงติดตาย ระบบ Smart X — SF-X series outer frame + inner bead",
      standardBarLengthMm: 6000,
      kerfMm: 0,
      sortOrder: 11,
    },
  });
  await prisma.templateComponent.deleteMany({ where: { templateId: tmplFixed.id } });
  await prisma.templateComponent.createMany({
    data: [
      // Outer frame — SF-X101 (top/bottom/sides, all same profile)
      { templateId: tmplFixed.id, materialId: await mat("SF-X101"), label: "เฟรมช่องแสง (Frame H)", formula: "W",      quantity: 2, sortOrder: 1 },
      { templateId: tmplFixed.id, materialId: await mat("SF-X101"), label: "เฟรมช่องแสง (Frame V)", formula: "H",      quantity: 2, sortOrder: 2 },
      // Inner bead / stop — SF-X103
      { templateId: tmplFixed.id, materialId: await mat("SF-X103"), label: "ตบช่องแสง (Stop H)",    formula: "W - 10", quantity: 2, sortOrder: 3 },
      { templateId: tmplFixed.id, materialId: await mat("SF-X103"), label: "ตบช่องแสง (Stop V)",    formula: "H - 10", quantity: 2, sortOrder: 4 },
      // Glass bead — SF-X108 (12.7mm groove)
      { templateId: tmplFixed.id, materialId: await mat("SF-X108"), label: "คิ้วกระจก (Bead H)",   formula: "W - 40", quantity: 2, sortOrder: 5 },
      { templateId: tmplFixed.id, materialId: await mat("SF-X108"), label: "คิ้วกระจก (Bead V)",   formula: "H - 40", quantity: 2, sortOrder: 6 },
    ],
  });
  await prisma.glassSpecification.deleteMany({ where: { templateId: tmplFixed.id } });
  await prisma.glassSpecification.create({
    data: { templateId: tmplFixed.id, label: "กระจกช่องแสง", widthFormula: "W - 60", heightFormula: "H - 60", panelCount: 1, glassType: "5mm Clear Tempered", pricePerSqM: 41.81, sortOrder: 0 },
  });
  await prisma.templateAccessory.deleteMany({ where: { templateId: tmplFixed.id } });
  await prisma.templateAccessory.createMany({
    data: [
      { templateId: tmplFixed.id, name: "ซิลิโคนขอบกระจก (Glazing Silicone)", quantity: 1, unitCost: 80, unit: "หลอด", sortOrder: 1 },
    ],
  });
  console.log(`   ✓ ${tmplFixed.name}`);

  // ── Template 3: Smart X Casement Window (บานเปิด) ───────────
  const tmplCasement = await prisma.productTemplate.upsert({
    where: { slug: "smartx-casement" },
    update: { name: "Smart X Casement Window (บานเปิด)" },
    create: {
      categoryId: catSmartX.id,
      name: "Smart X Casement Window (บานเปิด)",
      slug: "smartx-casement",
      description: "บานเปิด ระบบ Smart X — SC-X outer frame + SC-X201 sash frame",
      standardBarLengthMm: 6000,
      kerfMm: 0,
      sortOrder: 12,
    },
  });
  await prisma.templateComponent.deleteMany({ where: { templateId: tmplCasement.id } });
  await prisma.templateComponent.createMany({
    data: [
      // Outer frame (SC-X101 = top+sides, SF-X109 = bottom sill)
      { templateId: tmplCasement.id, materialId: await mat("SC-X101"), label: "เฟรมบน-ข้าง (Head/Jamb H)", formula: "W",      quantity: 1, sortOrder: 1 },
      { templateId: tmplCasement.id, materialId: await mat("SC-X101"), label: "เฟรมบน-ข้าง (Head/Jamb V)", formula: "H",      quantity: 2, sortOrder: 2 },
      { templateId: tmplCasement.id, materialId: await mat("SF-X109"), label: "เฟรมล่าง (Bottom Sill)",    formula: "W",      quantity: 1, sortOrder: 3 },
      // Sash frame — SC-X201
      { templateId: tmplCasement.id, materialId: await mat("SC-X201"), label: "กรอบบาน (Sash H)",          formula: "W - 30", quantity: 2, sortOrder: 4 },
      { templateId: tmplCasement.id, materialId: await mat("SC-X201"), label: "กรอบบาน (Sash V)",          formula: "H - 35", quantity: 2, sortOrder: 5 },
      // Glass bead — SF-X108
      { templateId: tmplCasement.id, materialId: await mat("SF-X108"), label: "คิ้วกระจก (Bead H)",        formula: "W - 70", quantity: 2, sortOrder: 6 },
      { templateId: tmplCasement.id, materialId: await mat("SF-X108"), label: "คิ้วกระจก (Bead V)",        formula: "H - 70", quantity: 2, sortOrder: 7 },
    ],
  });
  await prisma.glassSpecification.deleteMany({ where: { templateId: tmplCasement.id } });
  await prisma.glassSpecification.create({
    data: { templateId: tmplCasement.id, label: "กระจกบานเปิด", widthFormula: "W - 90", heightFormula: "H - 90", panelCount: 1, glassType: "5mm Clear Tempered", pricePerSqM: 41.81, sortOrder: 0 },
  });
  await prisma.templateAccessory.deleteMany({ where: { templateId: tmplCasement.id } });
  await prisma.templateAccessory.createMany({
    data: [
      { templateId: tmplCasement.id, name: "บานพับ (Hinge)",           quantity: 2, unitCost: 180, unit: "ชิ้น", sortOrder: 1 },
      { templateId: tmplCasement.id, name: "มือจับล็อค (Handle Lock)", quantity: 1, unitCost: 250, unit: "ชุด",  sortOrder: 2 },
      { templateId: tmplCasement.id, name: "ยางซีล (Weatherstrip)",    quantity: 1, unitCost: 60,  unit: "เส้น", sortOrder: 3 },
    ],
  });
  console.log(`   ✓ ${tmplCasement.name}`);

  // ── Template 4: Smart X Awning Window (บานกระทุ้ง) ──────────
  const tmplAwning = await prisma.productTemplate.upsert({
    where: { slug: "smartx-awning" },
    update: { name: "Smart X Awning Window (บานกระทุ้ง)" },
    create: {
      categoryId: catSmartX.id,
      name: "Smart X Awning Window (บานกระทุ้ง)",
      slug: "smartx-awning",
      description: "บานกระทุ้ง ระบบ Smart X — SC-X101 outer frame + SC-X102 sash frame",
      standardBarLengthMm: 6000,
      kerfMm: 0,
      sortOrder: 13,
    },
  });
  await prisma.templateComponent.deleteMany({ where: { templateId: tmplAwning.id } });
  await prisma.templateComponent.createMany({
    data: [
      // Outer frame (top+sides = SC-X101, bottom = SF-X109)
      { templateId: tmplAwning.id, materialId: await mat("SC-X101"), label: "เฟรมบน-ข้าง (Head/Jamb H)", formula: "W",      quantity: 1, sortOrder: 1 },
      { templateId: tmplAwning.id, materialId: await mat("SC-X101"), label: "เฟรมบน-ข้าง (Head/Jamb V)", formula: "H",      quantity: 2, sortOrder: 2 },
      { templateId: tmplAwning.id, materialId: await mat("SF-X109"), label: "เฟรมล่าง (Bottom Sill)",    formula: "W",      quantity: 1, sortOrder: 3 },
      // Sash / casement frame — SC-X102
      { templateId: tmplAwning.id, materialId: await mat("SC-X102"), label: "เฟรมบาน (Sash H)",          formula: "W - 25", quantity: 2, sortOrder: 4 },
      { templateId: tmplAwning.id, materialId: await mat("SC-X102"), label: "เฟรมบาน (Sash V)",          formula: "H - 30", quantity: 2, sortOrder: 5 },
      // Frame stay / separator — SC-X103
      { templateId: tmplAwning.id, materialId: await mat("SC-X103"), label: "ซอยเฟรม (Frame Stay)",      formula: "W - 25", quantity: 1, sortOrder: 6 },
      // Glass bead — SF-X108
      { templateId: tmplAwning.id, materialId: await mat("SF-X108"), label: "คิ้วกระจก (Bead H)",        formula: "W - 65", quantity: 2, sortOrder: 7 },
      { templateId: tmplAwning.id, materialId: await mat("SF-X108"), label: "คิ้วกระจก (Bead V)",        formula: "H - 65", quantity: 2, sortOrder: 8 },
    ],
  });
  await prisma.glassSpecification.deleteMany({ where: { templateId: tmplAwning.id } });
  await prisma.glassSpecification.create({
    data: { templateId: tmplAwning.id, label: "กระจกบานกระทุ้ง", widthFormula: "W - 85", heightFormula: "H - 85", panelCount: 1, glassType: "5mm Clear Tempered", pricePerSqM: 41.81, sortOrder: 0 },
  });
  await prisma.templateAccessory.deleteMany({ where: { templateId: tmplAwning.id } });
  await prisma.templateAccessory.createMany({
    data: [
      { templateId: tmplAwning.id, name: "บานพับกระทุ้ง (Awning Hinge)", quantity: 2, unitCost: 200, unit: "ชิ้น", sortOrder: 1 },
      { templateId: tmplAwning.id, name: "ที่ค้ำบาน (Stay Arm)",          quantity: 1, unitCost: 150, unit: "ชิ้น", sortOrder: 2 },
      { templateId: tmplAwning.id, name: "มือจับ (Handle)",               quantity: 1, unitCost: 120, unit: "ชิ้น", sortOrder: 3 },
      { templateId: tmplAwning.id, name: "ยางซีล (Weatherstrip)",         quantity: 1, unitCost: 60,  unit: "เส้น", sortOrder: 4 },
    ],
  });
  console.log(`   ✓ ${tmplAwning.name}`);

  // ── Template 5: Smart X Folding Door (บานเฟี้ยม) ────────────
  const tmplFolding = await prisma.productTemplate.upsert({
    where: { slug: "smartx-folding-door" },
    update: { name: "Smart X Folding Door (บานเฟี้ยม)" },
    create: {
      categoryId: catSmartX.id,
      name: "Smart X Folding Door (บานเฟี้ยม)",
      slug: "smartx-folding-door",
      description: "บานเฟี้ยม ระบบ Smart X — SB-0xxx series outer frame + inner panel frame",
      standardBarLengthMm: 6000,
      kerfMm: 0,
      sortOrder: 14,
    },
  });
  await prisma.templateComponent.deleteMany({ where: { templateId: tmplFolding.id } });
  await prisma.templateComponent.createMany({
    data: [
      // Outer header track — SB-0101
      { templateId: tmplFolding.id, materialId: await mat("SB-0101"), label: "เฟรมบน (Top Track)",        formula: "W",           quantity: 1, sortOrder: 1 },
      // Outer bottom track — SB-0103
      { templateId: tmplFolding.id, materialId: await mat("SB-0103"), label: "เฟรมล่าง (Bottom Track)",   formula: "W",           quantity: 1, sortOrder: 2 },
      // Side jambs — SB-0105
      { templateId: tmplFolding.id, materialId: await mat("SB-0105"), label: "เฟรมข้าง (Side Jamb)",      formula: "H",           quantity: 2, sortOrder: 3 },
      // Door stile (pivot post) — SB-0114
      { templateId: tmplFolding.id, materialId: await mat("SB-0114"), label: "เสาประตู (Pivot Post)",     formula: "H - 20",      quantity: 1, sortOrder: 4 },
      // Panel top/bottom — SB-0107 (each leaf = W/number_of_leaves)
      { templateId: tmplFolding.id, materialId: await mat("SB-0107"), label: "ขวางบน-ล่างบาน (Panel T/B)", formula: "W / 2 - 20",  quantity: 4, sortOrder: 5 },
      // Panel side — SB-0105 inner
      { templateId: tmplFolding.id, materialId: await mat("SB-0112"), label: "เฟรมข้างบาน-ใน (Inner Side)", formula: "H - 60",    quantity: 4, sortOrder: 6 },
      // Glass bead — SB-0108
      { templateId: tmplFolding.id, materialId: await mat("SB-0108"), label: "คิ้วบาน (Glass Bead H)",    formula: "W / 2 - 60",  quantity: 4, sortOrder: 7 },
      { templateId: tmplFolding.id, materialId: await mat("SB-0108"), label: "คิ้วบาน (Glass Bead V)",    formula: "H - 100",     quantity: 4, sortOrder: 8 },
      // Floor guide — SB-0115
      { templateId: tmplFolding.id, materialId: await mat("SB-0115"), label: "รางกั้นพื้น (Floor Guide)", formula: "W",           quantity: 1, sortOrder: 9 },
    ],
  });
  await prisma.glassSpecification.deleteMany({ where: { templateId: tmplFolding.id } });
  await prisma.glassSpecification.create({
    data: { templateId: tmplFolding.id, label: "กระจกบานเฟี้ยม", widthFormula: "W / 2 - 80", heightFormula: "H - 120", panelCount: 2, glassType: "5mm Clear Tempered", pricePerSqM: 41.81, sortOrder: 0 },
  });
  await prisma.templateAccessory.deleteMany({ where: { templateId: tmplFolding.id } });
  await prisma.templateAccessory.createMany({
    data: [
      { templateId: tmplFolding.id, name: "ล้อบนบานเฟี้ยม (Top Roller)",       quantity: 4, unitCost: 510, unit: "ชิ้น", sortOrder: 1 },
      { templateId: tmplFolding.id, name: "ไกด์ล่างบานเฟี้ยม (Bottom Guide)",   quantity: 2, unitCost: 390, unit: "ชิ้น", sortOrder: 2 },
      { templateId: tmplFolding.id, name: "บานพับบานเฟี้ยม (Fold Hinge)",       quantity: 4, unitCost: 105, unit: "ชิ้น", sortOrder: 3 },
      { templateId: tmplFolding.id, name: "มือจับบานเฟี้ยม (Handle)",           quantity: 2, unitCost: 170, unit: "ชิ้น", sortOrder: 4 },
      { templateId: tmplFolding.id, name: "ก้านล็อคบน-ล่าง (Top/Bot Rod Lock)", quantity: 2, unitCost: 215, unit: "ชิ้น", sortOrder: 5 },
    ],
  });
  console.log(`   ✓ ${tmplFolding.name}`);

  // ═══════════════════════════════════════════════════════════
  console.log("\n═══════════════════════════════════════════════════════════");
  console.log("📊 Seed summary:");
  console.log(`   Colors         : 6 (ขาว, ดำ, ซาฮาร่าเกรย์, ซาฮาร่าแซนด์, ลายไม้, เงิน)`);
  console.log(`   Categories     : 8`);
  console.log(`     1. Alumet iConiq Euro Series  (${materials.length} profiles)`);
  console.log(`     2. Alumet Flexi Series         (${flexiBarProfiles.length + 1 + flexiAccessoryPieces.length} items)`);
  console.log(`     3. Alumet Box Series           (${boxProfiles.length} items)`);
  console.log(`     4. Alumet Pro Smart Series     (${psTotal} profiles)`);
  console.log(`     5. Alumet Vista Series         (${vistaProfiles.length} profiles)`);
  console.log(`     6. Alumet Smart X Series       (${smartXProfiles.length} profiles)`);
  console.log(`     7. Alumet Accessories           (${accItems.length} items)`);
  console.log(`     8. Alumet Standard Series      (${stdItems.length} profiles)`);
  console.log(`   Smart X Templates : 5`);
  console.log(`     1. ${tmplSliding.name}`);
  console.log(`     2. ${tmplFixed.name}`);
  console.log(`     3. ${tmplCasement.name}`);
  console.log(`     4. ${tmplAwning.name}`);
  console.log(`     5. ${tmplFolding.name}`);
  console.log(`   Price Effective: iConiq 15 พ.ค. 2569 | Flexi+Box+ProSmart+Vista+SmartX 1 ส.ค. 2567 | Accessories 3 มี.ค. 2568 (ex-VAT)`);
  console.log("═══════════════════════════════════════════════════════════");
  console.log("\n✅ Full Alumet seed complete.\n");
}

main()
  .catch((e) => {
    console.error("❌ Seed failed:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

