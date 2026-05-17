/**
 * src/lib/cuttingOptimizer.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * 1D Linear Cutting Stock Optimizer — Parametric Estimator
 *
 * ALGORITHM: First Fit Decreasing (FFD)
 * ──────────────────────────────────────
 * FFD is a bin-packing heuristic proven to use at most (11/9)·OPT + 6/9 bins,
 * which in practice gives near-optimal results for aluminum cutting stock.
 *
 * Steps:
 *   1. SORT all required cuts in DESCENDING order (longest first).
 *      Why: Large cuts are hardest to place. Fitting them first leaves
 *      smaller "remainder pockets" that smaller cuts can fill efficiently.
 *
 *   2. For each cut, scan existing open bars in order.
 *      If the cut + its kerf fits in the bar's remaining space → place it there.
 *      If no existing bar has room → open a new bar.
 *
 * KERF MODEL:
 * ──────────────────────────────────────
 * Every cut consumes: cutLengthMm + kerfMm
 *
 * Physical justification:
 *   • The saw blade has a blade width ("kerf") of typically 3–5 mm.
 *   • Each cut generates one blade-width of sawdust/waste.
 *   • We model EVERY cut as consuming its length + one kerf, which is the
 *     conservative (safe) approach. The last cut at the very end of a bar
 *     technically needs no kerf (the remainder just falls off), but including
 *     kerf there adds only 1×kerfMm of conservatism per bar — negligible and
 *     avoids measurement errors on-site.
 *
 * Example with kerfMm = 5:
 *   Bar = 6000mm.
 *   Cut 1: 2000mm → consumes 2005mm  → remaining: 3995mm
 *   Cut 2: 1500mm → consumes 1505mm  → remaining: 2490mm
 *   Cut 3: 2490mm → fits exactly     → remaining: 0mm (but 5mm kerf ignored at end)
 *   Effective: 3 cuts in 1 bar instead of needing to overflow.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 */

// ─── Types ────────────────────────────────────────────────────────────────────

/**
 * One required cut, potentially needing multiple identical pieces.
 * The optimizer explodes `quantity` into individual cut entries internally.
 */
export interface CutRequest {
  label: string;       // Human-readable label, e.g., "เฟรมบน-ล่าง (ต่อบาน)"
  materialId: string;  // Used to group cuts by material before optimizing
  cutLengthMm: number; // Length of ONE cut piece in mm
  quantity: number;    // Number of identical pieces needed
  barLengthMm: number; // Stock bar length for this cut (may differ per component)
}

/**
 * A single cut recorded inside a bar assignment.
 */
export interface CutEntry {
  label: string;       // Which component this cut belongs to
  materialId: string;
  lengthMm: number;    // The cut length (not including kerf)
}

/**
 * Describes how one physical bar is utilized.
 * `cuts` are the pieces placed in this bar, in placement order.
 */
export interface BarAssignment {
  barIndex: number;       // 1-based bar number within this material group
  cuts: CutEntry[];       // All cuts placed in this bar
  usedMm: number;         // Total mm consumed (sum of cutLengths + kerfs for each cut)
  wasteMm: number;        // barLengthMm - usedMm (unused end)
  barLengthMm: number;    // The full stock bar length for reference
}

/**
 * Optimization result for ONE material group (one profile type).
 * Multiple MaterialOptimizationResult objects are produced per EstimationProject
 * — one per unique (materialId, barLengthMm) combination.
 */
export interface MaterialOptimizationResult {
  materialId: string;
  barLengthMm: number;        // stock bar length used for this group
  barsRequired: number;       // number of full bars to purchase
  bars: BarAssignment[];      // per-bar detail (for cut sheets)

  // Aggregate statistics
  totalCutsMm: number;        // sum of all raw cut lengths (no kerf)
  totalKerfMm: number;        // total kerf consumed = numberOfCuts × kerfMm
  totalUsedMm: number;        // totalCutsMm + totalKerfMm
  totalWasteMm: number;       // (barsRequired × barLengthMm) - totalUsedMm
  wastePercent: number;       // (totalWasteMm / (barsRequired × barLengthMm)) × 100
  utilizationPercent: number; // 100 - wastePercent
}

/**
 * Final output of the optimizer across ALL materials for one project.
 */
export interface OptimizationResult {
  ok: true;
  materials: MaterialOptimizationResult[];

  // Roll-up totals across all materials
  totalBarsRequired: number;
  overallWastePercent: number;
  overallUtilizationPercent: number;
}

export interface OptimizationError {
  ok: false;
  error: string;
}

// ─── Input ────────────────────────────────────────────────────────────────────

export interface OptimizerInput {
  cuts: CutRequest[];
  defaultBarLengthMm: number; // from ProductTemplate.standardBarLengthMm
  kerfMm: number;             // from ProductTemplate.kerfMm (e.g., 5)
}

// ─── Internal helper types ────────────────────────────────────────────────────

/** An individual exploded cut — one piece, no quantity grouping */
interface ExplodedCut {
  label: string;
  materialId: string;
  lengthMm: number;
  barLengthMm: number;
}

/** A "bin" being filled during FFD */
interface Bin {
  remainingMm: number;
  cuts: CutEntry[];
}

// ─── Core FFD Implementation ──────────────────────────────────────────────────

/**
 * Run First Fit Decreasing bin packing on a single group of cuts
 * (all cuts share the same barLengthMm).
 *
 * @param cuts      Individual cut pieces (already exploded from quantity)
 * @param barLength Stock bar length in mm
 * @param kerfMm    Saw blade kerf width in mm (consumed per cut)
 */
function ffd(
  cuts: ExplodedCut[],
  barLength: number,
  kerfMm: number
): BarAssignment[] {
  // Step 1: Sort cuts longest-first (the "Decreasing" in FFD)
  const sorted = [...cuts].sort((a, b) => b.lengthMm - a.lengthMm);

  const bins: Bin[] = [];

  for (const cut of sorted) {
    const needed = cut.lengthMm + kerfMm; // space this cut consumes in the bar

    // Validate: a single cut must fit in an empty bar
    // (This should have been caught by evalFormulasBatch, but belt-and-suspenders)
    if (cut.lengthMm > barLength) {
      throw new Error(
        `Cut "${cut.label}" (${cut.lengthMm}mm) exceeds bar length (${barLength}mm). ` +
        `Check the formula or bar length configuration.`
      );
    }

    // Step 2: "First Fit" — find the first bin with enough room
    let placed = false;
    for (const bin of bins) {
      if (bin.remainingMm >= needed) {
        bin.cuts.push({ label: cut.label, materialId: cut.materialId, lengthMm: cut.lengthMm });
        bin.remainingMm -= needed;
        placed = true;
        break;
      }
    }

    // Step 3: No existing bin fits → open a new bar
    if (!placed) {
      bins.push({
        remainingMm: barLength - needed,
        cuts: [{ label: cut.label, materialId: cut.materialId, lengthMm: cut.lengthMm }],
      });
    }
  }

  // Step 4: Convert internal bins → BarAssignment output format
  return bins.map((bin, idx) => {
    const numberOfCuts = bin.cuts.length;
    const rawCutsMm   = bin.cuts.reduce((sum, c) => sum + c.lengthMm, 0);
    const kerfTotal   = numberOfCuts * kerfMm;
    const usedMm      = rawCutsMm + kerfTotal;
    const wasteMm     = barLength - usedMm;

    return {
      barIndex: idx + 1,
      cuts: bin.cuts,
      usedMm,
      wasteMm: Math.max(0, wasteMm), // guard against floating-point drift
      barLengthMm: barLength,
    };
  });
}

// ─── Grouping & Aggregation ───────────────────────────────────────────────────

/**
 * Groups CutRequests by (materialId + barLengthMm) and runs FFD per group.
 * Different materials may have different bar lengths (per-component override).
 */
function optimizeByMaterial(
  cuts: CutRequest[],
  kerfMm: number
): MaterialOptimizationResult[] {
  // Build a composite key so we split correctly when barLengthMm differs
  type GroupKey = string;
  const groups = new Map<GroupKey, { materialId: string; barLengthMm: number; pieces: ExplodedCut[] }>();

  for (const cut of cuts) {
    const key: GroupKey = `${cut.materialId}::${cut.barLengthMm}`;

    if (!groups.has(key)) {
      groups.set(key, { materialId: cut.materialId, barLengthMm: cut.barLengthMm, pieces: [] });
    }

    // Explode quantity into individual cut entries
    for (let i = 0; i < cut.quantity; i++) {
      groups.get(key)!.pieces.push({
        label: cut.label,
        materialId: cut.materialId,
        lengthMm: cut.cutLengthMm,
        barLengthMm: cut.barLengthMm,
      });
    }
  }

  const results: MaterialOptimizationResult[] = [];

  for (const [, group] of groups) {
    const { materialId, barLengthMm, pieces } = group;

    const bars      = ffd(pieces, barLengthMm, kerfMm);
    const totalBars = bars.length;

    const totalCutsMm = pieces.reduce((sum, p) => sum + p.lengthMm, 0);
    const totalKerfMm = pieces.length * kerfMm;
    const totalUsedMm = totalCutsMm + totalKerfMm;
    const capacity    = totalBars * barLengthMm;
    const totalWasteMm   = capacity - totalUsedMm;
    const wastePercent   = capacity > 0 ? (totalWasteMm / capacity) * 100 : 0;
    const utilizationPct = 100 - wastePercent;

    results.push({
      materialId,
      barLengthMm,
      barsRequired: totalBars,
      bars,
      totalCutsMm,
      totalKerfMm,
      totalUsedMm,
      totalWasteMm: Math.max(0, totalWasteMm),
      wastePercent: Math.max(0, wastePercent),
      utilizationPercent: Math.min(100, utilizationPct),
    });
  }

  return results;
}

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Run the 1D cutting stock optimizer for all materials in an estimation project.
 *
 * Implements First Fit Decreasing (FFD) bin packing.
 * Each unique (materialId + barLengthMm) pair is optimized independently.
 *
 * @param input  OptimizerInput containing all cut requests, bar length, and kerf
 * @returns      OptimizationResult | OptimizationError
 *
 * @example
 * const result = optimizeCuts({
 *   cuts: [
 *     { label: "รางล่าง",      materialId: "m1", cutLengthMm: 2000, quantity: 1, barLengthMm: 6000 },
 *     { label: "เฟรมบน-ล่าง", materialId: "m2", cutLengthMm: 990,  quantity: 4, barLengthMm: 6000 },
 *     { label: "ขอบยึดกระจก", materialId: "m3", cutLengthMm: 1410, quantity: 8, barLengthMm: 6000 },
 *   ],
 *   defaultBarLengthMm: 6000,
 *   kerfMm: 5,
 * });
 */
export function optimizeCuts(
  input: OptimizerInput
): OptimizationResult | OptimizationError {
  try {
    // ── Input validation ────────────────────────────────────────────────────
    if (!input.cuts || input.cuts.length === 0) {
      return { ok: false, error: "No cuts provided to the optimizer." };
    }
    if (input.kerfMm < 0) {
      return { ok: false, error: `kerfMm must be ≥ 0, got ${input.kerfMm}.` };
    }
    if (input.defaultBarLengthMm <= 0) {
      return { ok: false, error: `defaultBarLengthMm must be > 0, got ${input.defaultBarLengthMm}.` };
    }

    for (const cut of input.cuts) {
      if (cut.cutLengthMm <= 0) {
        return {
          ok: false,
          error: `Cut "${cut.label}" has invalid length ${cut.cutLengthMm}mm. Must be > 0.`,
        };
      }
      if (cut.quantity <= 0 || !Number.isInteger(cut.quantity)) {
        return {
          ok: false,
          error: `Cut "${cut.label}" has invalid quantity ${cut.quantity}. Must be a positive integer.`,
        };
      }
      if (cut.cutLengthMm + input.kerfMm > cut.barLengthMm) {
        return {
          ok: false,
          error:
            `Cut "${cut.label}" (${cut.cutLengthMm}mm + ${input.kerfMm}mm kerf = ` +
            `${cut.cutLengthMm + input.kerfMm}mm) exceeds bar length (${cut.barLengthMm}mm). ` +
            `Reduce the cut length or use a longer bar.`,
        };
      }
    }

    // ── Run FFD per material group ──────────────────────────────────────────
    const materials = optimizeByMaterial(input.cuts, input.kerfMm);

    // ── Roll-up totals ──────────────────────────────────────────────────────
    const totalBarsRequired = materials.reduce((sum, m) => sum + m.barsRequired, 0);
    const totalCapacityMm   = materials.reduce((sum, m) => sum + m.barsRequired * m.barLengthMm, 0);
    const totalUsedMm       = materials.reduce((sum, m) => sum + m.totalUsedMm, 0);
    const totalWasteMm      = totalCapacityMm - totalUsedMm;
    const overallWaste      = totalCapacityMm > 0 ? (totalWasteMm / totalCapacityMm) * 100 : 0;

    return {
      ok: true,
      materials,
      totalBarsRequired,
      overallWastePercent:       Math.max(0, overallWaste),
      overallUtilizationPercent: Math.min(100, 100 - overallWaste),
    };
  } catch (err) {
    if (err instanceof Error) {
      return { ok: false, error: err.message };
    }
    return { ok: false, error: "An unexpected error occurred in the cutting optimizer." };
  }
}

// ─── Utility: Serialize for DB storage ───────────────────────────────────────

/**
 * Serializes a MaterialOptimizationResult's bars array into the JSON string
 * format stored in `CuttingResult.cutDetails`.
 *
 * Each bar entry is a compact object suitable for rendering a cut sheet.
 */
export function serializeCutDetails(bars: BarAssignment[]): string {
  return JSON.stringify(
    bars.map((bar) => ({
      barIndex: bar.barIndex,
      cuts: bar.cuts.map((c) => ({ label: c.label, lengthMm: c.lengthMm })),
      usedMm: bar.usedMm,
      wasteMm: bar.wasteMm,
    }))
  );
}

/**
 * Deserializes the JSON string from `CuttingResult.cutDetails` back
 * into a typed array for UI rendering.
 */
export interface StoredBarDetail {
  barIndex: number;
  cuts: { label: string; lengthMm: number }[];
  usedMm: number;
  wasteMm: number;
}

export function deserializeCutDetails(json: string): StoredBarDetail[] {
  try {
    return JSON.parse(json) as StoredBarDetail[];
  } catch {
    return [];
  }
}
