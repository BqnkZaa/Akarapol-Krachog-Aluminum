import { getColors } from "@/actions/material";
import prisma from "@/lib/prisma";
import NewMaterialForm from "@/components/NewMaterialForm";

export const metadata = {
  title: "Add Material — SmartQuote",
};

export default async function NewMaterialPage() {
  // Fetch reference data server-side to pass as props
  const [colors, categories] = await Promise.all([
    getColors(),
    prisma.category.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: "asc" },
      select: { id: true, name: true },
    }),
  ]);

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Page Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-3xl mx-auto px-6 py-6">
          <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">Add Material</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Add a new aluminum profile or component with color-specific pricing.
          </p>
        </div>
      </div>

      {/* Form */}
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
        <NewMaterialForm categories={categories} colors={colors} />
      </div>
    </div>
  );
}
