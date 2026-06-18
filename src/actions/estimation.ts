/**
 * src/actions/estimation.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Server Actions — Parametric Estimation Engine (v2)
 *
 * PRIMARY ACTION:
 *   runParametricEstimation(payload)
 *     1. Fetch template (components + formulas, glass spec, accessories)
 *     2. Fetch MaterialVariant unit costs for the selected color
 *     3. Run Formula Parser on every component → Cutting List
 *     4. Run FFD Cutting Optimizer per material → Bars Required + Waste
 *     5. Calculate Glass Cost (area formula → ft² → THB)
 *     6. Calculate Accessories Cost (fixed per template)
 *     7. Calculate Final Price with margin / labor / discount
 *     8. Persist EstimationProject + CuttingResult[] in one DB transaction
 *
 * READ ACTIONS:
 *   getEstimationProjects()        → dashboard listing
 *   getEstimationProjectById(id)   → full detail with cutting results
 * ─────────────────────────────────────────────────────────────────────────────
 */

"use server";

import prisma from "@/lib/prisma";
import { revalidatePath } from "next/cache";
import {
  evalFormula,
  evalFormulasBatch,
  type FormulaInput,
} from "@/lib/formulaParser";
import {
  optimizeCuts,
  serializeCutDetails,
  deserializeCutDetails,
  type CutRequest,
  type MaterialOptimizationResult,
  type StoredBarDetail,
} from "@/lib/cuttingOptimizer";

// ─── Input Types ──────────────────────────────────────────────────────────────

export interface RunEstimationPayload {
  // ── Template & color selection ──────────────────────────────────────────
  templateId: string;
  colorId: string;

  // ── Parametric dimensions (user input, in mm) ───────────────────────────
  widthMm: number;   // W
  heightMm: number;  // H
  h1?: number;
  h2?: number;
  w1?: number;
  w2?: number;

  // ── Customer / project metadata ─────────────────────────────────────────
  projectName: string;
  customerName?: string;
  customerPhone?: string;
  customerAddress?: string;
  notes?: string;

  // ── Pricing modifiers ────────────────────────────────────────────────────
  profitMarginPercent: number; // e.g. 20 → 20%
  laborCostPerSqM: number;     // THB per m² — multiplied by total opening area
  additionalCost?: number;     // misc flat THB
  discountPercent?: number;    // e.g. 5 → 5%

  // ── Manual Overrides ─────────────────────────────────────────────────────
  isManualOverride?: boolean;
  manualMaterials?: CuttingResultSummary[];
  manualAccessories?: AccessoryDetail[];
  manualGlass?: GlassDetail[];

  // ── Pricing Mode ─────────────────────────────────────────────────────────
  aluminumPricingMode?: string; // "FULL_LENGTH" | "EXACT_USAGE"
}

// ─── Output Types ─────────────────────────────────────────────────────────────

/** Per-material cutting result for the frontend to render the cut sheet */
export interface CuttingResultSummary {
  materialId: string;
  materialCode: string;
  materialName: string;
  barLengthMm: number;
  barsRequired: number;
  barUnitCost: number;         // THB per bar for selected color
  materialLineCost: number;    // pro-rated or full-length cost depending on mode
  totalCutsMm: number;
  totalWasteMm: number;
  wastePercent: number;
  utilizationPercent: number;
  bars: StoredBarDetail[];     // deserialized bar assignments for cut sheet display
}

/** Glass calculation detail for the quotation view */
export interface GlassDetail {
  label: string;
  glassType: string;
  panelCount: number;
  widthPerPanelMm: number;
  heightPerPanelMm: number;
  areaSqFt: number;            // total glass area in sq.ft
  pricePerSqFt: number;
  glassCost: number;           // total glass cost THB
}

/** Accessories detail for the quotation view */
export interface AccessoryDetail {
  name: string;
  quantity: number;
  unitCost: number;
  unit: string;
  lineCost: number;            // quantity × unitCost
}

/** Complete pricing breakdown */
export interface QuotationSummary {
  materialCost: number;        // sum of all bar costs depending on mode
  glassCost: number;
  accessoryCost: number;
  subtotal: number;            // materialCost + glassCost + accessoryCost
  marginAmount: number;        // subtotal × marginPercent / 100
  laborCost: number;           // area-based labor cost (areaSqM × laborCostPerSqM)
  additionalCost: number;
  beforeDiscount: number;      // subtotal + marginAmount + laborCost + additionalCost
  discountAmount: number;      // beforeDiscount × discountPercent / 100
  finalPrice: number;          // beforeDiscount - discountAmount
}

export type RunEstimationResult =
  | {
      success: true;
      projectId: string;
      templateName: string;
      colorName: string;
      widthMm: number;
      heightMm: number;
      w1?: number | null;
      w2?: number | null;
      h1?: number | null;
      h2?: number | null;
      cuttingResults: CuttingResultSummary[];
      glassDetail: GlassDetail[];
      accessories: AccessoryDetail[];
      summary: QuotationSummary;
      totalMaterialCostExact?: number;
      totalMaterialCostFullLength?: number;
    }
  | {
      success: false;
      error: string;
      field?: string; // which step/field caused the error
    };

// ─── Internal: Price Calculation ──────────────────────────────────────────────

function buildQuotationSummary(
  materialCost: number,
  glassCost: number,
  accessoryCost: number,
  marginPercent: number,
  laborCost: number,
  additional: number,
  discountPercent: number
): QuotationSummary {
  const subtotal = materialCost + glassCost + accessoryCost;
  const marginAmount = subtotal * (marginPercent / 100);
  const beforeDiscount = subtotal + marginAmount + laborCost + additional;
  const discountAmount = beforeDiscount * (discountPercent / 100);
  const finalPrice = beforeDiscount - discountAmount;

  return {
    materialCost,
    glassCost,
    accessoryCost,
    subtotal,
    marginAmount,
    laborCost,
    additionalCost: additional,
    beforeDiscount,
    discountAmount,
    finalPrice,
  };
}

// ─── PRIMARY ACTION ───────────────────────────────────────────────────────────

/**
 * The full parametric estimation pipeline:
 * Template → Formulas → Cutting Optimizer → Glass → Accessories → Price → DB
 *
 * All DB writes are atomic (Prisma transaction). If ANY step fails, nothing
 * is persisted and a descriptive error is returned to the client.
 */
export async function runParametricEstimation(
  payload: RunEstimationPayload
): Promise<RunEstimationResult> {
  try {
    // ── Step 0: Basic input validation ───────────────────────────────────────
    if (!payload.projectName?.trim()) {
      return { success: false, error: "Project name is required.", field: "projectName" };
    }
    if (!payload.templateId) {
      return { success: false, error: "Please select a template.", field: "templateId" };
    }
    if (!payload.colorId) {
      return { success: false, error: "Please select a color.", field: "colorId" };
    }
    if (!payload.widthMm || payload.widthMm <= 0) {
      return { success: false, error: "Width (W) must be a positive number.", field: "widthMm" };
    }
    if (!payload.heightMm || payload.heightMm <= 0) {
      return { success: false, error: "Height (H) must be a positive number.", field: "heightMm" };
    }
    if (payload.profitMarginPercent < 0 || payload.profitMarginPercent > 100) {
      return { success: false, error: "Profit margin must be between 0 and 100.", field: "profitMarginPercent" };
    }

    const W = payload.widthMm;
    const H = payload.heightMm;

    // ── Step 1: Fetch Template + all related data ────────────────────────────
    const template = await prisma.productTemplate.findUnique({
      where: { id: payload.templateId, isActive: true },
      include: {
        components: {
          orderBy: { sortOrder: "asc" },
          include: {
            material: {
              select: { id: true, code: true, name: true, variants: true },
            },
          },
        },
        glassSpecifications: { orderBy: { sortOrder: "asc" } },
        accessories: { orderBy: { sortOrder: "asc" } },
      },
    });

    if (!template) {
      return {
        success: false,
        error: "Template not found or is inactive. Please refresh and try again.",
        field: "templateId",
      };
    }

    // ── Step 2: Fetch color for name display ─────────────────────────────────
    const color = await prisma.color.findUnique({
      where: { id: payload.colorId, isActive: true },
      select: { id: true, name: true },
    });

    if (!color) {
      return {
        success: false,
        error: "Selected color not found or is inactive.",
        field: "colorId",
      };
    }

    // ── Step 3: Resolve color variant prices for every component ─────────────
    // Build a map: materialId → unitCost for the selected color
    // This is a single O(n) pass — no N+1 queries.
    const variantPriceMap = new Map<string, number>(); // materialId → unitCost
    const variantIdMap    = new Map<string, string>();  // materialId → variantId (for auditing)

    for (const comp of template.components) {
      const material = comp.material;

      // Find the variant matching the selected color
      const variant = material.variants.find(
        (v) => v.colorId === payload.colorId && v.isActive
      );

      if (!variant) {
        return {
          success: false,
          error:
            `Profile "${material.code} — ${material.name}" does not have a price ` +
            `for the selected color. Please choose a different color or update the material catalog.`,
          field: "colorId",
        };
      }

      variantPriceMap.set(material.id, variant.unitCost);
      variantIdMap.set(material.id, variant.id);
    }

    // ── Step 4: Run Formula Engine → Cutting List ────────────────────────────
    const formulaInputs: FormulaInput[] = template.components.map((comp) => ({
      label:       comp.label,
      formula:     comp.formula,
      quantity:    comp.quantity,
      materialId:  comp.material.id,
      barLengthMm: comp.barLengthMm, // null = use template default
    }));

    const formulaResult = evalFormulasBatch(
      formulaInputs,
      {
        W,
        H,
        H1: payload.h1 || 0,
        H2: payload.h2 || H,
        W1: payload.w1 || 0,
        W2: payload.w2 || W,
      },
      template.standardBarLengthMm
    );

    if (!formulaResult.ok) {
      return {
        success: false,
        error: formulaResult.error,
        field: "formula",
      };
    }

    // ── Step 5: Run 1D Cutting Optimizer (FFD) ───────────────────────────────
    const cutRequests: CutRequest[] = formulaResult.cuts.map((cut) => ({
      label:       cut.label,
      materialId:  cut.materialId,
      cutLengthMm: cut.cutLengthMm,
      quantity:    cut.quantity,
      // Use per-component bar length override; fall back to template default
      barLengthMm: cut.barLengthMm ?? template.standardBarLengthMm,
    }));

    const optimizerResult = optimizeCuts({
      cuts:               cutRequests,
      defaultBarLengthMm: template.standardBarLengthMm,
      kerfMm:             0, // Client request: treat cutting width (kerf) as 0
    });

    if (!optimizerResult.ok) {
      return {
        success: false,
        error: `Cutting optimization failed: ${optimizerResult.error}`,
        field: "optimizer",
      };
    }

    // ── Step 6: Build CuttingResultSummary with costs ────────────────────────
    // Merge optimizer output with material metadata + prices.
    // REQ-3: Cost is pro-rated on exact length used, NOT rounded up to full bars.
    //   Cost = (totalUsedMm / barLengthMm) * barUnitCost
    const materialMap = new Map(
      template.components.map((c) => [c.material.id, c.material])
    );

    let totalMaterialCostExact = 0;
    let totalMaterialCostFullLength = 0;
    let totalBarsUsed     = 0;

    const pricingMode = payload.aluminumPricingMode || "FULL_LENGTH";

    const cuttingResults: CuttingResultSummary[] = optimizerResult.materials.map(
      (matResult: MaterialOptimizationResult) => {
        const material    = materialMap.get(matResult.materialId)!;
        const barUnitCost = variantPriceMap.get(matResult.materialId)!;

        // Pro-rated cost
        const costExact = (matResult.totalUsedMm / matResult.barLengthMm) * barUnitCost;
        // Full length cost
        const costFullLength = matResult.barsRequired * barUnitCost;

        totalMaterialCostExact += costExact;
        totalMaterialCostFullLength += costFullLength;
        totalBarsUsed     += matResult.barsRequired; // keep full-bar count for BOM/cut list

        const lineCost = pricingMode === "EXACT_USAGE" ? costExact : costFullLength;

        return {
          materialId:         matResult.materialId,
          materialCode:       material.code,
          materialName:       material.name,
          barLengthMm:        matResult.barLengthMm,
          barsRequired:       matResult.barsRequired,
          barUnitCost,
          materialLineCost:   lineCost,
          totalCutsMm:        matResult.totalCutsMm,
          totalWasteMm:       matResult.totalWasteMm,
          wastePercent:       matResult.wastePercent,
          utilizationPercent: matResult.utilizationPercent,
          bars:               matResult.bars.map((bar) => ({
            barIndex: bar.barIndex,
            cuts:     bar.cuts.map((c) => ({ label: c.label, lengthMm: c.lengthMm })),
            usedMm:   bar.usedMm,
            wasteMm:  bar.wasteMm,
          })),
        };
      }
    );

    const totalMaterialCost = pricingMode === "EXACT_USAGE" ? totalMaterialCostExact : totalMaterialCostFullLength;

    // ── Step 7: Calculate Glass Cost ─────────────────────────────────────────
    // REQ-1: Glass area is now in Sq.Ft using the conversion:
    //   areaSqFt = (widthMm × heightMm) / 92903.04  (1 ft² = 92903.04 mm²)
    // The DB field `pricePerSqM` is treated as price-per-sq.ft going forward.
    const glassDetail: GlassDetail[] = [];
    let glassCost = 0;

    if (template.glassSpecifications && template.glassSpecifications.length > 0) {
      for (const g of template.glassSpecifications) {
        const glassWResult = evalFormula(g.widthFormula,  {
          W,
          H,
          H1: payload.h1 || 0,
          H2: payload.h2 || H,
          W1: payload.w1 || 0,
          W2: payload.w2 || W,
        });
        const glassHResult = evalFormula(g.heightFormula, {
          W,
          H,
          H1: payload.h1 || 0,
          H2: payload.h2 || H,
          W1: payload.w1 || 0,
          W2: payload.w2 || W,
        });

        if (!glassWResult.ok) {
          return {
            success: false,
            error: `Glass "${g.label}" width formula error: ${glassWResult.error}`,
            field: "glass.widthFormula",
          };
        }
        if (!glassHResult.ok) {
          return {
            success: false,
            error: `Glass "${g.label}" height formula error: ${glassHResult.error}`,
            field: "glass.heightFormula",
          };
        }

        const widthPerPanelMm  = Math.round(glassWResult.value);
        const heightPerPanelMm = Math.round(glassHResult.value);

        // Convert mm² → ft²: divide by 92903.04 (1 ft² = 304.8mm × 304.8mm)
        const MM2_PER_SQFT = 92903.04;
        const areaSqFt = g.panelCount * (widthPerPanelMm * heightPerPanelMm) / MM2_PER_SQFT;

        const cost = areaSqFt * g.pricePerSqM;
        glassCost += cost;

        glassDetail.push({
          label:             g.label,
          glassType:         g.glassType,
          panelCount:        g.panelCount,
          widthPerPanelMm,
          heightPerPanelMm,
          areaSqFt:          Math.round(areaSqFt * 10000) / 10000, // 4 decimal places
          pricePerSqFt:      g.pricePerSqM,
          glassCost:         Math.round(cost * 100) / 100,
        });
      }
    }

    // ── Step 8: Calculate Accessories Cost ───────────────────────────────────
    let totalAccessoryCost = 0;
    const accessories: AccessoryDetail[] = template.accessories.map((acc) => {
      const lineCost = acc.quantity * acc.unitCost;
      totalAccessoryCost += lineCost;
      return {
        name:     acc.name,
        quantity: acc.quantity,
        unitCost: acc.unitCost,
        unit:     acc.unit,
        lineCost,
      };
    });

    // ── Step 9: Final Pricing Summary ────────────────────────────────────────
    // Calculate area-based labor cost (labor per m² × opening area in m²)
    const margin     = payload.profitMarginPercent;
    const laborPerSqM = Math.max(0, payload.laborCostPerSqM ?? 0);
    const additional = Math.max(0, payload.additionalCost ?? 0);
    const discount   = Math.max(0, Math.min(100, payload.discountPercent ?? 0));

    // Opening area in m²: (W mm × H mm) / 1,000,000
    const openingAreaSqM = (W * H) / 1_000_000;
    const laborCost   = Math.round(openingAreaSqM * laborPerSqM * 100) / 100;

    const summary = buildQuotationSummary(
      totalMaterialCost,
      glassCost,
      totalAccessoryCost,
      margin,
      laborCost,
      additional,
      discount
    );

    // ── Step 10: Persist atomically in a Prisma transaction ──────────────────
    // All records are created or NONE — no partial saves.
    const savedProject = await prisma.$transaction(async (tx) => {
      // Create the EstimationProject
      const project = await tx.estimationProject.create({
        data: {
          projectName:     payload.projectName.trim(),
          customerName:    payload.customerName?.trim()    ?? null,
          customerPhone:   payload.customerPhone?.trim()   ?? null,
          customerAddress: payload.customerAddress?.trim() ?? null,
          notes:           payload.notes?.trim()            ?? null,

          templateId: payload.templateId,
          colorId:    payload.colorId,
          widthMm:    W,
          heightMm:   H,
          h1:         payload.h1 ?? null,
          h2:         payload.h2 ?? null,
          w1:         payload.w1 ?? null,
          w2:         payload.w2 ?? null,

          profitMarginPercent: margin,
          // Snapshot area-based labor so the saved quote is self-contained
          laborCost:           laborCost,
          additionalCost:      additional,
          discountPercent:     discount,
          aluminumPricingMode: pricingMode,

          // Snapshot computed costs so this quote is immutable to future price changes
          glassCost:     summary.glassCost,
          accessoryCost: summary.accessoryCost,
          materialCost:  summary.materialCost,
          totalBarsUsed,
          wastePercent:  optimizerResult.overallWastePercent,

          status: "DRAFT",
        },
        select: { id: true },
      });

      // Create one CuttingResult row per material group
      await tx.cuttingResult.createMany({
        data: optimizerResult.materials.map((matResult) => {
          const material    = materialMap.get(matResult.materialId)!;
          const barUnitCost = variantPriceMap.get(matResult.materialId)!;

          return {
            estimationProjectId: project.id,
            materialId:          matResult.materialId,
            materialCode:        material.code,
            materialName:        material.name,
            barUnitCost,
            barLengthMm:         matResult.barLengthMm,
            barsRequired:        matResult.barsRequired,
            cutDetails:          serializeCutDetails(matResult.bars),
            totalUsedMm:         matResult.totalUsedMm,
            totalWasteMm:        matResult.totalWasteMm,
            wastePercent:        matResult.wastePercent,
          };
        }),
      });

      return project;
    });

    // ── Step 11: Revalidate & Return ─────────────────────────────────────────
    revalidatePath("/estimates");

    return {
      success: true,
      projectId:      savedProject.id,
      templateName:   template.name,
      colorName:      color.name,
      widthMm:        W,
      heightMm:       H,
      w1:             payload.w1,
      w2:             payload.w2,
      h1:             payload.h1,
      h2:             payload.h2,
      cuttingResults,
      glassDetail,
      accessories,
      summary,
      totalMaterialCostExact,
      totalMaterialCostFullLength,
    };
  } catch (err) {
    console.error("[runParametricEstimation] Unexpected error:", err);
    return {
      success: false,
      error: "An unexpected server error occurred. Please try again.",
    };
  }
}

// ─── READ ACTIONS ─────────────────────────────────────────────────────────────

export interface EstimationProjectListItem {
  id: string;
  projectName: string;
  customerName: string | null;
  templateName: string;
  colorName: string;
  widthMm: number;
  heightMm: number;
  totalBarsUsed: number;
  wastePercent: number;
  status: string;
  createdAt: Date;
}

/**
 * Fetch all estimation projects for the dashboard listing.
 * Lean query — no cutting result detail included.
 */
export async function getEstimationProjects(): Promise<EstimationProjectListItem[]> {
  const projects = await prisma.estimationProject.findMany({
    orderBy: { createdAt: "desc" },
    select: {
      id:           true,
      projectName:  true,
      customerName: true,
      widthMm:      true,
      heightMm:     true,
      totalBarsUsed: true,
      wastePercent: true,
      status:       true,
      createdAt:    true,
      template: { select: { name: true } },
      color:    { select: { name: true } },
    },
  });

  return projects.map((p) => ({
    id:           p.id,
    projectName:  p.projectName,
    customerName: p.customerName,
    templateName: p.template.name,
    colorName:    p.color.name,
    widthMm:      p.widthMm,
    heightMm:     p.heightMm,
    totalBarsUsed: p.totalBarsUsed,
    wastePercent: p.wastePercent,
    status:       p.status,
    createdAt:    p.createdAt,
  }));
}

/** Full project detail including all cutting results */
export interface EstimationProjectDetail {
  id: string;
  projectName: string;
  customerName: string | null;
  customerPhone: string | null;
  customerAddress: string | null;
  notes: string | null;
  templateName: string;
  colorName: string;
  widthMm: number;
  heightMm: number;
  status: string;
  createdAt: Date;
  aluminumPricingMode: string;

  // Snapshotted pricing
  glassCost: number;
  accessoryCost: number;
  materialCost: number;
  totalBarsUsed: number;
  wastePercent: number;
  profitMarginPercent: number;
  laborCost: number;
  additionalCost: number;
  discountPercent: number;

  // Cutting results per material
  cuttingResults: {
    id: string;
    materialCode: string;
    materialName: string;
    barLengthMm: number;
    barsRequired: number;
    barUnitCost: number;
    materialLineCost: number;
    totalUsedMm: number;
    totalWasteMm: number;
    wastePercent: number;
    bars: StoredBarDetail[];
  }[];

  // Recomputed summary from snapshots
  summary: QuotationSummary;
}

/**
 * Fetch one project with full cutting detail.
 * Used by the quotation view and print page.
 */
export async function getEstimationProjectById(
  id: string
): Promise<EstimationProjectDetail | null> {
  const project = await prisma.estimationProject.findUnique({
    where: { id },
    include: {
      template:  { select: { name: true } },
      color:     { select: { name: true } },
      cuttingResults: {
        orderBy: { createdAt: "asc" },
      },
    },
  });

  if (!project) return null;

  // Recompute the summary from the snapshotted cost fields
  const summary = buildQuotationSummary(
    project.materialCost,
    project.glassCost,
    project.accessoryCost,
    project.profitMarginPercent,
    project.laborCost,
    project.additionalCost,
    project.discountPercent
  );

  return {
    id:              project.id,
    projectName:     project.projectName,
    customerName:    project.customerName,
    customerPhone:   project.customerPhone,
    customerAddress: project.customerAddress,
    notes:           project.notes,
    templateName:    project.template.name,
    colorName:       project.color.name,
    widthMm:         project.widthMm,
    heightMm:        project.heightMm,
    status:          project.status,
    createdAt:       project.createdAt,
    aluminumPricingMode: project.aluminumPricingMode,

    glassCost:           project.glassCost,
    accessoryCost:       project.accessoryCost,
    materialCost:        project.materialCost,
    totalBarsUsed:       project.totalBarsUsed,
    wastePercent:        project.wastePercent,
    profitMarginPercent: project.profitMarginPercent,
    laborCost:           project.laborCost,
    additionalCost:      project.additionalCost,
    discountPercent:     project.discountPercent,

    cuttingResults: project.cuttingResults.map((cr) => ({
      id:               cr.id,
      materialCode:     cr.materialCode,
      materialName:     cr.materialName,
      barLengthMm:      cr.barLengthMm,
      barsRequired:     cr.barsRequired,
      barUnitCost:      cr.barUnitCost,
      materialLineCost: project.aluminumPricingMode === "EXACT_USAGE"
        ? (cr.totalUsedMm / cr.barLengthMm) * cr.barUnitCost
        : cr.barsRequired * cr.barUnitCost,
      totalUsedMm:      cr.totalUsedMm,
      totalWasteMm:     cr.totalWasteMm,
      wastePercent:     cr.wastePercent,
      bars:             deserializeCutDetails(cr.cutDetails),
    })),

    summary,
  };
}

// ─── TEMPLATE CATALOG ACTIONS (for the Step 5 Wizard) ────────────────────────

export interface TemplateOption {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  imageUrl: string | null;
  standardBarLengthMm: number;
  kerfMm: number;
  categoryName: string;
  componentCount: number;
  hasGlass: boolean;
  accessoryCount: number;
  defaultProfitMargin: number;
  defaultLaborCost: number;
}

/**
 * Fetch all active templates for the wizard's template selection step.
 * Returns enough metadata to render a card without loading formulas.
 */
export async function getTemplates(): Promise<TemplateOption[]> {
  const templates = await prisma.productTemplate.findMany({
    where: { isActive: true },
    orderBy: [{ category: { sortOrder: "asc" } }, { sortOrder: "asc" }],
    include: {
      category:    { select: { name: true } },
      _count:      { select: { components: true, accessories: true } },
      glassSpecifications: { select: { id: true } },
    },
  });

  return templates.map((t) => ({
    id:                  t.id,
    name:                t.name,
    slug:                t.slug,
    description:         t.description,
    imageUrl:            t.imageUrl,
    standardBarLengthMm: t.standardBarLengthMm,
    kerfMm:              t.kerfMm,
    categoryName:        t.category.name,
    componentCount:      t._count.components,
    hasGlass:            t.glassSpecifications.length > 0,
    accessoryCount:      t._count.accessories,
    defaultProfitMargin: t.defaultProfitMargin,
    defaultLaborCost:    t.defaultLaborCost,
  }));
}

export interface ColorOption {
  id: string;
  name: string;
  hexCode: string | null;
}

/**
 * Fetch colors available for a specific template.
 * A color is "available" if ALL components in the template have a variant for it.
 * This prevents selecting a color that lacks pricing for one of the profiles.
 */
export async function getAvailableColors(
  templateId: string
): Promise<ColorOption[]> {
  // Fetch all component materials for this template
  const template = await prisma.productTemplate.findUnique({
    where: { id: templateId },
    include: {
      components: {
        include: {
          material: {
            include: { variants: { include: { color: true } } },
          },
        },
      },
    },
  });

  if (!template || template.components.length === 0) return [];

  // Find colors that exist as a variant in EVERY component's material
  // Start with all colors from the first material, then intersect
  const colorSets = template.components.map((comp) => {
    const colorIds = new Set(
      comp.material.variants
        .filter((v) => v.isActive)
        .map((v) => v.colorId)
    );
    return { colorIds, variants: comp.material.variants };
  });

  // Intersection: only colors present in ALL materials
  const universalColorIds = colorSets.reduce(
    (intersection, { colorIds }) =>
      new Set([...intersection].filter((id) => colorIds.has(id))),
    colorSets[0].colorIds
  );

  // Collect color details from first material's variants (all materials share the same colors)
  const allColors = await prisma.color.findMany({
    where: { id: { in: [...universalColorIds] }, isActive: true },
    orderBy: { sortOrder: "asc" },
    select: { id: true, name: true, hexCode: true },
  });

  return allColors;
}
