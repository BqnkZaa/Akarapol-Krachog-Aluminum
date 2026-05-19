-- CreateTable
CREATE TABLE "glass_types" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "thicknessMm" INTEGER,
    "pricePerSqM" DOUBLE PRECISION NOT NULL,
    "description" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "glass_types_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "glass_types_name_key" ON "glass_types"("name");
