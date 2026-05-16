/**
 * src/actions/material.ts
 * ─────────────────────────────────────────────────────────────
 * Server Actions — Master Data Fetching
 *
 * getColors()                  → all active colors
 * getCategoriesWithMaterials() → categories + materials + variants
 * getMaterialVariant()         → single variant lookup by id
 * ─────────────────────────────────────────────────────────────
 */

"use server";

import prisma from "@/lib/prisma";

// ─── Types (exported so the UI can use them for type safety) ───

export type ColorDTO = {
  id: string;
  name: string;
  hexCode: string | null;
  sortOrder: number;
};

export type MaterialVariantDTO = {
  id: string;
  colorId: string;
  colorName: string;
  unitCost: number;
  sku: string | null;
};

export type MaterialDTO = {
  id: string;
  code: string;
  name: string;
  unit: string;
  baseCost: number;
  sortOrder: number;
  variants: MaterialVariantDTO[];
};

export type CategoryWithMaterialsDTO = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  sortOrder: number;
  materials: MaterialDTO[];
};

// ─── Actions ───────────────────────────────────────────────────

/**
 * Fetch all active colors, ordered for display.
 * Used to populate the color selector step in the wizard.
 */
export async function getColors(): Promise<ColorDTO[]> {
  const colors = await prisma.color.findMany({
    where: { isActive: true },
    orderBy: { sortOrder: "asc" },
    select: {
      id: true,
      name: true,
      hexCode: true,
      sortOrder: true,
    },
  });

  return colors;
}

/**
 * Fetch all active categories with their materials and color variants.
 * Used to populate the brand → material selector steps.
 *
 * Shape: Category[] → Material[] → MaterialVariant[] (with color info)
 */
export async function getCategoriesWithMaterials(): Promise<
  CategoryWithMaterialsDTO[]
> {
  const categories = await prisma.category.findMany({
    where: { isActive: true },
    orderBy: { sortOrder: "asc" },
    select: {
      id: true,
      name: true,
      slug: true,
      description: true,
      sortOrder: true,
      materials: {
        where: { isActive: true },
        orderBy: { sortOrder: "asc" },
        select: {
          id: true,
          code: true,
          name: true,
          unit: true,
          baseCost: true,
          sortOrder: true,
          variants: {
            where: { isActive: true },
            select: {
              id: true,
              colorId: true,
              unitCost: true,
              sku: true,
              color: {
                select: { name: true },
              },
            },
          },
        },
      },
    },
  });

  // Flatten the nested color name into variants for easier UI consumption
  return categories.map((cat) => ({
    ...cat,
    materials: cat.materials.map((mat) => ({
      ...mat,
      variants: mat.variants.map((v) => ({
        id: v.id,
        colorId: v.colorId,
        colorName: v.color.name,
        unitCost: v.unitCost,
        sku: v.sku,
      })),
    })),
  }));
}

/**
 * Look up a single MaterialVariant by id.
 * Useful for server-side price verification before saving.
 */
export async function getMaterialVariantById(variantId: string): Promise<{
  id: string;
  unitCost: number;
  materialId: string;
} | null> {
  return prisma.materialVariant.findUnique({
    where: { id: variantId },
    select: { id: true, unitCost: true, materialId: true },
  });
}
