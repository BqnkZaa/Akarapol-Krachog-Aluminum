import Link from "next/link";
import { PlusCircle, Tag, Palette } from "lucide-react";
import prisma from "@/lib/prisma";
import MaterialActions from "@/components/MaterialActions";

export const metadata = {
  title: "Materials — SmartQuote",
};

async function getMaterials() {
  return prisma.material.findMany({
    orderBy: [{ category: { name: "asc" } }, { sortOrder: "asc" }, { code: "asc" }],
    include: {
      category: { select: { id: true, name: true } },
      variants: {
        where: { isActive: true },
        include: { color: { select: { id: true, name: true, hexCode: true } } },
        orderBy: { color: { sortOrder: "asc" } },
      },
    },
  });
}

type Material = Awaited<ReturnType<typeof getMaterials>>[number];

export default async function MaterialsPage() {
  const materials = await getMaterials();

  // Group by category for a nicer table layout
  const grouped = materials.reduce<Record<string, { catName: string; items: Material[] }>>(
    (acc, mat) => {
      const key = mat.categoryId;
      if (!acc[key]) acc[key] = { catName: mat.category.name, items: [] };
      acc[key].items.push(mat);
      return acc;
    },
    {}
  );

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Page Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-6xl mx-auto px-6 py-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">Materials</h1>
            <p className="text-sm text-gray-500 mt-0.5">
              {materials.length} profile{materials.length !== 1 ? "s" : ""} across{" "}
              {Object.keys(grouped).length} categor{Object.keys(grouped).length !== 1 ? "ies" : "y"}
            </p>
          </div>
          <Link
            href="/materials/new"
            className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl shadow-sm transition-colors"
          >
            <PlusCircle className="w-4 h-4" />
            Add Material
          </Link>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-8 space-y-10">
        {materials.length === 0 && (
          <div className="bg-white rounded-2xl border border-gray-200 p-16 text-center">
            <Tag className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h3 className="font-semibold text-gray-700">No materials yet</h3>
            <p className="text-sm text-gray-400 mt-1 mb-6">
              Add your first aluminum profile to get started.
            </p>
            <Link
              href="/materials/new"
              className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl transition-colors"
            >
              <PlusCircle className="w-4 h-4" /> Add First Material
            </Link>
          </div>
        )}

        {Object.entries(grouped).map(([catId, { catName, items }]) => (
          <section key={catId}>
            {/* Category heading */}
            <div className="flex items-center gap-3 mb-4">
              <div className="w-2 h-6 bg-blue-600 rounded-full" />
              <h2 className="text-base font-bold text-gray-800">{catName}</h2>
              <span className="text-xs text-gray-400 bg-gray-100 px-2 py-0.5 rounded-full">
                {items.length} item{items.length !== 1 ? "s" : ""}
              </span>
            </div>

            {/* Table */}
            <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-sm">
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-gray-100 bg-gray-50/70">
                      <th className="text-left py-3 px-5 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                        Code
                      </th>
                      <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                        Name
                      </th>
                      <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                        Unit
                      </th>
                      <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                        <span className="flex items-center gap-1.5">
                          <Palette className="w-3.5 h-3.5" /> Color Prices
                        </span>
                      </th>
                      <th className="text-right py-3 px-5 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                        Actions
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {items.map((mat) => (
                      <tr
                        key={mat.id}
                        className={`hover:bg-gray-50/60 transition-colors ${!mat.isActive ? "opacity-50" : ""}`}
                      >
                        {/* Code */}
                        <td className="py-4 px-5">
                          <span className="font-mono text-xs font-semibold text-blue-600 bg-blue-50 px-2 py-1 rounded-lg">
                            {mat.code}
                          </span>
                        </td>

                        {/* Name */}
                        <td className="py-4 px-4">
                          <p className="font-medium text-gray-900">{mat.name}</p>
                          {mat.description && (
                            <p className="text-xs text-gray-400 mt-0.5 truncate max-w-xs">
                              {mat.description}
                            </p>
                          )}
                          {!mat.isActive && (
                            <span className="inline-block mt-1 text-xs text-red-500 bg-red-50 px-2 py-0.5 rounded-full">
                              Inactive
                            </span>
                          )}
                        </td>

                        {/* Unit */}
                        <td className="py-4 px-4">
                          <span className="text-gray-600">{mat.unit}</span>
                        </td>

                        {/* Variants */}
                        <td className="py-4 px-4">
                          <div className="flex flex-wrap gap-2">
                            {mat.variants.map((v) => (
                              <div
                                key={v.id}
                                className="flex items-center gap-1.5 bg-gray-100 rounded-lg px-2.5 py-1 text-xs"
                              >
                                {v.color.hexCode && (
                                  <span
                                    className="w-3 h-3 rounded-full border border-gray-300 shrink-0"
                                    style={{ backgroundColor: v.color.hexCode }}
                                  />
                                )}
                                <span className="text-gray-600">{v.color.name}</span>
                                <span className="font-semibold text-gray-800">
                                  ฿{v.unitCost.toLocaleString()}
                                </span>
                              </div>
                            ))}
                            {mat.variants.length === 0 && (
                              <span className="text-gray-400 italic text-xs">No variants</span>
                            )}
                          </div>
                        </td>

                        {/* Actions */}
                        <td className="py-4 px-5 text-right">
                          <MaterialActions materialId={mat.id} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
