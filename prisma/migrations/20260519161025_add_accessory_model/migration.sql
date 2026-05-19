-- CreateTable
CREATE TABLE "accessories" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "unit" TEXT NOT NULL DEFAULT 'ชิ้น',
    "baseCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "description" TEXT,
    "imageUrl" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "accessories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "accessory_variants" (
    "id" TEXT NOT NULL,
    "accessoryId" TEXT NOT NULL,
    "colorId" TEXT NOT NULL,
    "unitCost" DOUBLE PRECISION NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "accessory_variants_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "accessories_code_key" ON "accessories"("code");

-- CreateIndex
CREATE INDEX "accessory_variants_accessoryId_idx" ON "accessory_variants"("accessoryId");

-- CreateIndex
CREATE INDEX "accessory_variants_colorId_idx" ON "accessory_variants"("colorId");

-- CreateIndex
CREATE UNIQUE INDEX "accessory_variants_accessoryId_colorId_key" ON "accessory_variants"("accessoryId", "colorId");

-- AddForeignKey
ALTER TABLE "accessory_variants" ADD CONSTRAINT "accessory_variants_accessoryId_fkey" FOREIGN KEY ("accessoryId") REFERENCES "accessories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "accessory_variants" ADD CONSTRAINT "accessory_variants_colorId_fkey" FOREIGN KEY ("colorId") REFERENCES "colors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
