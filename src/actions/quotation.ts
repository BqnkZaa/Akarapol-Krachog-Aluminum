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
import {
  type RunEstimationPayload,
  type RunEstimationResult,
  type CuttingResultSummary,
  type GlassDetail,
  type AccessoryDetail,
  type QuotationSummary,
} from "./estimation";

const PAGE_SIZE = 20;

export interface QuotationListItem {
  id: string;
  projectName: string;
  customerName: string | null;
  templateName: string;
  createdAt: Date;
  finalPrice: number;
  status: string;
  imageUrl?: string | null;
}

export async function getQuotations(page: number = 1) {
  const skip = (page - 1) * PAGE_SIZE;

  const [projects, total] = await Promise.all([
    prisma.estimationProject.findMany({
      skip,
      take: PAGE_SIZE,
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        projectName: true,
        customerName: true,
        createdAt: true,
        status: true,
        glassCost: true,
        accessoryCost: true,
        materialCost: true,
        profitMarginPercent: true,
        laborCost: true,
        additionalCost: true,
        discountPercent: true,
        template: {
          select: {
            name: true,
            imageUrl: true,
          },
        },
      },
    }),
    prisma.estimationProject.count(),
  ]);

  const items: QuotationListItem[] = projects.map((p) => {
    // Recompute total price dynamically
    const subtotal = p.materialCost + p.glassCost + p.accessoryCost;
    const marginAmount = subtotal * (p.profitMarginPercent / 100);
    const beforeDiscount = subtotal + marginAmount + p.laborCost + p.additionalCost;
    const discountAmount = beforeDiscount * (p.discountPercent / 100);
    const finalPrice = beforeDiscount - discountAmount;

    return {
      id: p.id,
      projectName: p.projectName,
      customerName: p.customerName,
      templateName: p.template.name,
      createdAt: p.createdAt,
      finalPrice: Math.round(finalPrice * 100) / 100,
      status: p.status,
      imageUrl: p.template.imageUrl,
    };
  });

  return { items, total, totalPages: Math.ceil(total / PAGE_SIZE) };
}

export async function deleteQuotation(id: string) {
  try {
    await prisma.estimationProject.delete({
      where: { id },
    });
    revalidatePath("/quotations");
    return { success: true };
  } catch (error) {
    console.error("[deleteQuotation] Error deleting quotation:", error);
    return { success: false, error: "Failed to delete quotation" };
  }
}

// ─── Helper: Recompute summary ──────────────────────────────────────────────
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

// ─── GET BY ID SERVER ACTION ────────────────────────────────────────────────
export async function getQuotationById(id: string) {
  try {
    const project = await prisma.estimationProject.findUnique({
      where: { id },
      include: {
        template: {
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
        },
        color: true,
        cuttingResults: {
          orderBy: { createdAt: "asc" },
        },
      },
    });

    if (!project) return null;

    // Deserialize cutting details for each cutting result
    const cuttingResultsWithBars = project.cuttingResults.map((cr) => ({
      id: cr.id,
      materialId: cr.materialId,
      materialCode: cr.materialCode,
      materialName: cr.materialName,
      barLengthMm: cr.barLengthMm,
      barsRequired: cr.barsRequired,
      barUnitCost: cr.barUnitCost,
      materialLineCost: project.aluminumPricingMode === "EXACT_USAGE"
        ? (cr.totalUsedMm / cr.barLengthMm) * cr.barUnitCost
        : cr.barsRequired * cr.barUnitCost,
      totalUsedMm: cr.totalUsedMm,
      totalWasteMm: cr.totalWasteMm,
      wastePercent: cr.wastePercent,
      utilizationPercent: cr.barsRequired > 0 
        ? ((cr.totalUsedMm) / (cr.barsRequired * cr.barLengthMm)) * 100 
        : 0,
      bars: deserializeCutDetails(cr.cutDetails),
    }));

    // Evaluate component lengths driven by the width/height formulas
    const components = project.template.components.map((comp) => {
      const evalRes = evalFormula(comp.formula, {
        W: project.widthMm,
        H: project.heightMm,
        H1: project.h1 || 0,
        H2: project.h2 || project.heightMm,
        W1: project.w1 || 0,
        W2: project.w2 || project.widthMm,
      });
      return {
        label: comp.label,
        formula: comp.formula,
        lengthMm: evalRes.ok ? evalRes.value : 0,
        quantity: comp.quantity,
        materialCode: comp.material.code,
        materialName: comp.material.name,
      };
    });

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

    // Initialize override state
    let isManualOverride = false;
    let userNotes = project.notes || "";
    let accessories = project.template.accessories.map((acc) => ({
      name: acc.name,
      quantity: acc.quantity,
      unitCost: acc.unitCost,
      unit: acc.unit,
      lineCost: acc.quantity * acc.unitCost,
    }));

    let glassDetail: any[] = [];
    if (project.template.glassSpecifications && project.template.glassSpecifications.length > 0) {
      for (const g of project.template.glassSpecifications) {
        const glassWResult = evalFormula(g.widthFormula, {
          W: project.widthMm,
          H: project.heightMm,
          H1: project.h1 || 0,
          H2: project.h2 || project.heightMm,
          W1: project.w1 || 0,
          W2: project.w2 || project.widthMm,
        });
        const glassHResult = evalFormula(g.heightFormula, {
          W: project.widthMm,
          H: project.heightMm,
          H1: project.h1 || 0,
          H2: project.h2 || project.heightMm,
          W1: project.w1 || 0,
          W2: project.w2 || project.widthMm,
        });
        const widthPerPanelMm = glassWResult.ok ? Math.round(glassWResult.value) : 0;
        const heightPerPanelMm = glassHResult.ok ? Math.round(glassHResult.value) : 0;

        const MM2_PER_SQFT = 92903.04;
        const areaSqFt = g.panelCount * (widthPerPanelMm * heightPerPanelMm) / MM2_PER_SQFT;
        const cost = areaSqFt * g.pricePerSqM;

        glassDetail.push({
          label: g.label,
          glassType: g.glassType,
          panelCount: g.panelCount,
          widthPerPanelMm,
          heightPerPanelMm,
          areaSqFt: Math.round(areaSqFt * 10000) / 10000,
          pricePerSqFt: g.pricePerSqM,
          glassCost: Math.round(cost * 100) / 100,
        });
      }
    }

    if (project.notes) {
      try {
        const parsed = JSON.parse(project.notes);
        if (parsed && typeof parsed === "object" && parsed.isManualOverride === true) {
          isManualOverride = true;
          if (Array.isArray(parsed.accessories)) {
            accessories = parsed.accessories;
          }
          if (parsed.glassDetail) {
            glassDetail = parsed.glassDetail;
          }
          userNotes = typeof parsed.userNotes === "string" ? parsed.userNotes : "";
        }
      } catch (e) {
        // Not a JSON string, treat as regular notes
      }
    }

    // Legacy support: dynamically calculate both modes if not already present or for pricing toggle support
    let materialCostExact = 0;
    let materialCostFullLength = 0;

    if (project.cuttingResults && project.cuttingResults.length > 0) {
      for (const cr of project.cuttingResults) {
        const costExact = (cr.totalUsedMm / cr.barLengthMm) * cr.barUnitCost;
        const costFullLength = cr.barsRequired * cr.barUnitCost;
        materialCostExact += costExact;
        materialCostFullLength += costFullLength;
      }
    } else if (project.template) {
      try {
        // Resolve color variant prices
        const variantPriceMap = new Map<string, number>();
        for (const comp of project.template.components) {
          const material = comp.material;
          const variant = material.variants.find(
            (v) => v.colorId === project.colorId && v.isActive
          );
          if (variant) {
            variantPriceMap.set(material.id, variant.unitCost);
          }
        }

        // Run Formula Engine
        const formulaInputs: FormulaInput[] = project.template.components.map((comp) => ({
          label:       comp.label,
          formula:     comp.formula,
          quantity:    comp.quantity,
          materialId:  comp.material.id,
          barLengthMm: comp.barLengthMm,
        }));

        const formulaResult = evalFormulasBatch(
          formulaInputs,
          {
            W: project.widthMm,
            H: project.heightMm,
            H1: project.h1 || 0,
            H2: project.h2 || project.heightMm,
            W1: project.w1 || 0,
            W2: project.w2 || project.widthMm,
          },
          project.template.standardBarLengthMm
        );

        if (formulaResult.ok) {
          // Run Cutting Optimizer
          const cutRequests: CutRequest[] = formulaResult.cuts.map((cut) => ({
            label:       cut.label,
            materialId:  cut.materialId,
            cutLengthMm: cut.cutLengthMm,
            quantity:    cut.quantity,
            barLengthMm: cut.barLengthMm ?? project.template.standardBarLengthMm,
          }));

          const optimizerResult = optimizeCuts({
            cuts:               cutRequests,
            defaultBarLengthMm: project.template.standardBarLengthMm,
            kerfMm:             0,
          });

          if (optimizerResult.ok) {
            for (const matResult of optimizerResult.materials) {
              const barUnitCost = variantPriceMap.get(matResult.materialId) || 0;
              const costExact = (matResult.totalUsedMm / matResult.barLengthMm) * barUnitCost;
              const costFullLength = matResult.barsRequired * barUnitCost;
              materialCostExact += costExact;
              materialCostFullLength += costFullLength;
            }
          }
        }
      } catch (err) {
        console.error("Error dynamically recalculating legacy quotation:", err);
      }
    }

    return {
      ...project,
      cuttingResults: cuttingResultsWithBars,
      components,
      summary,
      glassDetail,
      accessories,
      isManualOverride,
      userNotes,
      materialCostExact: materialCostExact || project.materialCost,
      materialCostFullLength: materialCostFullLength || project.materialCost,
    };
  } catch (error) {
    console.error("[getQuotationById] Error fetching quotation:", error);
    return null;
  }
}

// ─── UPDATE QUOTATION SERVER ACTION ──────────────────────────────────────────
export async function updateQuotation(
  id: string,
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

    // Initialize pricing snapshot values
    let totalMaterialCostExact = 0;
    let totalMaterialCostFullLength = 0;
    let totalMaterialCost = 0;
    let totalBarsUsed     = 0;
    let glassCost = 0;
    let totalAccessoryCost = 0;
    let overallWastePercent = 0;

    const pricingMode = payload.aluminumPricingMode || "FULL_LENGTH";

    let cuttingResults: CuttingResultSummary[] = [];
    let glassDetail: any = null;
    let accessories: AccessoryDetail[] = [];

    const margin      = payload.profitMarginPercent;
    const laborPerSqM = Math.max(0, payload.laborCostPerSqM ?? 0);
    const additional  = Math.max(0, payload.additionalCost ?? 0);
    const discount    = Math.max(0, Math.min(100, payload.discountPercent ?? 0));

    const openingAreaSqM = (W * H) / 1_000_000;
    const laborCost      = Math.round(openingAreaSqM * laborPerSqM * 100) / 100;

    const fallbackMaterialId = template.components[0]?.material.id || (await prisma.material.findFirst())?.id || "";

    if (payload.isManualOverride) {
      // ── MANUAL OVERRIDE PATH ──
      // Sum custom material costs
      const manualMaterials = payload.manualMaterials || [];
      totalMaterialCost = 0;
      for (const mm of manualMaterials) {
        mm.materialLineCost = mm.barsRequired * mm.barUnitCost;
        totalMaterialCost += mm.materialLineCost;
        totalBarsUsed += mm.barsRequired;
      }
      totalMaterialCostExact = totalMaterialCost;
      totalMaterialCostFullLength = totalMaterialCost;
      cuttingResults = manualMaterials;

      // Sum custom glass costs
      const manualGlass = payload.manualGlass || [];
      for (const mg of manualGlass) {
        glassCost += mg.glassCost;
      }
      if (manualGlass.length > 0) {
        glassDetail = manualGlass; // Store the full list
      }

      // Sum custom accessory costs
      const manualAccessories = payload.manualAccessories || [];
      for (const ma of manualAccessories) {
        ma.lineCost = ma.quantity * ma.unitCost;
        totalAccessoryCost += ma.lineCost;
      }
      accessories = manualAccessories;
      overallWastePercent = 0;

    } else {
      // ── PARAMETRIC CALCULATIONS PATH ──
      // ── Step 3: Resolve color variant prices for every component ─────────────
      const variantPriceMap = new Map<string, number>();

      for (const comp of template.components) {
        const material = comp.material;

        const variant = material.variants.find(
          (v) => v.colorId === payload.colorId && v.isActive
        );

        if (!variant) {
          return {
            success: false,
            error:
              `Profile "${material.code} — ${material.name}" does not have a price ` +
              `for the selected color. Choose a different color or update the material catalog.`,
            field: "colorId",
          };
        }

        variantPriceMap.set(material.id, variant.unitCost);
      }

      // ── Step 4: Run Formula Engine → Cutting List ────────────────────────────
      const formulaInputs: FormulaInput[] = template.components.map((comp) => ({
        label:       comp.label,
        formula:     comp.formula,
        quantity:    comp.quantity,
        materialId:  comp.material.id,
        barLengthMm: comp.barLengthMm,
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
        barLengthMm: cut.barLengthMm ?? template.standardBarLengthMm,
      }));

      const optimizerResult = optimizeCuts({
        cuts:               cutRequests,
        defaultBarLengthMm: template.standardBarLengthMm,
        kerfMm:             0,
      });

      if (!optimizerResult.ok) {
        return {
          success: false,
          error: `Cutting optimization failed: ${optimizerResult.error}`,
          field: "optimizer",
        };
      }

      // ── Step 6: Build CuttingResultSummary with pro-rated costs ──────────────
      const materialMap = new Map(
        template.components.map((c) => [c.material.id, c.material])
      );

      overallWastePercent = optimizerResult.overallWastePercent;

      cuttingResults = optimizerResult.materials.map(
        (matResult: MaterialOptimizationResult) => {
          const material    = materialMap.get(matResult.materialId)!;
          const barUnitCost = variantPriceMap.get(matResult.materialId)!;

          // Pro-rated cost
          const costExact = (matResult.totalUsedMm / matResult.barLengthMm) * barUnitCost;
          // Full length cost
          const costFullLength = matResult.barsRequired * barUnitCost;

          totalMaterialCostExact += costExact;
          totalMaterialCostFullLength += costFullLength;
          totalBarsUsed     += matResult.barsRequired;

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

      totalMaterialCost = pricingMode === "EXACT_USAGE" ? totalMaterialCostExact : totalMaterialCostFullLength;

      // ── Step 7: Calculate Glass Cost ─────────────────────────────────────────
      glassDetail = [];
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
            areaSqFt:          Math.round(areaSqFt * 10000) / 10000,
            pricePerSqFt:      g.pricePerSqM,
            glassCost:         Math.round(cost * 100) / 100,
          });
        }
      }

      // ── Step 8: Calculate Accessories Cost ───────────────────────────────────
      accessories = template.accessories.map((acc) => {
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
    }

    // ── Step 9: Final Pricing Summary ────────────────────────────────────────
    const summary = buildQuotationSummary(
      totalMaterialCost,
      glassCost,
      totalAccessoryCost,
      margin,
      laborCost,
      additional,
      discount
    );

    // Build notes field
    let notesToSave: string | null = payload.notes?.trim() ?? null;
    if (payload.isManualOverride) {
      notesToSave = JSON.stringify({
        isManualOverride: true,
        accessories: payload.manualAccessories || [],
        glassDetail: payload.manualGlass || [],
        userNotes: payload.notes || "",
      });
    }

    // ── Step 10: Persist atomically in a Prisma transaction ──────────────────
    const savedProject = await prisma.$transaction(async (tx) => {
      // Update the EstimationProject
      const project = await tx.estimationProject.update({
        where: { id },
        data: {
          projectName:     payload.projectName.trim(),
          customerName:    payload.customerName?.trim()    ?? null,
          customerPhone:   payload.customerPhone?.trim()   ?? null,
          customerAddress: payload.customerAddress?.trim() ?? null,
          notes:           notesToSave,

          templateId: payload.templateId,
          colorId:    payload.colorId,
          widthMm:    W,
          heightMm:   H,
          h1:         payload.h1 ?? null,
          h2:         payload.h2 ?? null,
          w1:         payload.w1 ?? null,
          w2:         payload.w2 ?? null,

          profitMarginPercent: margin,
          laborCost:           laborCost,
          additionalCost:      additional,
          discountPercent:     discount,
          aluminumPricingMode: pricingMode,

          glassCost:     summary.glassCost,
          accessoryCost: summary.accessoryCost,
          materialCost:  summary.materialCost,
          totalBarsUsed,
          wastePercent:  overallWastePercent,
        },
        select: { id: true },
      });

      // Delete existing CuttingResults for this project
      await tx.cuttingResult.deleteMany({
        where: { estimationProjectId: id },
      });

      // Create new CuttingResults
      await tx.cuttingResult.createMany({
        data: cuttingResults.map((cr) => {
          return {
            estimationProjectId: id,
            materialId:          cr.materialId || fallbackMaterialId,
            materialCode:        cr.materialCode,
            materialName:        cr.materialName,
            barUnitCost:         cr.barUnitCost,
            barLengthMm:         cr.barLengthMm || template.standardBarLengthMm,
            barsRequired:        cr.barsRequired,
            cutDetails:          serializeCutDetails(
              (cr.bars || []).map((b) => ({
                barIndex: b.barIndex,
                cuts: (b.cuts || []).map((c) => ({
                  label: c.label,
                  materialId: cr.materialId || fallbackMaterialId,
                  lengthMm: c.lengthMm,
                })),
                usedMm: b.usedMm,
                wasteMm: b.wasteMm,
                barLengthMm: cr.barLengthMm || template.standardBarLengthMm,
              }))
            ),
            totalUsedMm:         (cr as any).totalUsedMm || cr.totalCutsMm || 0,
            totalWasteMm:        cr.totalWasteMm || 0,
            wastePercent:        cr.wastePercent || 0,
          };
        }),
      });

      return project;
    });

    // ── Step 11: Revalidate & Return ─────────────────────────────────────────
    revalidatePath("/quotations");
    revalidatePath("/");

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
      glassDetail:    glassDetail,
      accessories,
      summary,
      totalMaterialCostExact,
      totalMaterialCostFullLength,
    };
  } catch (err) {
    console.error("[updateQuotation] Unexpected error:", err);
    return {
      success: false,
      error: "An unexpected server error occurred. Please try again.",
    };
  }
}
