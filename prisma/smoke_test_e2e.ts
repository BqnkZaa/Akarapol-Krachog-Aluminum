/**
 * End-to-end smoke test for the full parametric estimation pipeline.
 * Calls the same logic as the server action, but directly (no HTTP layer).
 *
 * Run:  npx tsx prisma/smoke_test_e2e.ts
 */

import { config } from "dotenv";
config();

import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import { evalFormula, evalFormulasBatch, type FormulaInput } from "../src/lib/formulaParser";
import { optimizeCuts, serializeCutDetails, type CutRequest } from "../src/lib/cuttingOptimizer";

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma  = new PrismaClient({ adapter });

async function main() {
  const W = 2000, H = 1500;
  console.log("=".repeat(64));
  console.log("🚀 End-to-End Parametric Estimation Smoke Test");
  console.log(`   W=${W}mm  H=${H}mm`);
  console.log("=".repeat(64));

  // ── 1. Fetch template ────────────────────────────────────────────────
  const template = await prisma.productTemplate.findFirst({
    where: { slug: "iconiq-sliding-door-2p" },
    include: {
      components: { orderBy: { sortOrder: "asc" }, include: { material: { include: { variants: true } } } },
      glass: true,
      accessories: { orderBy: { sortOrder: "asc" } },
    },
  });
  if (!template) throw new Error("Template not found — run `npx prisma db seed` first.");
  console.log(`\n✓ Template loaded: "${template.name}" (bar=${template.standardBarLengthMm}mm, kerf=${template.kerfMm}mm)`);

  // ── 2. Resolve black color ───────────────────────────────────────────
  const blackColor = await prisma.color.findFirst({ where: { name: { contains: "Black" } } });
  if (!blackColor) throw new Error("Black color not found.");
  console.log(`✓ Color: ${blackColor.name}`);

  // ── 3. Resolve variant prices ────────────────────────────────────────
  const variantPriceMap = new Map<string, number>();
  for (const comp of template.components) {
    const v = comp.material.variants.find((v) => v.colorId === blackColor.id);
    if (!v) throw new Error(`No black variant for ${comp.material.code}`);
    variantPriceMap.set(comp.material.id, v.unitCost);
    console.log(`   ${comp.material.code}  →  ฿${v.unitCost}/bar`);
  }

  // ── 4. Formula Engine ────────────────────────────────────────────────
  console.log("\n📐 Formula Engine:");
  const formulaInputs: FormulaInput[] = template.components.map((c) => ({
    label: c.label, formula: c.formula, quantity: c.quantity,
    materialId: c.material.id, barLengthMm: c.barLengthMm,
  }));
  const batchResult = evalFormulasBatch(formulaInputs, { W, H }, template.standardBarLengthMm);
  if (!batchResult.ok) throw new Error(`Formula error: ${batchResult.error}`);
  for (const cut of batchResult.cuts) {
    console.log(`   "${cut.label}"  formula → ${cut.cutLengthMm}mm × ${cut.quantity}`);
  }

  // ── 5. Bin Packing ───────────────────────────────────────────────────
  console.log("\n📦 Cutting Optimizer (FFD):");
  const cutRequests: CutRequest[] = batchResult.cuts.map((c) => ({
    label: c.label, materialId: c.materialId, cutLengthMm: c.cutLengthMm,
    quantity: c.quantity, barLengthMm: c.barLengthMm ?? template.standardBarLengthMm,
  }));
  const optResult = optimizeCuts({ cuts: cutRequests, defaultBarLengthMm: template.standardBarLengthMm, kerfMm: template.kerfMm });
  if (!optResult.ok) throw new Error(`Optimizer error: ${optResult.error}`);

  let totalMaterialCost = 0;
  for (const mat of optResult.materials) {
    const matInfo = template.components.find((c) => c.material.id === mat.materialId)!;
    const barUnitCost = variantPriceMap.get(mat.materialId)!;
    const lineCost = mat.barsRequired * barUnitCost;
    totalMaterialCost += lineCost;
    console.log(`   ${matInfo.material.code}: ${mat.barsRequired} bar(s) × ฿${barUnitCost} = ฿${lineCost}  (waste: ${mat.wastePercent.toFixed(1)}%)`);
  }

  // ── 6. Glass ────────────────────────────────────────────────────────
  let glassCost = 0;
  if (template.glass) {
    const g = template.glass;
    const gW = evalFormula(g.widthFormula,  { W, H });
    const gH = evalFormula(g.heightFormula, { W, H });
    if (!gW.ok || !gH.ok) throw new Error("Glass formula error");
    const areaSqM = g.panelCount * (gW.value / 1000) * (gH.value / 1000);
    glassCost = areaSqM * g.pricePerSqM;
    console.log(`\n🪟 Glass: ${g.panelCount} panels × ${gW.value}mm × ${gH.value}mm = ${areaSqM.toFixed(4)} m² × ฿${g.pricePerSqM}/m² = ฿${glassCost.toFixed(2)}`);
  }

  // ── 7. Accessories ──────────────────────────────────────────────────
  console.log("\n🔩 Accessories:");
  let accessoryCost = 0;
  for (const acc of template.accessories) {
    const lineCost = acc.quantity * acc.unitCost;
    accessoryCost += lineCost;
    console.log(`   ${acc.name}: ${acc.quantity} × ฿${acc.unitCost} = ฿${lineCost}`);
  }

  // ── 8. Final price ──────────────────────────────────────────────────
  const margin  = 20, labor = 500;
  const subtotal = totalMaterialCost + glassCost + accessoryCost;
  const marginAmt = subtotal * (margin / 100);
  const finalPrice = subtotal + marginAmt + labor;

  console.log("\n" + "=".repeat(64));
  console.log("💰 QUOTATION SUMMARY");
  console.log(`   Material Cost  : ฿${totalMaterialCost.toLocaleString("th-TH", { minimumFractionDigits: 2 })}`);
  console.log(`   Glass Cost     : ฿${glassCost.toFixed(2)}`);
  console.log(`   Accessories    : ฿${accessoryCost.toFixed(2)}`);
  console.log(`   Subtotal       : ฿${subtotal.toFixed(2)}`);
  console.log(`   + Margin (${margin}%): ฿${marginAmt.toFixed(2)}`);
  console.log(`   + Labor        : ฿${labor.toFixed(2)}`);
  console.log(`   ─────────────────────────────────────────────────`);
  console.log(`   FINAL PRICE    : ฿${finalPrice.toFixed(2)}`);
  console.log(`\n   Total Bars     : ${optResult.totalBarsRequired}`);
  console.log(`   Overall Waste  : ${optResult.overallWastePercent.toFixed(1)}%`);
  console.log("=".repeat(64));
  console.log("\n✅ E2E smoke test passed — pipeline is fully operational.\n");
}

main()
  .catch((e) => { console.error("❌", e); process.exit(1); })
  .finally(() => prisma.$disconnect());
