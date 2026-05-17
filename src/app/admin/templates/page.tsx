import Link from "next/link";
import {
  PlusCircle,
  FileBox,
  Layers,
  Wine,
  ShoppingBag,
  CheckCircle2,
  XCircle,
} from "lucide-react";
import { getTemplatesForAdmin } from "@/actions/template";
import TemplateActions from "@/components/TemplateActions";

// Force TS server reload
export const dynamic = "force-dynamic";

export const metadata = {
  title: "จัดการรูปแบบงาน — SmartQuote",
};

export default async function TemplatesPage() {
  const templates = await getTemplatesForAdmin();

  const activeCount = templates.filter((t) => t.isActive).length;

  // Group by category for display
  const grouped = templates.reduce<
    Record<string, { categoryName: string; items: typeof templates }>
  >((acc, t) => {
    if (!acc[t.categoryId]) {
      acc[t.categoryId] = { categoryName: t.categoryName, items: [] };
    }
    acc[t.categoryId].items.push(t);
    return acc;
  }, {});

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Page Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-6 py-6">
          <div className="flex items-center gap-2 text-sm text-gray-400 mb-3">
            <Link href="/dashboard" className="hover:text-gray-600 transition-colors">
              หน้าหลัก
            </Link>
            <span>/</span>
            <span className="text-gray-600 font-medium">รูปแบบงาน</span>
          </div>
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">
                รูปแบบงาน
              </h1>
              <p className="text-sm text-gray-500 mt-0.5">
                {activeCount} เปิดใช้งาน · {templates.length} รูปแบบงานทั้งหมด
              </p>
            </div>
            <Link
              href="/admin/templates/new"
              id="add-template-btn"
              className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl shadow-sm transition-colors"
            >
              <PlusCircle className="w-4 h-4" />
              เพิ่มรูปแบบงาน
            </Link>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8 space-y-10">
        {templates.length === 0 ? (
          <div className="bg-white rounded-2xl border border-gray-200 p-16 text-center">
            <FileBox className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h3 className="font-semibold text-gray-700">ยังไม่มีรูปแบบงาน</h3>
            <p className="text-sm text-gray-400 mt-1 mb-6">
              สร้างรูปแบบงานแรกของคุณเพื่อเริ่มสร้างใบเสนอราคา
            </p>
            <Link
              href="/admin/templates/new"
              className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl transition-colors"
            >
              <PlusCircle className="w-4 h-4" /> เพิ่มรูปแบบงานแรก
            </Link>
          </div>
        ) : (
          Object.entries(grouped).map(([catId, { categoryName, items }]) => (
            <section key={catId}>
              {/* Category heading */}
              <div className="flex items-center gap-3 mb-4">
                <div className="w-2 h-6 bg-indigo-600 rounded-full" />
                <h2 className="text-base font-bold text-gray-800">{categoryName}</h2>
                <span className="text-xs text-gray-400 bg-gray-100 px-2 py-0.5 rounded-full">
                  {items.length} รูปแบบงาน
                </span>
              </div>

              <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-sm">
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-gray-100 bg-gray-50/70">
                        <th className="text-left py-3 px-5 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                          รูปแบบงาน
                        </th>
                        <th className="text-center py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                          <span className="flex items-center justify-center gap-1">
                            <Layers className="w-3.5 h-3.5" /> โปรไฟล์
                          </span>
                        </th>
                        <th className="text-center py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                          กระจก
                        </th>
                        <th className="text-center py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                          <span className="flex items-center justify-center gap-1">
                            <ShoppingBag className="w-3.5 h-3.5" /> อุปกรณ์เสริม
                          </span>
                        </th>
                        <th className="text-center py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                          ความยาวเส้นเต็ม / ตัดทิ้ง
                        </th>
                        <th className="text-center py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                          ประเมินราคา
                        </th>
                        <th className="text-center py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                          สถานะ
                        </th>
                        <th className="text-right py-3 px-5 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                          จัดการ
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                      {items.map((t) => (
                        <tr
                          key={t.id}
                          id={`template-row-${t.slug}`}
                          className={`hover:bg-gray-50/60 transition-colors ${!t.isActive ? "opacity-55" : ""}`}
                        >
                          {/* Template name + slug */}
                          <td className="py-4 px-5">
                            <p className="font-semibold text-gray-900">{t.name}</p>
                            <p className="text-xs font-mono text-gray-400 mt-0.5">
                              /{t.slug}
                            </p>
                            {t.description && (
                              <p className="text-xs text-gray-400 mt-0.5 truncate max-w-xs">
                                {t.description}
                              </p>
                            )}
                          </td>

                          {/* Profile count */}
                          <td className="py-4 px-4 text-center">
                            <span className="inline-flex items-center justify-center w-7 h-7 rounded-lg bg-blue-50 text-blue-700 font-bold text-xs">
                              {t.componentCount}
                            </span>
                          </td>

                          {/* Glass */}
                          <td className="py-4 px-4 text-center">
                            {t.hasGlass ? (
                              <CheckCircle2 className="w-5 h-5 text-green-500 mx-auto" />
                            ) : (
                              <span className="text-gray-300 text-xs">—</span>
                            )}
                          </td>

                          {/* Accessories */}
                          <td className="py-4 px-4 text-center">
                            {t.accessoryCount > 0 ? (
                              <span className="inline-flex items-center justify-center w-7 h-7 rounded-lg bg-purple-50 text-purple-700 font-bold text-xs">
                                {t.accessoryCount}
                              </span>
                            ) : (
                              <span className="text-gray-300 text-xs">—</span>
                            )}
                          </td>

                          {/* Bar length / Kerf */}
                          <td className="py-4 px-4 text-center">
                            <span className="text-xs text-gray-600 font-mono">
                              {(t.standardBarLengthMm / 1000).toFixed(1)}m
                            </span>
                            <span className="text-gray-300 mx-1">/</span>
                            <span className="text-xs text-gray-600 font-mono">
                              {t.kerfMm}mm
                            </span>
                          </td>

                          {/* Quotes */}
                          <td className="py-4 px-4 text-center">
                            <span className="text-sm font-semibold text-gray-700">
                              {t.projectCount}
                            </span>
                          </td>

                          {/* Status */}
                          <td className="py-4 px-4 text-center">
                            {t.isActive ? (
                              <span className="inline-flex items-center gap-1 text-xs font-medium text-green-700 bg-green-50 px-2.5 py-1 rounded-full">
                                <CheckCircle2 className="w-3 h-3" /> เปิดใช้งาน
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 text-xs font-medium text-gray-500 bg-gray-100 px-2.5 py-1 rounded-full">
                                <XCircle className="w-3 h-3" /> ปิดใช้งาน
                              </span>
                            )}
                          </td>

                          {/* Actions */}
                          <td className="py-4 px-5 text-right">
                            <TemplateActions
                              templateId={t.id}
                              templateName={t.name}
                              projectCount={t.projectCount}
                            />
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </section>
          ))
        )}
      </div>
    </div>
  );
}
