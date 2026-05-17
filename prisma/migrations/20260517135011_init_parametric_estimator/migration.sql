-- CreateTable
CREATE TABLE "categories" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "description" TEXT,
    "imageUrl" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "materials" (
    "id" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "unit" TEXT NOT NULL DEFAULT 'เส้น',
    "baseCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "description" TEXT,
    "imageUrl" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "materials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "material_variants" (
    "id" TEXT NOT NULL,
    "materialId" TEXT NOT NULL,
    "colorId" TEXT NOT NULL,
    "unitCost" DOUBLE PRECISION NOT NULL,
    "sku" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "material_variants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "colors" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "hexCode" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "colors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_templates" (
    "id" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "description" TEXT,
    "imageUrl" TEXT,
    "standardBarLengthMm" INTEGER NOT NULL DEFAULT 6000,
    "kerfMm" INTEGER NOT NULL DEFAULT 5,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "template_components" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "materialId" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "formula" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "barLengthMm" INTEGER,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "template_components_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "glass_specifications" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "widthFormula" TEXT NOT NULL,
    "heightFormula" TEXT NOT NULL,
    "panelCount" INTEGER NOT NULL DEFAULT 1,
    "glassType" TEXT NOT NULL DEFAULT '6mm Clear Tempered',
    "pricePerSqM" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "glass_specifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "template_accessories" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "unitCost" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL DEFAULT 'ชุด',
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "template_accessories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "estimation_projects" (
    "id" TEXT NOT NULL,
    "projectName" TEXT NOT NULL,
    "customerName" TEXT,
    "customerPhone" TEXT,
    "customerAddress" TEXT,
    "notes" TEXT,
    "templateId" TEXT NOT NULL,
    "colorId" TEXT NOT NULL,
    "widthMm" DOUBLE PRECISION NOT NULL,
    "heightMm" DOUBLE PRECISION NOT NULL,
    "profitMarginPercent" DOUBLE PRECISION NOT NULL DEFAULT 15,
    "laborCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "additionalCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discountPercent" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "glassCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "accessoryCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "materialCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalBarsUsed" INTEGER NOT NULL DEFAULT 0,
    "wastePercent" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "estimation_projects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cutting_results" (
    "id" TEXT NOT NULL,
    "estimationProjectId" TEXT NOT NULL,
    "materialId" TEXT NOT NULL,
    "materialCode" TEXT NOT NULL,
    "materialName" TEXT NOT NULL,
    "barUnitCost" DOUBLE PRECISION NOT NULL,
    "barLengthMm" INTEGER NOT NULL,
    "barsRequired" INTEGER NOT NULL,
    "cutDetails" TEXT NOT NULL,
    "totalUsedMm" INTEGER NOT NULL,
    "totalWasteMm" INTEGER NOT NULL,
    "wastePercent" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cutting_results_pkey" PRIMARY KEY ("id")
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
CREATE UNIQUE INDEX "product_templates_name_key" ON "product_templates"("name");

-- CreateIndex
CREATE UNIQUE INDEX "product_templates_slug_key" ON "product_templates"("slug");

-- CreateIndex
CREATE INDEX "product_templates_categoryId_idx" ON "product_templates"("categoryId");

-- CreateIndex
CREATE INDEX "template_components_templateId_idx" ON "template_components"("templateId");

-- CreateIndex
CREATE INDEX "template_components_materialId_idx" ON "template_components"("materialId");

-- CreateIndex
CREATE UNIQUE INDEX "glass_specifications_templateId_key" ON "glass_specifications"("templateId");

-- CreateIndex
CREATE INDEX "template_accessories_templateId_idx" ON "template_accessories"("templateId");

-- CreateIndex
CREATE INDEX "estimation_projects_templateId_idx" ON "estimation_projects"("templateId");

-- CreateIndex
CREATE INDEX "estimation_projects_colorId_idx" ON "estimation_projects"("colorId");

-- CreateIndex
CREATE INDEX "cutting_results_estimationProjectId_idx" ON "cutting_results"("estimationProjectId");

-- CreateIndex
CREATE INDEX "cutting_results_materialId_idx" ON "cutting_results"("materialId");

-- AddForeignKey
ALTER TABLE "materials" ADD CONSTRAINT "materials_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_variants" ADD CONSTRAINT "material_variants_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_variants" ADD CONSTRAINT "material_variants_colorId_fkey" FOREIGN KEY ("colorId") REFERENCES "colors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_templates" ADD CONSTRAINT "product_templates_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "template_components" ADD CONSTRAINT "template_components_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "product_templates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "template_components" ADD CONSTRAINT "template_components_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "glass_specifications" ADD CONSTRAINT "glass_specifications_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "product_templates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "template_accessories" ADD CONSTRAINT "template_accessories_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "product_templates"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estimation_projects" ADD CONSTRAINT "estimation_projects_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "product_templates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estimation_projects" ADD CONSTRAINT "estimation_projects_colorId_fkey" FOREIGN KEY ("colorId") REFERENCES "colors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cutting_results" ADD CONSTRAINT "cutting_results_estimationProjectId_fkey" FOREIGN KEY ("estimationProjectId") REFERENCES "estimation_projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cutting_results" ADD CONSTRAINT "cutting_results_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
