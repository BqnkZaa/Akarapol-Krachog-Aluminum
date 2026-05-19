/**
 * src/actions/template.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Server Actions — ProductTemplate (Work Type) Management
 *
 * CREATE / READ / UPDATE / DELETE operations for the full template graph:
 *   ProductTemplate
 *     ├─ TemplateComponent[]   (aluminum profile formulas)
 *     ├─ GlassSpecification?   (optional glass area calculation)
 *     └─ TemplateAccessory[]   (fixed-cost accessories)
 *
 * All write operations use Prisma $transaction to ensure atomicity.
 * Formula strings are validated at write time using the Formula Parser Engine.
 * ─────────────────────────────────────────────────────────────────────────────
 */

"use server";

import prisma from "@/lib/prisma";
import { revalidatePath } from "next/cache";
import { validateFormula } from "@/lib/formulaParser";

// ═══════════════════════════════════════════════════════════════════════════════
// INPUT DTOs
// ═══════════════════════════════════════════════════════════════════════════════

/** A single aluminum profile component within the template */
export type TemplateComponentInput = {
  materialId: string;
  label: string;
  formula: string;        // e.g. "H - 35", "W / 2 + 10"
  quantity: number;       // how many identical cuts
  barLengthMm?: number;   // per-component override (null → use template default)
  sortOrder: number;
};

/** Glass specification — optional, one per template */
export type GlassSpecInput = {
  widthFormula: string;    // e.g. "W / 2 - 30"
  heightFormula: string;   // e.g. "H - 80"
  panelCount: number;
  glassType: string;       // e.g. "6mm Clear Tempered"
  pricePerSqM: number;    // THB per m²
};

/** A fixed-cost accessory item */
export type TemplateAccessoryInput = {
  name: string;            // e.g. "ชุดล้อบานเลื่อน (Roller Set)"
  quantity: number;
  unitCost: number;        // THB per piece
  unit: string;            // "ชุด", "อัน", "เมตร"
  sortOrder: number;
};

/** Full payload for creating or updating a ProductTemplate */
export type TemplatePayload = {
  // ─── Template header ─────────────────────────────────────────
  categoryId: string;
  name: string;
  slug: string;
  description?: string;
  imageUrl?: string;
  standardBarLengthMm: number;   // e.g. 6000
  kerfMm: number;                // e.g. 5
  sortOrder?: number;
  isActive?: boolean;

  // ─── Child entities ──────────────────────────────────────────
  components: TemplateComponentInput[];
  glass?: GlassSpecInput | null;  // null = no glass spec
  accessories: TemplateAccessoryInput[];
};

/** Standard action result */
export type TemplateActionResult =
  | { success: true; id: string }
  | { success: false; error: string };

// ═══════════════════════════════════════════════════════════════════════════════
// READ DTOs
// ═══════════════════════════════════════════════════════════════════════════════

/** Lean DTO for the admin list page */
export type TemplateListItem = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  imageUrl: string | null;
  standardBarLengthMm: number;
  kerfMm: number;
  sortOrder: number;
  isActive: boolean;
  categoryId: string;
  categoryName: string;
  componentCount: number;
  accessoryCount: number;
  hasGlass: boolean;
  projectCount: number;      // how many estimation projects reference this
  createdAt: Date;
  updatedAt: Date;
};

/** Full DTO for the edit form — includes all child arrays */
export type TemplateDetail = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  imageUrl: string | null;
  standardBarLengthMm: number;
  kerfMm: number;
  sortOrder: number;
  isActive: boolean;
  categoryId: string;
  categoryName: string;

  components: {
    id: string;
    materialId: string;
    materialCode: string;
    materialName: string;
    label: string;
    formula: string;
    quantity: number;
    barLengthMm: number | null;
    sortOrder: number;
  }[];

  glass: {
    id: string;
    widthFormula: string;
    heightFormula: string;
    panelCount: number;
    glassType: string;
    pricePerSqM: number;
  } | null;

  accessories: {
    id: string;
    name: string;
    quantity: number;
    unitCost: number;
    unit: string;
    sortOrder: number;
  }[];

  projectCount: number;
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/** Generate a URL-safe slug from a name string */
function generateSlug(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/** Revalidate all paths that might display template data */
function revalidateTemplatePaths() {
  revalidatePath("/admin/templates");
  revalidatePath("/admin/categories");
  revalidatePath("/dashboard");
  revalidatePath("/");
}

// ═══════════════════════════════════════════════════════════════════════════════
// VALIDATION
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Comprehensive server-side validation for the TemplatePayload.
 * Returns null if valid, or an error string describing the first problem found.
 */
function validatePayload(payload: TemplatePayload): string | null {
  // ── Header validations ──────────────────────────────────────
  if (!payload.categoryId) return "Category (Series) is required.";
  if (!payload.name?.trim()) return "Template name is required.";

  const slug = payload.slug?.trim() || generateSlug(payload.name);
  if (!slug) return "Could not generate a valid slug.";

  if (!payload.standardBarLengthMm || payload.standardBarLengthMm <= 0) {
    return "Standard bar length must be a positive number (mm).";
  }
  if (payload.kerfMm < 0) return "Kerf width cannot be negative.";

  // ── Component validations ───────────────────────────────────
  if (!payload.components || payload.components.length === 0) {
    return "At least one profile component is required.";
  }

  for (let i = 0; i < payload.components.length; i++) {
    const comp = payload.components[i];
    const prefix = `Component #${i + 1}`;

    if (!comp.materialId) return `${prefix}: Material selection is required.`;
    if (!comp.label?.trim()) return `${prefix}: Label is required.`;
    if (!comp.formula?.trim()) return `${prefix}: Formula is required.`;
    if (comp.quantity < 1) return `${prefix}: Quantity must be at least 1.`;

    // Validate the formula using the secure parser
    const formulaCheck = validateFormula(comp.formula.trim());
    if (!formulaCheck.valid) {
      return `${prefix} ("${comp.label}"): Formula error — ${formulaCheck.error}`;
    }

    // If a per-component bar length override is set, it must be positive
    if (comp.barLengthMm !== undefined && comp.barLengthMm !== null && comp.barLengthMm <= 0) {
      return `${prefix} ("${comp.label}"): Bar length override must be positive.`;
    }
  }

  // ── Glass specification validations ─────────────────────────
  if (payload.glass) {
    const g = payload.glass;

    if (!g.widthFormula?.trim()) return "Glass: Width formula is required.";
    if (!g.heightFormula?.trim()) return "Glass: Height formula is required.";
    if (g.panelCount < 1) return "Glass: Panel count must be at least 1.";
    if (!g.glassType?.trim()) return "Glass: Glass type label is required.";
    if (g.pricePerSqM < 0) return "Glass: Price per m² cannot be negative.";

    const wCheck = validateFormula(g.widthFormula.trim());
    if (!wCheck.valid) return `Glass width formula error: ${wCheck.error}`;

    const hCheck = validateFormula(g.heightFormula.trim());
    if (!hCheck.valid) return `Glass height formula error: ${hCheck.error}`;
  }

  // ── Accessory validations ───────────────────────────────────
  for (let i = 0; i < payload.accessories.length; i++) {
    const acc = payload.accessories[i];
    const prefix = `Accessory #${i + 1}`;

    if (!acc.name?.trim()) return `${prefix}: Name is required.`;
    if (acc.quantity < 1) return `${prefix}: Quantity must be at least 1.`;
    if (acc.unitCost < 0) return `${prefix}: Unit cost cannot be negative.`;
    if (!acc.unit?.trim()) return `${prefix}: Unit label is required.`;
  }

  return null; // all good
}

// ═══════════════════════════════════════════════════════════════════════════════
// READ ACTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Fetch all templates for the admin list page.
 * Includes category name and child counts.
 */
export async function getTemplatesForAdmin(): Promise<TemplateListItem[]> {
  const templates = await prisma.productTemplate.findMany({
    orderBy: [{ category: { sortOrder: "asc" } }, { sortOrder: "asc" }, { name: "asc" }],
    include: {
      category: { select: { name: true } },
      glass: { select: { id: true } },
      _count: {
        select: {
          components: true,
          accessories: true,
          projects: true,
        },
      },
    },
  });

  return templates.map((t) => ({
    id: t.id,
    name: t.name,
    slug: t.slug,
    description: t.description,
    imageUrl: t.imageUrl,
    standardBarLengthMm: t.standardBarLengthMm,
    kerfMm: t.kerfMm,
    sortOrder: t.sortOrder,
    isActive: t.isActive,
    categoryId: t.categoryId,
    categoryName: t.category.name,
    componentCount: t._count.components,
    accessoryCount: t._count.accessories,
    hasGlass: t.glass !== null,
    projectCount: t._count.projects,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  }));
}

/**
 * Fetch a single template with all child entities for the edit form.
 */
export async function getTemplateById(id: string): Promise<TemplateDetail | null> {
  const t = await prisma.productTemplate.findUnique({
    where: { id },
    include: {
      category: { select: { name: true } },
      components: {
        orderBy: { sortOrder: "asc" },
        include: {
          material: { select: { code: true, name: true } },
        },
      },
      glass: true,
      accessories: { orderBy: { sortOrder: "asc" } },
      _count: { select: { projects: true } },
    },
  });

  if (!t) return null;

  return {
    id: t.id,
    name: t.name,
    slug: t.slug,
    description: t.description,
    imageUrl: t.imageUrl,
    standardBarLengthMm: t.standardBarLengthMm,
    kerfMm: t.kerfMm,
    sortOrder: t.sortOrder,
    isActive: t.isActive,
    categoryId: t.categoryId,
    categoryName: t.category.name,

    components: t.components.map((c) => ({
      id: c.id,
      materialId: c.materialId,
      materialCode: c.material.code,
      materialName: c.material.name,
      label: c.label,
      formula: c.formula,
      quantity: c.quantity,
      barLengthMm: c.barLengthMm,
      sortOrder: c.sortOrder,
    })),

    glass: t.glass
      ? {
          id: t.glass.id,
          widthFormula: t.glass.widthFormula,
          heightFormula: t.glass.heightFormula,
          panelCount: t.glass.panelCount,
          glassType: t.glass.glassType,
          pricePerSqM: t.glass.pricePerSqM,
        }
      : null,

    accessories: t.accessories.map((a) => ({
      id: a.id,
      name: a.name,
      quantity: a.quantity,
      unitCost: a.unitCost,
      unit: a.unit,
      sortOrder: a.sortOrder,
    })),

    projectCount: t._count.projects,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATE
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Atomically create a ProductTemplate with all its children:
 *   TemplateComponent[]
 *   GlassSpecification?
 *   TemplateAccessory[]
 *
 * All formula strings are validated by the secure parser before persistence.
 */
export async function createTemplate(
  payload: TemplatePayload
): Promise<TemplateActionResult> {
  try {
    // ── Validate ──────────────────────────────────────────────
    const validationError = validatePayload(payload);
    if (validationError) {
      return { success: false, error: validationError };
    }

    const slug = payload.slug?.trim() || generateSlug(payload.name);

    // ── Duplicate checks ──────────────────────────────────────
    const existingName = await prisma.productTemplate.findUnique({
      where: { name: payload.name.trim() },
      select: { id: true },
    });
    if (existingName) {
      return { success: false, error: `A template named "${payload.name.trim()}" already exists.` };
    }

    const existingSlug = await prisma.productTemplate.findUnique({
      where: { slug },
      select: { id: true },
    });
    if (existingSlug) {
      return { success: false, error: `The slug "${slug}" is already in use.` };
    }

    // ── Verify category exists ────────────────────────────────
    const category = await prisma.category.findUnique({
      where: { id: payload.categoryId, isActive: true },
      select: { id: true },
    });
    if (!category) {
      return { success: false, error: "Selected category (series) not found or is inactive." };
    }

    // ── Verify all referenced materials exist ─────────────────
    const materialIds = [...new Set(payload.components.map((c) => c.materialId))];
    const existingMaterials = await prisma.material.findMany({
      where: { id: { in: materialIds }, isActive: true },
      select: { id: true },
    });
    const existingMaterialSet = new Set(existingMaterials.map((m) => m.id));

    for (const comp of payload.components) {
      if (!existingMaterialSet.has(comp.materialId)) {
        return {
          success: false,
          error: `Component "${comp.label}": Referenced material not found or is inactive. Please select an active material.`,
        };
      }
    }

    // ── Atomic write ──────────────────────────────────────────
    const template = await prisma.$transaction(async (tx) => {
      // 1. Create the ProductTemplate
      const tpl = await tx.productTemplate.create({
        data: {
          categoryId: payload.categoryId,
          name: payload.name.trim(),
          slug,
          description: payload.description?.trim() || null,
          imageUrl: payload.imageUrl?.trim() || null,
          standardBarLengthMm: payload.standardBarLengthMm,
          kerfMm: payload.kerfMm,
          sortOrder: payload.sortOrder ?? 0,
          isActive: payload.isActive ?? true,
        },
      });

      // 2. Create TemplateComponent[] in bulk
      await tx.templateComponent.createMany({
        data: payload.components.map((c) => ({
          templateId: tpl.id,
          materialId: c.materialId,
          label: c.label.trim(),
          formula: c.formula.trim(),
          quantity: c.quantity,
          barLengthMm: c.barLengthMm ?? null,
          sortOrder: c.sortOrder,
        })),
      });

      // 3. Create GlassSpecification (optional)
      if (payload.glass) {
        await tx.glassSpecification.create({
          data: {
            templateId: tpl.id,
            widthFormula: payload.glass.widthFormula.trim(),
            heightFormula: payload.glass.heightFormula.trim(),
            panelCount: payload.glass.panelCount,
            glassType: payload.glass.glassType.trim(),
            pricePerSqM: payload.glass.pricePerSqM,
          },
        });
      }

      // 4. Create TemplateAccessory[] in bulk
      if (payload.accessories.length > 0) {
        await tx.templateAccessory.createMany({
          data: payload.accessories.map((a) => ({
            templateId: tpl.id,
            name: a.name.trim(),
            quantity: a.quantity,
            unitCost: a.unitCost,
            unit: a.unit.trim(),
            sortOrder: a.sortOrder,
          })),
        });
      }

      return tpl;
    });

    revalidateTemplatePaths();
    return { success: true, id: template.id };
  } catch (err) {
    console.error("[createTemplate] Error:", err);
    return { success: false, error: "An unexpected server error occurred. Please try again." };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Atomically update a ProductTemplate and all its children.
 *
 * Strategy: Delete all existing children → Re-create from the payload.
 * This is the safest approach for complex nested forms where rows can be
 * added, removed, and reordered arbitrarily. Prisma's onDelete: Cascade
 * on the child models means we only need to delete the template's children,
 * not the template itself.
 */
export async function updateTemplate(
  id: string,
  payload: TemplatePayload
): Promise<TemplateActionResult> {
  try {
    // ── Validate ──────────────────────────────────────────────
    if (!id) return { success: false, error: "Template ID is required." };

    const validationError = validatePayload(payload);
    if (validationError) {
      return { success: false, error: validationError };
    }

    const slug = payload.slug?.trim() || generateSlug(payload.name);

    // ── Check template exists ─────────────────────────────────
    const existing = await prisma.productTemplate.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!existing) {
      return { success: false, error: "Template not found." };
    }

    // ── Duplicate checks (exclude self) ───────────────────────
    const duplicateName = await prisma.productTemplate.findFirst({
      where: { name: payload.name.trim(), id: { not: id } },
      select: { id: true },
    });
    if (duplicateName) {
      return { success: false, error: `A template named "${payload.name.trim()}" already exists.` };
    }

    const duplicateSlug = await prisma.productTemplate.findFirst({
      where: { slug, id: { not: id } },
      select: { id: true },
    });
    if (duplicateSlug) {
      return { success: false, error: `The slug "${slug}" is already in use.` };
    }

    // ── Verify category exists ────────────────────────────────
    const category = await prisma.category.findUnique({
      where: { id: payload.categoryId, isActive: true },
      select: { id: true },
    });
    if (!category) {
      return { success: false, error: "Selected category (series) not found or is inactive." };
    }

    // ── Verify all referenced materials exist ─────────────────
    const materialIds = [...new Set(payload.components.map((c) => c.materialId))];
    const existingMaterials = await prisma.material.findMany({
      where: { id: { in: materialIds }, isActive: true },
      select: { id: true },
    });
    const existingMaterialSet = new Set(existingMaterials.map((m) => m.id));

    for (const comp of payload.components) {
      if (!existingMaterialSet.has(comp.materialId)) {
        return {
          success: false,
          error: `Component "${comp.label}": Referenced material not found or is inactive.`,
        };
      }
    }

    // ── Atomic: delete children → update header → re-create children ──
    await prisma.$transaction(async (tx) => {
      // 1. Delete all existing children (order matters to avoid FK issues)
      await tx.templateComponent.deleteMany({ where: { templateId: id } });
      await tx.glassSpecification.deleteMany({ where: { templateId: id } });
      await tx.templateAccessory.deleteMany({ where: { templateId: id } });

      // 2. Update the template header
      await tx.productTemplate.update({
        where: { id },
        data: {
          categoryId: payload.categoryId,
          name: payload.name.trim(),
          slug,
          description: payload.description?.trim() || null,
          imageUrl: payload.imageUrl?.trim() || null,
          standardBarLengthMm: payload.standardBarLengthMm,
          kerfMm: payload.kerfMm,
          sortOrder: payload.sortOrder ?? 0,
          isActive: payload.isActive ?? true,
        },
      });

      // 3. Re-create TemplateComponent[]
      await tx.templateComponent.createMany({
        data: payload.components.map((c) => ({
          templateId: id,
          materialId: c.materialId,
          label: c.label.trim(),
          formula: c.formula.trim(),
          quantity: c.quantity,
          barLengthMm: c.barLengthMm ?? null,
          sortOrder: c.sortOrder,
        })),
      });

      // 4. Re-create GlassSpecification (optional)
      if (payload.glass) {
        await tx.glassSpecification.create({
          data: {
            templateId: id,
            widthFormula: payload.glass.widthFormula.trim(),
            heightFormula: payload.glass.heightFormula.trim(),
            panelCount: payload.glass.panelCount,
            glassType: payload.glass.glassType.trim(),
            pricePerSqM: payload.glass.pricePerSqM,
          },
        });
      }

      // 5. Re-create TemplateAccessory[]
      if (payload.accessories.length > 0) {
        await tx.templateAccessory.createMany({
          data: payload.accessories.map((a) => ({
            templateId: id,
            name: a.name.trim(),
            quantity: a.quantity,
            unitCost: a.unitCost,
            unit: a.unit.trim(),
            sortOrder: a.sortOrder,
          })),
        });
      }
    });

    revalidateTemplatePaths();
    return { success: true, id };
  } catch (err) {
    console.error("[updateTemplate] Error:", err);
    return { success: false, error: "An unexpected server error occurred. Please try again." };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DELETE
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Delete a ProductTemplate.
 *
 * Safety: Blocks deletion if any EstimationProject references this template.
 * The user must delete or reassign those quotations first.
 *
 * If no projects reference it, a hard-delete is performed (cascading to
 * components, glass spec, and accessories via the Prisma schema).
 */
export async function deleteTemplate(
  id: string
): Promise<TemplateActionResult> {
  try {
    if (!id) return { success: false, error: "Template ID is required." };

    // ── Check for related estimation projects ─────────────────
    const template = await prisma.productTemplate.findUnique({
      where: { id },
      select: {
        name: true,
        _count: { select: { projects: true } },
      },
    });

    if (!template) {
      return { success: false, error: "Template not found." };
    }

    if (template._count.projects > 0) {
      return {
        success: false,
        error:
          `Cannot delete "${template.name}" — it is referenced by ` +
          `${template._count.projects} quotation(s). Delete or reassign them first.`,
      };
    }

    // ── Safe to delete — cascade will clean up children ───────
    await prisma.productTemplate.delete({ where: { id } });

    revalidateTemplatePaths();
    return { success: true, id };
  } catch (err) {
    console.error("[deleteTemplate] Error:", err);
    return { success: false, error: "Failed to delete template." };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REFERENCE DATA (for the template form dropdowns)
// ═══════════════════════════════════════════════════════════════════════════════

/** Minimal material option for the component material dropdown */
export type MaterialOption = {
  id: string;
  code: string;
  name: string;
  categoryId: string;
  categoryName: string;
};

/**
 * Fetch all active materials for the component material dropdown.
 * Grouped by category for a better UX.
 */
export async function getMaterialsForDropdown(): Promise<MaterialOption[]> {
  const materials = await prisma.material.findMany({
    where: { isActive: true },
    orderBy: [{ category: { name: "asc" } }, { sortOrder: "asc" }, { code: "asc" }],
    select: {
      id: true,
      code: true,
      name: true,
      categoryId: true,
      category: { select: { name: true } },
    },
  });

  return materials.map((m) => ({
    id: m.id,
    code: m.code,
    name: m.name,
    categoryId: m.categoryId,
    categoryName: m.category.name,
  }));
}

/** Minimal category option for the template category dropdown */
export type CategoryOption = {
  id: string;
  name: string;
};

/**
 * Fetch all active categories for the template's category dropdown.
 */
export async function getCategoriesForDropdown(): Promise<CategoryOption[]> {
  const cats = await prisma.category.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    select: { id: true, name: true },
  });
  return cats;
}

/** Minimal accessory option for the template accessories dropdown */
export type AccessoryOption = {
  id: string;
  code: string;
  name: string;
  unit: string;
  baseCost: number;
};

/**
 * Fetch all active accessories for the template accessories dropdown.
 */
export async function getAccessoriesForDropdown(): Promise<AccessoryOption[]> {
  const accs = await prisma.accessory.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    select: { id: true, code: true, name: true, unit: true, baseCost: true },
  });
  return accs;
}

/** Minimal glass option for the template glass section dropdown */
export type GlassOption = {
  id: string;
  name: string;
  thicknessMm: number | null;
  pricePerSqM: number;
};

/**
 * Fetch all active glass types for the template glass section dropdown.
 */
export async function getGlassesForDropdown(): Promise<GlassOption[]> {
  const glasses = await prisma.glass.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    select: { id: true, name: true, thicknessMm: true, pricePerSqM: true },
  });
  return glasses;
}
