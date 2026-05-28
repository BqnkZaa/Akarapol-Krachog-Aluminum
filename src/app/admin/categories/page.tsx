import Link from "next/link";
import {
  PlusCircle,
  FolderOpen,
  Layers,
  FileBox,
  ArrowLeft,
} from "lucide-react";
import { getCategories } from "@/actions/category";
import CategoryActions from "@/components/CategoryActions";

export const dynamic = "force-dynamic";

export const metadata = {
  title: "จัดการซีรีส์ — SmartQuote",
};

export default async function CategoriesPage() {
  const categories = await getCategories();

  const activeCount = categories.filter((c) => c.isActive).length;
  const totalMaterials = categories.reduce(
    (sum, c) => sum + c._count.materials,
    0
  );
  const totalTemplates = categories.reduce(
    (sum, c) => sum + c._count.templates,
    0
  );

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Page Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-6xl mx-auto px-6 py-6">
          <div className="flex items-center gap-2 text-sm text-gray-400 mb-3">
            <Link
              href="/dashboard"
              className="hover:text-gray-600 transition-colors"
            >
              หน้าหลัก
            </Link>
            <span>/</span>
            <span className="text-gray-600 font-medium">
              จัดการซีรีส์
            </span>
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">
                จัดการซีรีส์
              </h1>
              <p className="text-sm text-gray-500 mt-0.5">
                {activeCount} ซีรีส์ที่เปิดใช้งาน · {totalMaterials} เส้นอลูมิเนียม ·{" "}
                {totalTemplates} รูปแบบงาน
              </p>
            </div>
            <Link
              href="/admin/categories/new"
              id="add-category-btn"
              className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl shadow-sm transition-colors"
            >
              <PlusCircle className="w-4 h-4" />
              เพิ่มซีรีส์
            </Link>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-8">
        {categories.length === 0 ? (
          <div className="bg-white rounded-2xl border border-gray-200 p-16 text-center">
            <FolderOpen className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h3 className="font-semibold text-gray-700">ยังไม่มีซีรีส์</h3>
            <p className="text-sm text-gray-400 mt-1 mb-6">
              สร้างซีรีส์แรกของคุณเพื่อจัดระเบียบเส้นอลูมิเนียมและรูปแบบงาน
            </p>
            <Link
              href="/admin/categories/new"
              className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl transition-colors"
            >
              <PlusCircle className="w-4 h-4" /> เพิ่มซีรีส์แรก
            </Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {categories.map((cat) => (
              <div
                key={cat.id}
                id={`category-card-${cat.slug}`}
                className={`bg-white rounded-2xl border border-gray-200 shadow-sm hover:shadow-md transition-all duration-200 group relative overflow-hidden ${
                  !cat.isActive ? "opacity-60" : ""
                }`}
              >
                {/* Color accent bar */}
                <div
                  className={`h-1 ${cat.isActive ? "bg-gradient-to-r from-blue-500 to-indigo-500" : "bg-gray-300"}`}
                />

                <div className="p-5">
                  {/* Header */}
                  <div className="flex items-start justify-between mb-3">
                    <div className="flex-1 min-w-0">
                      <h3 className="font-bold text-gray-900 text-base truncate">
                        {cat.name}
                      </h3>
                      <p className="text-xs text-gray-400 font-mono mt-0.5">
                        /{cat.slug}
                      </p>
                    </div>
                    {!cat.isActive && (
                      <span className="text-xs text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full font-medium shrink-0 ml-2">
                        ปิดใช้งาน
                      </span>
                    )}
                  </div>

                  {/* Description */}
                  {cat.description ? (
                    <p className="text-sm text-gray-500 line-clamp-2 mb-4 min-h-[2.5rem]">
                      {cat.description}
                    </p>
                  ) : (
                    <p className="text-sm text-gray-300 italic mb-4 min-h-[2.5rem]">
                      ไม่มีคำอธิบาย
                    </p>
                  )}

                  {/* Stats */}
                  <div className="flex items-center gap-4 mb-4">
                    <div className="flex items-center gap-1.5 text-xs text-gray-500">
                      <Layers className="w-3.5 h-3.5 text-blue-500" />
                      <span className="font-semibold text-gray-700">
                        {cat._count.materials}
                      </span>
                      <span>เส้นอลูมิเนียม</span>
                    </div>
                    <div className="flex items-center gap-1.5 text-xs text-gray-500">
                      <FileBox className="w-3.5 h-3.5 text-purple-500" />
                      <span className="font-semibold text-gray-700">
                        {cat._count.templates}
                      </span>
                      <span>รูปแบบงาน</span>
                    </div>
                  </div>

                  {/* Sort order badge */}
                  <div className="flex items-center justify-between">
                    <span className="text-[10px] text-gray-400 bg-gray-100 px-2 py-0.5 rounded-full">
                      ลำดับ: {cat.sortOrder}
                    </span>

                    {/* Actions */}
                    <CategoryActions
                      categoryId={cat.id}
                      categoryName={cat.name}
                      materialCount={cat._count.materials}
                      templateCount={cat._count.templates}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
