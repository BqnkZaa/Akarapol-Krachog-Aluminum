/**
 * src/actions/estimation.ts
 * ─────────────────────────────────────────────────────────────
 * Server Actions — Estimation Calculation & Persistence
 *
 * saveEstimationProject(payload) → creates a full estimation project
 *   with server-verified prices and calculated totals.
 *
 * getEstimationProjects()        → list of projects for dashboard
 * getEstimationProjectById(id)   → single project with full BOM
 * ─────────────────────────────────────────────────────────────
 */

"use server";

import prisma from "@/lib/prisma";
import { revalidatePath } from "next/cache";

// ─── Input / Output Types ──────────────────────────────────────

/** One line-item submitted from the wizard UI */
export type EstimationItemInput = {
  materialId: string;
  materialVariantId: string; // color variant — MUST exist in DB
  quantity: number;
  description?: string;
  sortOrder?: number;
};

/** Full payload to create a new estimation project */
export type SaveEstimationPayload = {
  // Project metadata
  projectName: string;
  customerName?: string;
  customerPhone?: string;
  customerAddress?: string;
  notes?: string;

  // Reference dimensions (informational only, not used in cost calc)
  refWidthMm?: number;
  refHeightMm?: number;

  // Pricing adjustments
  profitMarginPercent: number; // e.g. 15 for 15%
  laborCost: number; // flat THB
  additionalCost?: number; // misc flat THB
  discountPercent?: number; // e.g. 5 for 5%

  // BOM line items
  items: EstimationItemInput[];
};

/** Result returned to the client after saving */
export type SaveEstimationResult =
  | {
      success: true;
      projectId: string;
      summary: EstimationSummary;
    }
  | {
      success: false;
      error: string;
    };

/** Pricing summary calculated server-side */
export type EstimationSummary = {
  subtotal: number; // sum of all materialCosts
  marginAmount: number; // subtotal × margin%
  laborCost: number;
  additionalCost: number;
  discountAmount: number;
  finalPrice: number;
};

// ─── Helpers ───────────────────────────────────────────────────

function calculateSummary(
  subtotal: number,
  marginPercent: number,
  labor: number,
  additional: number,
  discountPercent: number
): EstimationSummary {
  const marginAmount = subtotal * (marginPercent / 100);
  const beforeDiscount = subtotal + marginAmount + labor + additional;
  const discountAmount = beforeDiscount * (discountPercent / 100);
  const finalPrice = beforeDiscount - discountAmount;

  return {
    subtotal,
    marginAmount,
    laborCost: labor,
    additionalCost: additional,
    discountAmount,
    finalPrice,
  };
}

// ─── Actions ───────────────────────────────────────────────────

/**
 * Save a new EstimationProject with server-verified pricing.
 *
 * Security: The client sends materialVariantId, NOT a price.
 * We look up every variant's unitCost from the database — this
 * prevents any client-side price manipulation.
 *
 * Formula per item: materialCost = quantity × unitCost  (from DB)
 */
export async function saveEstimationProject(
  payload: SaveEstimationPayload
): Promise<SaveEstimationResult> {
  try {
    // ── Validate basics ─────────────────────────────────────────
    if (!payload.projectName?.trim()) {
      return { success: false, error: "Project name is required." };
    }
    if (!payload.items || payload.items.length === 0) {
      return { success: false, error: "At least one material item is required." };
    }
    if (payload.profitMarginPercent < 0 || payload.profitMarginPercent > 100) {
      return { success: false, error: "Profit margin must be between 0 and 100." };
    }

    // ── Server-side price verification ─────────────────────────
    // Fetch all variant prices from DB in one round-trip
    const variantIds = payload.items.map((i) => i.materialVariantId);
    const dbVariants = await prisma.materialVariant.findMany({
      where: { id: { in: variantIds } },
      select: { id: true, unitCost: true, materialId: true },
    });

    // Index by id for O(1) lookup
    const variantMap = new Map(dbVariants.map((v) => [v.id, v]));

    // Verify every requested variant actually exists
    for (const item of payload.items) {
      if (!variantMap.has(item.materialVariantId)) {
        return {
          success: false,
          error: `Material variant "${item.materialVariantId}" not found. Please refresh and try again.`,
        };
      }
    }

    // ── Build line items with server-verified costs ─────────────
    let subtotal = 0;

    const itemsToCreate = payload.items.map((item, idx) => {
      const dbVariant = variantMap.get(item.materialVariantId)!;
      const qty = Math.max(1, Math.round(item.quantity)); // sanitize: min 1, integer
      const unitCost = dbVariant.unitCost; // ← from DB, not client
      const materialCost = qty * unitCost;

      subtotal += materialCost;

      return {
        materialId: item.materialId,
        materialVariantId: item.materialVariantId,
        quantity: qty,
        description: item.description?.trim() ?? null,
        sortOrder: item.sortOrder ?? idx,
        unitCost, // snapshot
        materialCost, // snapshot
      };
    });

    // ── Calculate final pricing ─────────────────────────────────
    const margin = payload.profitMarginPercent;
    const labor = Math.max(0, payload.laborCost);
    const additional = Math.max(0, payload.additionalCost ?? 0);
    const discount = Math.max(0, payload.discountPercent ?? 0);

    const summary = calculateSummary(subtotal, margin, labor, additional, discount);

    // ── Persist project + items in a single transaction ─────────
    const project = await prisma.estimationProject.create({
      data: {
        projectName: payload.projectName.trim(),
        customerName: payload.customerName?.trim() ?? null,
        customerPhone: payload.customerPhone?.trim() ?? null,
        customerAddress: payload.customerAddress?.trim() ?? null,
        notes: payload.notes?.trim() ?? null,

        refWidthMm: payload.refWidthMm ?? null,
        refHeightMm: payload.refHeightMm ?? null,

        profitMarginPercent: margin,
        laborCost: labor,
        additionalCost: additional,
        discountPercent: discount,

        status: "DRAFT",

        items: {
          create: itemsToCreate,
        },
      },
      select: { id: true },
    });

    // ── Invalidate cached pages if needed ───────────────────────
    revalidatePath("/estimates");

    return {
      success: true,
      projectId: project.id,
      summary,
    };
  } catch (err) {
    console.error("[saveEstimationProject] Error:", err);
    return {
      success: false,
      error: "An unexpected server error occurred. Please try again.",
    };
  }
}

// ─── Read Actions ──────────────────────────────────────────────

/** List type for the dashboard */
export type EstimationProjectListItem = {
  id: string;
  projectName: string;
  customerName: string | null;
  status: string;
  profitMarginPercent: number;
  laborCost: number;
  additionalCost: number;
  discountPercent: number;
  refWidthMm: number | null;
  refHeightMm: number | null;
  itemCount: number;
  createdAt: Date;
};

/**
 * Fetch all estimation projects for the dashboard listing.
 * Returns lean data — no BOM details.
 */
export async function getEstimationProjects(): Promise<
  EstimationProjectListItem[]
> {
  const projects = await prisma.estimationProject.findMany({
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      projectName: true,
      customerName: true,
      status: true,
      profitMarginPercent: true,
      laborCost: true,
      additionalCost: true,
      discountPercent: true,
      refWidthMm: true,
      refHeightMm: true,
      createdAt: true,
      _count: { select: { items: true } },
    },
  });

  return projects.map((p) => ({
    ...p,
    itemCount: p._count.items,
  }));
}

/** Full BOM detail type for the quotation view */
export type EstimationProjectDetail = {
  id: string;
  projectName: string;
  customerName: string | null;
  customerPhone: string | null;
  customerAddress: string | null;
  notes: string | null;
  refWidthMm: number | null;
  refHeightMm: number | null;
  profitMarginPercent: number;
  laborCost: number;
  additionalCost: number;
  discountPercent: number;
  status: string;
  createdAt: Date;
  items: {
    id: string;
    sortOrder: number;
    quantity: number;
    unitCost: number;
    materialCost: number;
    description: string | null;
    material: { code: string; name: string; unit: string };
    materialVariant: { color: { name: string; hexCode: string | null } } | null;
  }[];
  summary: EstimationSummary;
};

/**
 * Fetch a single estimation project with its full BOM + computed summary.
 * Used by the quotation detail / print view.
 */
export async function getEstimationProjectById(
  id: string
): Promise<EstimationProjectDetail | null> {
  const project = await prisma.estimationProject.findUnique({
    where: { id },
    include: {
      items: {
        orderBy: { sortOrder: "asc" },
        select: {
          id: true,
          sortOrder: true,
          quantity: true,
          unitCost: true,
          materialCost: true,
          description: true,
          material: { select: { code: true, name: true, unit: true } },
          materialVariant: {
            select: { color: { select: { name: true, hexCode: true } } },
          },
        },
      },
    },
  });

  if (!project) return null;

  const subtotal = project.items.reduce(
    (sum, item) => sum + item.materialCost,
    0
  );

  const summary = calculateSummary(
    subtotal,
    project.profitMarginPercent,
    project.laborCost,
    project.additionalCost,
    project.discountPercent
  );

  return { ...project, summary };
}
