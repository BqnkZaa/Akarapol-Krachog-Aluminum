-- CreateTable
CREATE TABLE "categories" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "description" TEXT,
    "imageUrl" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "materials" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "categoryId" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "unit" TEXT NOT NULL DEFAULT 'sq.m',
    "baseCost" REAL NOT NULL DEFAULT 0,
    "description" TEXT,
    "imageUrl" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "materials_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "categories" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "material_variants" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "materialId" TEXT NOT NULL,
    "colorId" TEXT NOT NULL,
    "unitCost" REAL NOT NULL,
    "sku" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "material_variants_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "material_variants_colorId_fkey" FOREIGN KEY ("colorId") REFERENCES "colors" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "colors" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL,
    "hexCode" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "estimation_projects" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "projectName" TEXT NOT NULL,
    "customerName" TEXT,
    "customerPhone" TEXT,
    "customerAddress" TEXT,
    "notes" TEXT,
    "profitMarginPercent" REAL NOT NULL DEFAULT 15,
    "laborCost" REAL NOT NULL DEFAULT 0,
    "additionalCost" REAL NOT NULL DEFAULT 0,
    "discountPercent" REAL NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "estimation_items" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "estimationProjectId" TEXT NOT NULL,
    "materialId" TEXT NOT NULL,
    "materialVariantId" TEXT,
    "widthMm" REAL NOT NULL,
    "heightMm" REAL NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "areaSqM" REAL NOT NULL DEFAULT 0,
    "unitCost" REAL NOT NULL DEFAULT 0,
    "materialCost" REAL NOT NULL DEFAULT 0,
    "description" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "estimation_items_estimationProjectId_fkey" FOREIGN KEY ("estimationProjectId") REFERENCES "estimation_projects" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "estimation_items_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "estimation_items_materialVariantId_fkey" FOREIGN KEY ("materialVariantId") REFERENCES "material_variants" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "categories_name_key" ON "categories"("name");

-- CreateIndex
CREATE UNIQUE INDEX "categories_slug_key" ON "categories"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "materials_code_key" ON "materials"("code");

-- CreateIndex
CREATE INDEX "materials_categoryId_idx" ON "materials"("categoryId");

-- CreateIndex
CREATE INDEX "material_variants_materialId_idx" ON "material_variants"("materialId");

-- CreateIndex
CREATE INDEX "material_variants_colorId_idx" ON "material_variants"("colorId");

-- CreateIndex
CREATE UNIQUE INDEX "material_variants_materialId_colorId_key" ON "material_variants"("materialId", "colorId");

-- CreateIndex
CREATE UNIQUE INDEX "colors_name_key" ON "colors"("name");

-- CreateIndex
CREATE INDEX "estimation_items_estimationProjectId_idx" ON "estimation_items"("estimationProjectId");

-- CreateIndex
CREATE INDEX "estimation_items_materialId_idx" ON "estimation_items"("materialId");

-- CreateIndex
CREATE INDEX "estimation_items_materialVariantId_idx" ON "estimation_items"("materialVariantId");
