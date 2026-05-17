/**
 * Smoke test for the cutting optimizer.
 * Simulates the seeded template: iConiq Sliding Door 2-Panel
 * Input: W = 2000mm, H = 1500mm, kerf = 5mm, bar = 6000mm
 *
 * Expected cutting list (from formulas):
 *   iS-0101  W/2 - 10 = 990mm   × 4  (frame top/bottom per panel)
 *   iS-0102  H - 90   = 1410mm  × 8  (glass bead per panel side)
 *   iS-0103  W        = 2000mm  × 1  (bottom track)
 *   iS-0104  W        = 2000mm  × 1  (top track)
 *
 * Run:  npx tsx prisma/smoke_test_optimizer.ts
 */

import { optimizeCuts, serializeCutDetails } from "../src/lib/cuttingOptimizer";

const W = 2000;
const H = 1500;
const BAR = 6000;
const KERF = 5;

const result = optimizeCuts({
  defaultBarLengthMm: BAR,
  kerfMm: KERF,
  cuts: [
    { label: "เฟรมบน-ล่าง",  materialId: "iS-0101", cutLengthMm: W / 2 - 10, quantity: 4, barLengthMm: BAR },
    { label: "ขอบยึดกระจก",  materialId: "iS-0102", cutLengthMm: H - 90,     quantity: 8, barLengthMm: BAR },
    { label: "รางล่าง",       materialId: "iS-0103", cutLengthMm: W,          quantity: 1, barLengthMm: BAR },
    { label: "รางบน",         materialId: "iS-0104", cutLengthMm: W,          quantity: 1, barLengthMm: BAR },
  ],
});

if (!result.ok) {
  console.error("❌ Optimizer error:", result.error);
  process.exit(1);
}

console.log("=".repeat(60));
console.log("🔧 Cutting Optimizer Smoke Test");
console.log(`   Template: iConiq Sliding Door 2-Panel`);
console.log(`   W=${W}mm  H=${H}mm  Bar=${BAR}mm  Kerf=${KERF}mm`);
console.log("=".repeat(60));

for (const mat of result.materials) {
  console.log(`\n📦 Material: ${mat.materialId}`);
  console.log(`   Bars Required : ${mat.barsRequired}`);
  console.log(`   Bar Length    : ${mat.barLengthMm}mm`);
  console.log(`   Total Cuts    : ${mat.totalCutsMm}mm`);
  console.log(`   Total Kerf    : ${mat.totalKerfMm}mm`);
  console.log(`   Total Used    : ${mat.totalUsedMm}mm`);
  console.log(`   Total Waste   : ${mat.totalWasteMm}mm (${mat.wastePercent.toFixed(1)}%)`);
  console.log(`   Utilization   : ${mat.utilizationPercent.toFixed(1)}%`);

  for (const bar of mat.bars) {
    const cutStr = bar.cuts.map((c) => `${c.lengthMm}mm`).join(" + ");
    const kerfStr = `${bar.cuts.length}×${KERF}mm kerf`;
    console.log(`   Bar #${bar.barIndex}: [${cutStr}] + ${kerfStr} = ${bar.usedMm}mm used, ${bar.wasteMm}mm waste`);
  }
}

console.log("\n" + "=".repeat(60));
console.log(`📊 TOTAL BARS   : ${result.totalBarsRequired}`);
console.log(`📊 OVERALL WASTE: ${result.overallWastePercent.toFixed(1)}%`);
console.log(`📊 UTILIZATION  : ${result.overallUtilizationPercent.toFixed(1)}%`);
console.log("=".repeat(60));
console.log("\n✅ Smoke test passed.\n");
