import Link from "next/link";
import {
  PlusCircle,
  FileBox,
  Layers,
  Wine,
  ShoppingBag,
  CheckCircle2,
  XCircle,
  LayoutTemplate,
} from "lucide-react";
import { getTemplatesForAdmin } from "@/actions/template";
import TemplateActions from "@/components/TemplateActions";
import HashRowHighlighter from "@/components/HashRowHighlighter";

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
        <div className="max-w-7xl mx-auto px-4 md:px-8 py-4 md:py-6">
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
      <div className="max-w-7xl mx-auto px-4 md:px-8 py-6 md:py-8 space-y-6 md:space-y-10">
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

              {/* Desktop Table */}
              <div className="hidden md:block bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-sm">
                <div className="overflow-x-auto">
                  <table className="w-full text-sm min-w-[1000px]">
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
                          id={`template-${t.id}`}
                          className={`scroll-mt-24 hover:bg-gray-50/60 transition-colors duration-500 ${!t.isActive ? "opacity-55" : ""}`}
                        >
                          {/* Template name */}
                          <td className="py-4 px-5">
                            <div className="flex items-center gap-4">
                              {/* Thumbnail preview / fallback */}
                              <div className="w-12 h-12 shrink-0 bg-white border border-slate-200 rounded-md p-1 flex items-center justify-center overflow-hidden">
                                {t.imageUrl ? (
                                  <img
                                    src={t.imageUrl}
                                    alt={t.name}
                                    className="max-w-full max-h-full object-contain"
                                  />
                                ) : (
                                  <div className="w-full h-full bg-slate-50 flex items-center justify-center text-slate-300 rounded">
                                    <LayoutTemplate className="w-5 h-5" />
                                  </div>
                                )}
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="font-semibold text-gray-900 truncate max-w-xs md:max-w-md">{t.name}</p>
                                {t.description && (
                                  <p className="text-xs text-gray-400 mt-0.5 truncate max-w-xs" title={t.description}>
                                    {t.description}
                                  </p>
                                )}
                              </div>
                            </div>
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
                            <span className="text-xs text-gray-600 font-mono" title="ความยาวเส้นเต็ม">
                              {(t.standardBarLengthMm / 10).toFixed(1)} ซม.
                            </span>
                            <span className="text-gray-300 mx-1">/</span>
                            <span className="text-xs text-gray-600 font-mono" title="ใบเลื่อยตัดทิ้ง (Kerf)">
                              {(t.kerfMm / 10).toFixed(1)} ซม.
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

              {/* Mobile Cards */}
              <div className="md:hidden space-y-4">
                {items.map((t) => (
                  <div
                    key={t.id}
                    id={`template-${t.id}`}
                    className={`scroll-mt-24 bg-white rounded-2xl border border-gray-200 p-5 shadow-sm relative overflow-hidden transition-all duration-500 ${!t.isActive ? "opacity-75 bg-gray-50" : ""}`}
                  >
                    <div className={`absolute top-0 left-0 w-full h-1 ${t.isActive ? "bg-green-500" : "bg-gray-300"}`} />
                    
                    <div className="flex justify-between items-start mb-3 mt-1">
                      <div className="pr-2">
                        <p className="font-bold text-gray-900 text-base">{t.name}</p>
                      </div>
                      <div className="shrink-0">
                        <TemplateActions templateId={t.id} templateName={t.name} projectCount={t.projectCount} />
                      </div>
                    </div>
                    
                    {t.description && (
                      <p className="text-sm text-gray-500 mb-4 line-clamp-2">{t.description}</p>
                    )}

                    <div className="grid grid-cols-2 gap-y-3 gap-x-4 text-sm mb-4 bg-gray-50 rounded-xl p-3 border border-gray-100">
                      <div className="flex flex-col">
                        <span className="text-xs text-gray-500 mb-0.5 flex items-center gap-1.5"><Layers className="w-3.5 h-3.5" /> โปรไฟล์</span>
                        <span className="font-semibold text-gray-900">{t.componentCount} ชิ้นส่วน</span>
                      </div>
                      <div className="flex flex-col">
                        <span className="text-xs text-gray-500 mb-0.5 flex items-center gap-1.5"><ShoppingBag className="w-3.5 h-3.5" /> อุปกรณ์</span>
                        <span className="font-semibold text-gray-900">{t.accessoryCount || "—"}</span>
                      </div>
                      <div className="flex flex-col">
                        <span className="text-xs text-gray-500 mb-0.5 flex items-center gap-1.5"><CheckCircle2 className="w-3.5 h-3.5" /> กระจก</span>
                        <span className="font-semibold text-gray-900">{t.hasGlass ? "มี" : "—"}</span>
                      </div>
                      <div className="flex flex-col">
                        <span className="text-xs text-gray-500 mb-0.5 flex items-center gap-1.5"><FileBox className="w-3.5 h-3.5" /> ประเมินแล้ว</span>
                        <span className="font-semibold text-gray-900">{t.projectCount} ครั้ง</span>
                      </div>
                    </div>

                    <div className="pt-3 border-t border-gray-100 flex items-center justify-between">
                      <div className="text-xs text-gray-500">
                        ตัดทิ้ง: <span className="font-mono">{(t.kerfMm / 10).toFixed(1)}</span> ซม.
                      </div>
                      <div>
                        {t.isActive ? (
                          <span className="inline-flex items-center gap-1 text-xs font-medium text-green-700 bg-green-50 px-2 py-0.5 rounded-full">
                            <CheckCircle2 className="w-3 h-3" /> เปิดใช้งาน
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-xs font-medium text-gray-500 bg-gray-100 px-2 py-0.5 rounded-full">
                            <XCircle className="w-3 h-3" /> ปิดใช้งาน
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          ))
        )}
        <HashRowHighlighter />
      </div>
    </div>
  );
}
