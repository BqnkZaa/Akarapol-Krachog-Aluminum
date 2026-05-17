/**
 * src/actions/category.ts
 * ─────────────────────────────────────────────────────────────
 * Server Actions — Category (Series) Management
 *
 * createCategory(payload)  → creates a new Category (series)
 * updateCategory(id, payload) → updates name, slug, description, etc.
 * deleteCategory(id) → deletes IF no materials or templates reference it
 * getCategoryById(id) → fetch single category for edit form
 * ─────────────────────────────────────────────────────────────
 */

"use server";

import prisma from "@/lib/prisma";
import { revalidatePath } from "next/cache";

// ─── Input Types ───────────────────────────────────────────────

export type CategoryPayload = {
  name: string;
  slug: string;
  description?: string;
  imageUrl?: string;
  sortOrder?: number;
  isActive?: boolean;
};

export type CategoryActionResult =
  | { success: true; id: string }
  | { success: false; error: string };

// ─── Helpers ───────────────────────────────────────────────────

/** Generate a URL-safe slug from a name string */
function generateSlug(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")   // remove non-word chars (except spaces and hyphens)
    .replace(/[\s_]+/g, "-")    // replace spaces and underscores with hyphens
    .replace(/-+/g, "-")        // collapse multiple hyphens
    .replace(/^-+|-+$/g, "");   // trim leading/trailing hyphens
}

// ─── Read ──────────────────────────────────────────────────────

export type CategoryDTO = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  imageUrl: string | null;
  sortOrder: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
  _count: {
    materials: number;
    templates: number;
  };
};

/**
 * Fetch all categories with counts — for the list page.
 */
export async function getCategories(): Promise<CategoryDTO[]> {
  const cats = await prisma.category.findMany({
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: {
      _count: {
        select: { materials: true, templates: true },
      },
    },
  });

  return cats.map((c) => ({
    id: c.id,
    name: c.name,
    slug: c.slug,
    description: c.description,
    imageUrl: c.imageUrl,
    sortOrder: c.sortOrder,
    isActive: c.isActive,
    createdAt: c.createdAt,
    updatedAt: c.updatedAt,
    _count: c._count,
  }));
}

/**
 * Fetch a single category by ID — for the edit form.
 */
export async function getCategoryById(id: string): Promise<CategoryDTO | null> {
  const c = await prisma.category.findUnique({
    where: { id },
    include: {
      _count: {
        select: { materials: true, templates: true },
      },
    },
  });

  if (!c) return null;

  return {
    id: c.id,
    name: c.name,
    slug: c.slug,
    description: c.description,
    imageUrl: c.imageUrl,
    sortOrder: c.sortOrder,
    isActive: c.isActive,
    createdAt: c.createdAt,
    updatedAt: c.updatedAt,
    _count: c._count,
  };
}

// ─── Create ────────────────────────────────────────────────────

/**
 * Create a new Category (Series).
 * Auto-generates slug from name if not provided.
 */
export async function createCategory(
  payload: CategoryPayload
): Promise<CategoryActionResult> {
  try {
    // ── Validate ──────────────────────────────────────────────
    if (!payload.name?.trim()) {
      return { success: false, error: "Series name is required." };
    }

    const slug = payload.slug?.trim() || generateSlug(payload.name);

    if (!slug) {
      return { success: false, error: "Could not generate a valid slug. Please provide one manually." };
    }

    // ── Duplicate checks ──────────────────────────────────────
    const existingName = await prisma.category.findUnique({
      where: { name: payload.name.trim() },
      select: { id: true },
    });
    if (existingName) {
      return { success: false, error: `A series named "${payload.name.trim()}" already exists.` };
    }

    const existingSlug = await prisma.category.findUnique({
      where: { slug },
      select: { id: true },
    });
    if (existingSlug) {
      return { success: false, error: `The slug "${slug}" is already in use. Please choose a different slug.` };
    }

    // ── Create ────────────────────────────────────────────────
    const category = await prisma.category.create({
      data: {
        name: payload.name.trim(),
        slug,
        description: payload.description?.trim() || null,
        imageUrl: payload.imageUrl?.trim() || null,
        sortOrder: payload.sortOrder ?? 0,
        isActive: payload.isActive ?? true,
      },
    });

    // ── Invalidate cached routes ──────────────────────────────
    revalidatePath("/admin/categories");
    revalidatePath("/materials");
    revalidatePath("/materials/new");
    revalidatePath("/");

    return { success: true, id: category.id };
  } catch (err) {
    console.error("[createCategory] Error:", err);
    return { success: false, error: "An unexpected server error occurred. Please try again." };
  }
}

// ─── Update ────────────────────────────────────────────────────

/**
 * Update an existing Category (Series).
 */
export async function updateCategory(
  id: string,
  payload: CategoryPayload
): Promise<CategoryActionResult> {
  try {
    // ── Validate ──────────────────────────────────────────────
    if (!id) return { success: false, error: "Category ID is required." };
    if (!payload.name?.trim()) {
      return { success: false, error: "Series name is required." };
    }

    const slug = payload.slug?.trim() || generateSlug(payload.name);

    if (!slug) {
      return { success: false, error: "Could not generate a valid slug." };
    }

    // ── Check category exists ─────────────────────────────────
    const existing = await prisma.category.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!existing) {
      return { success: false, error: "Category not found." };
    }

    // ── Duplicate checks (exclude self) ───────────────────────
    const duplicateName = await prisma.category.findFirst({
      where: { name: payload.name.trim(), id: { not: id } },
      select: { id: true },
    });
    if (duplicateName) {
      return { success: false, error: `A series named "${payload.name.trim()}" already exists.` };
    }

    const duplicateSlug = await prisma.category.findFirst({
      where: { slug, id: { not: id } },
      select: { id: true },
    });
    if (duplicateSlug) {
      return { success: false, error: `The slug "${slug}" is already in use.` };
    }

    // ── Update ────────────────────────────────────────────────
    await prisma.category.update({
      where: { id },
      data: {
        name: payload.name.trim(),
        slug,
        description: payload.description?.trim() || null,
        imageUrl: payload.imageUrl?.trim() || null,
        sortOrder: payload.sortOrder ?? 0,
        isActive: payload.isActive ?? true,
      },
    });

    // ── Invalidate cached routes ──────────────────────────────
    revalidatePath("/admin/categories");
    revalidatePath("/materials");
    revalidatePath("/materials/new");
    revalidatePath("/");

    return { success: true, id };
  } catch (err) {
    console.error("[updateCategory] Error:", err);
    return { success: false, error: "An unexpected server error occurred. Please try again." };
  }
}

// ─── Delete ────────────────────────────────────────────────────

/**
 * Delete a category permanently.
 * Blocks deletion if materials or templates still reference it.
 */
export async function deleteCategory(
  id: string
): Promise<CategoryActionResult> {
  try {
    if (!id) return { success: false, error: "Category ID is required." };

    // ── Check for related records ─────────────────────────────
    const category = await prisma.category.findUnique({
      where: { id },
      include: {
        _count: {
          select: { materials: true, templates: true },
        },
      },
    });

    if (!category) {
      return { success: false, error: "Category not found." };
    }

    if (category._count.materials > 0) {
      return {
        success: false,
        error: `Cannot delete "${category.name}" — it still has ${category._count.materials} material(s). Remove or reassign them first.`,
      };
    }

    if (category._count.templates > 0) {
      return {
        success: false,
        error: `Cannot delete "${category.name}" — it still has ${category._count.templates} template(s). Remove or reassign them first.`,
      };
    }

    // ── Safe to delete ────────────────────────────────────────
    await prisma.category.delete({ where: { id } });

    // ── Invalidate cached routes ──────────────────────────────
    revalidatePath("/admin/categories");
    revalidatePath("/materials");
    revalidatePath("/materials/new");
    revalidatePath("/");

    return { success: true, id };
  } catch (err) {
    console.error("[deleteCategory] Error:", err);
    return { success: false, error: "Failed to delete category. It may still have dependent records." };
  }
}
