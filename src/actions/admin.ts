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

// ─── Delete (soft) ─────────────────────────────────────────────

/**
 * Soft-delete a material by setting isActive = false.
 * Preserves historical references in saved EstimationItems.
 */
export async function deleteMaterial(id: string): Promise<AdminActionResult> {
  try {
    await prisma.material.update({
      where: { id },
      data: { isActive: false },
    });

    revalidatePath("/materials");
    return { success: true, id };
  } catch (err) {
    console.error("[deleteMaterial] Error:", err);
    return { success: false, error: "Failed to delete material." };
  }
}
