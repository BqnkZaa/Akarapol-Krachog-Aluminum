/*
  Warnings:

  - You are about to drop the column `areaSqM` on the `estimation_items` table. All the data in the column will be lost.
  - You are about to drop the column `heightMm` on the `estimation_items` table. All the data in the column will be lost.
  - You are about to drop the column `widthMm` on the `estimation_items` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "estimation_projects" ADD COLUMN "refHeightMm" REAL;
ALTER TABLE "estimation_projects" ADD COLUMN "refWidthMm" REAL;

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_estimation_items" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "estimationProjectId" TEXT NOT NULL,
    "materialId" TEXT NOT NULL,
    "materialVariantId" TEXT,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "description" TEXT,
    "unitCost" REAL NOT NULL DEFAULT 0,
    "materialCost" REAL NOT NULL DEFAULT 0,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "estimation_items_estimationProjectId_fkey" FOREIGN KEY ("estimationProjectId") REFERENCES "estimation_projects" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "estimation_items_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "estimation_items_materialVariantId_fkey" FOREIGN KEY ("materialVariantId") REFERENCES "material_variants" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
INSERT INTO "new_estimation_items" ("createdAt", "description", "estimationProjectId", "id", "materialCost", "materialId", "materialVariantId", "quantity", "sortOrder", "unitCost", "updatedAt") SELECT "createdAt", "description", "estimationProjectId", "id", "materialCost", "materialId", "materialVariantId", "quantity", "sortOrder", "unitCost", "updatedAt" FROM "estimation_items";
DROP TABLE "estimation_items";
ALTER TABLE "new_estimation_items" RENAME TO "estimation_items";
CREATE INDEX "estimation_items_estimationProjectId_idx" ON "estimation_items"("estimationProjectId");
CREATE INDEX "estimation_items_materialId_idx" ON "estimation_items"("materialId");
CREATE INDEX "estimation_items_materialVariantId_idx" ON "estimation_items"("materialVariantId");
CREATE TABLE "new_materials" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "categoryId" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "unit" TEXT NOT NULL DEFAULT 'piece',
    "baseCost" REAL NOT NULL DEFAULT 0,
    "description" TEXT,
    "imageUrl" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "materials_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "categories" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);
INSERT INTO "new_materials" ("baseCost", "categoryId", "code", "createdAt", "description", "id", "imageUrl", "isActive", "name", "sortOrder", "unit", "updatedAt") SELECT "baseCost", "categoryId", "code", "createdAt", "description", "id", "imageUrl", "isActive", "name", "sortOrder", "unit", "updatedAt" FROM "materials";
DROP TABLE "materials";
ALTER TABLE "new_materials" RENAME TO "materials";
CREATE UNIQUE INDEX "materials_code_key" ON "materials"("code");
CREATE INDEX "materials_categoryId_idx" ON "materials"("categoryId");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
