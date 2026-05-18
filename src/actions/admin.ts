/**
 * src/actions/admin.ts
 * ─────────────────────────────────────────────────────────────
 * Server Actions — Admin / Master Data Management
 *
 * createMaterial(payload) → creates a Material + its color
 *   variants in a single atomic transaction.
 *
 * updateMaterial(id, payload) → updates material fields
 * deleteMaterial(id) → soft-deletes by setting isActive=false
 * ─────────────────────────────────────────────────────────────
 */

"use server";

import prisma from "@/lib/prisma";
import { revalidatePath } from "next/cache";

// ─── Input Types ───────────────────────────────────────────────

export type MaterialVariantInput = {
  colorId: string;
  unitCost: number;
  sku?: string;
};

export type CreateMaterialPayload = {
  categoryId: string;
  code: string;
  name: string;
  unit: string;
  baseCost?: number;
  description?: string;
  sortOrder?: number;
  variants: MaterialVariantInput[]; // one per color
};

export type AdminActionResult =
  | { success: true; id: string }
  | { success: false; error: string };

// ─── Create ────────────────────────────────────────────────────

/**
 * Create a new Material with color-variant prices in one transaction.
 * Returns the new material's id on success.
 */
export async function createMaterial(
  payload: CreateMaterialPayload
): Promise<AdminActionResult> {
  try {
    // ── Validate ──────────────────────────────────────────────
    if (!payload.categoryId) return { success: false, error: "Category is required." };
    if (!payload.code?.trim()) return { success: false, error: "Material code is required." };
    if (!payload.name?.trim()) return { success: false, error: "Material name is required." };
    if (!payload.unit?.trim()) return { success: false, error: "Unit is required." };

    if (!payload.variants || payload.variants.length === 0) {
      return { success: false, error: "At least one color variant with a price is required." };
    }

    for (const v of payload.variants) {
      if (!v.colorId) return { success: false, error: "Each variant must have a color selected." };
      if (v.unitCost < 0) return { success: false, error: "Unit cost cannot be negative." };
    }

    // ── Duplicate code check ──────────────────────────────────
    const existing = await prisma.material.findUnique({
      where: { code: payload.code.trim() },
      select: { id: true },
    });
    if (existing) {
      return { success: false, error: `Material code "${payload.code}" already exists.` };
    }

    // ── Atomic transaction: Material + Variants ───────────────
    const material = await prisma.$transaction(async (tx) => {
      const mat = await tx.material.create({
        data: {
          categoryId: payload.categoryId,
          code: payload.code.trim(),
          name: payload.name.trim(),
          unit: payload.unit.trim(),
          baseCost: payload.baseCost ?? 0,
          description: payload.description?.trim() ?? null,
          sortOrder: payload.sortOrder ?? 0,
        },
      });

      await tx.materialVariant.createMany({
        data: payload.variants.map((v) => ({
          materialId: mat.id,
          colorId: v.colorId,
          unitCost: v.unitCost,
          sku: v.sku?.trim() ?? null,
        })),
      });

      return mat;
    });

    // ── Invalidate cached routes ──────────────────────────────
    revalidatePath("/materials");
    revalidatePath("/");

    return { success: true, id: material.id };
  } catch (err) {
    console.error("[createMaterial] Error:", err);
    return { success: false, error: "An unexpected server error occurred. Please try again." };
  }
}

// ─── Update ────────────────────────────────────────────────────

export type UpdateMaterialPayload = {
  id: string;
  name: string;
  code: string;
  variants: {
    id: string;
    unitCost: number;
  }[];
};

/**
 * Update an existing Material and its color-variant prices.
 */
export async function updateMaterial(
  payload: UpdateMaterialPayload
): Promise<AdminActionResult> {
  try {
    if (!payload.id) return { success: false, error: "Material ID is required." };
    if (!payload.name?.trim()) return { success: false, error: "Material name is required." };
    if (!payload.code?.trim()) return { success: false, error: "Material code is required." };

    // Check for duplicate code if code was changed
    const existing = await prisma.material.findUnique({
      where: { code: payload.code.trim() },
      select: { id: true },
    });
    if (existing && existing.id !== payload.id) {
      return { success: false, error: `Material code "${payload.code}" is already in use by another material.` };
    }

    await prisma.$transaction(async (tx) => {
      // Update base material
      await tx.material.update({
        where: { id: payload.id },
        data: {
          name: payload.name.trim(),
          code: payload.code.trim(),
        },
      });

      // Update variants
      for (const v of payload.variants) {
        if (v.unitCost < 0) throw new Error("Unit cost cannot be negative.");
        await tx.materialVariant.update({
          where: { id: v.id },
          data: { unitCost: v.unitCost },
        });
      }
    });

    revalidatePath("/materials");
    revalidatePath("/");

    return { success: true, id: payload.id };
  } catch (err) {
    console.error("[updateMaterial] Error:", err);
    if (err instanceof Error) {
       return { success: false, error: err.message };
    }
    return { success: false, error: "Failed to update material." };
  }
}

/**
 * Delete a material from the database.
 * If the material is referenced by existing templates or projects, it will be soft-deleted (isActive = false) instead.
 */
export async function deleteMaterial(id: string): Promise<AdminActionResult> {
  try {
    // Attempt to hard-delete the material
    await prisma.material.delete({
      where: { id },
    });

    revalidatePath("/materials");
    return { success: true, id };
  } catch (err: any) {
    // P2003: Foreign key constraint failed. This means the material is used in a template or quotation.
    if (err.code === "P2003") {
      try {
        await prisma.material.update({
          where: { id },
          data: { isActive: false },
        });
        revalidatePath("/materials");
        // Still return success so the UI updates
        return { success: true, id };
      } catch (softErr) {
        console.error("[deleteMaterial] Soft Delete Error:", softErr);
        return { success: false, error: "Failed to deactivate material." };
      }
    }
    
    console.error("[deleteMaterial] Error:", err);
    return { success: false, error: "Failed to delete material." };
  }
}
