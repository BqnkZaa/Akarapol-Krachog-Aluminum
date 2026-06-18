import Link from "next/link";
import { PlusCircle, FlaskConical, ChevronLeft, ChevronRight, Search } from "lucide-react";
import prisma from "@/lib/prisma";
import GlassActions from "@/components/GlassActions";
import { Metadata } from "next";
import HashRowHighlighter from "@/components/HashRowHighlighter";

export const dynamic = "force-dynamic";

interface PageProps {
  searchParams: Promise<{ page?: string; q?: string; category?: string }>;
}

export async function generateMetadata({ searchParams }: PageProps): Promise<Metadata> {
  const params = await searchParams;
  const category = params.category?.trim() ?? "";
  let title = "กระจก — SmartQuote";
  if (category) {
    title = `จัดการข้อมูล: ${category} — SmartQuote`;
  }
  return { title };
}

const PAGE_SIZE = 50;

async function getGlasses(page: number, query: string, category?: string) {
  const skip = (page - 1) * PAGE_SIZE;

  const where = {
    isActive: true,
    ...(category ? { category } : {}),
    ...(query
      ? {
          name: { contains: query },
        }
      : {}),
  };

  const [glasses, total] = await Promise.all([
    prisma.glass.findMany({
      where,
      orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
      take: PAGE_SIZE,
      skip,
    }),
    prisma.glass.count({ where }),
  ]);

  return { glasses, total };
}

export default async function GlassPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const page = Math.max(1, parseInt(params.page ?? "1", 10));
  const query = params.q?.trim() ?? "";
  const category = params.category?.trim() ?? "";

  const { glasses, total } = await getGlasses(page, query, category);
  const totalPages = Math.ceil(total / PAGE_SIZE);

  function buildUrl(overrides: Record<string, string | number>) {
    const p = new URLSearchParams();
    if (query) p.set("q", query);
    if (category) p.set("category", category);
    p.set("page", String(page));
    Object.entries(overrides).forEach(([k, v]) => {
      if (v) p.set(k, String(v));
      else p.delete(k);
    });
    return `/admin/glass?${p.toString()}`;
  }

  let pageHeader = "จัดการข้อมูล: กระจกทั้งหมด";
  if (category) {
    pageHeader = `จัดการข้อมูล: ${category}`;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Page Header */}
      <div className="bg-white border-b border-gray-200">
         <div className="max-w-6xl mx-auto px-4 md:px-8 py-4 md:py-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">{pageHeader}</h1>
            <p className="text-sm text-gray-500 mt-0.5">
              {total.toLocaleString()} ชนิด{total !== 1 ? "" : ""} ในระบบ
              {query || category ? ` — กำลังกรอง` : ""}
            </p>
          </div>
          <Link
            href="/admin/glass/new"
            className="inline-flex items-center gap-2 bg-sky-600 hover:bg-sky-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl shadow-sm transition-colors"
          >
            <PlusCircle className="w-4 h-4" />
            เพิ่มกระจกใหม่
          </Link>
        </div>
      </div>

      {/* Filters Bar */}
      <div className="bg-white border-b border-gray-100 sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-4 md:px-8 py-3 flex flex-col sm:flex-row gap-3">
          <form method="GET" action="/admin/glass" className="flex-1 flex gap-2">
            {category && <input type="hidden" name="category" value={category} />}
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
              <input
                type="text"
                name="q"
                defaultValue={query}
                placeholder="ค้นหาชื่อกระจก…"
                className="w-full pl-9 pr-4 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500 focus:border-transparent bg-gray-50"
              />
            </div>
            <button
              type="submit"
              className="px-4 py-2 text-sm font-semibold bg-sky-600 text-white rounded-xl hover:bg-sky-700 transition-colors"
            >
              ค้นหา
            </button>
            {query && (
              <Link
                href={category ? `/admin/glass?category=${encodeURIComponent(category)}` : "/admin/glass"}
                className="px-4 py-2 text-sm font-semibold text-gray-600 bg-gray-100 rounded-xl hover:bg-gray-200 transition-colors whitespace-nowrap"
              >
                ล้าง
              </Link>
            )}
          </form>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-6xl mx-auto px-4 md:px-8 py-6 md:py-8 space-y-6 md:space-y-10">
        {glasses.length === 0 && (
          <div className="bg-white rounded-2xl border border-gray-200 p-16 text-center">
            <FlaskConical className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h3 className="font-semibold text-gray-700">
              {query ? "ไม่พบกระจกที่ตรงกับการค้นหา" : "ยังไม่มีข้อมูลกระจก"}
            </h3>
            <p className="text-sm text-gray-400 mt-1 mb-6">
              {query
                ? "ลองปรับคำค้นหาดู"
                : "เพิ่มกระจกชนิดแรกเพื่อเริ่มต้น"}
            </p>
            {!query && (
              <Link
                href="/admin/glass/new"
                className="inline-flex items-center gap-2 bg-sky-600 hover:bg-sky-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl transition-colors"
              >
                <PlusCircle className="w-4 h-4" /> เพิ่มกระจกชนิดแรก
              </Link>
            )}
          </div>
        )}

        {glasses.length > 0 && (
          <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-sm min-w-[700px]">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50/70">
                    <th className="text-left py-3 px-4 sm:px-5 font-semibold text-gray-500 text-xs uppercase tracking-wide min-w-[200px]">
                      ชื่อกระจก
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap hidden md:table-cell">
                      ความหนา
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap">
                      ราคา / ตร.ม.
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide hidden lg:table-cell">
                      หมายเหตุ
                    </th>
                    <th className="text-right py-3 px-4 sm:px-5 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap">
                      จัดการ
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {glasses.map((g) => (
                    <tr
                      key={g.id}
                      id={`glass-${g.id}`}
                      className={`scroll-mt-24 hover:bg-gray-50/60 transition-colors duration-500 ${!g.isActive ? "opacity-50" : ""}`}
                    >
                      {/* Name */}
                      <td className="py-4 px-4 sm:px-5 min-w-[200px]">
                        <div className="flex items-center gap-2.5">
                          <div className="w-8 h-8 rounded-lg bg-sky-50 flex items-center justify-center shrink-0">
                            <FlaskConical className="w-4 h-4 text-sky-500" />
                          </div>
                          <div>
                            <p className="font-medium text-gray-900">{g.name}</p>
                            {!g.isActive && (
                              <span className="inline-block mt-0.5 text-xs text-red-500 bg-red-50 px-2 py-0.5 rounded-full">
                                ปิดใช้งาน
                              </span>
                            )}
                          </div>
                        </div>
                      </td>

                      {/* Thickness */}
                      <td className="py-4 px-4 whitespace-nowrap hidden md:table-cell">
                        {g.thicknessMm ? (
                          <span className="inline-flex items-center px-2.5 py-1 rounded-lg bg-gray-100 text-gray-700 text-xs font-semibold">
                            {g.thicknessMm} มม.
                          </span>
                        ) : (
                          <span className="text-gray-300 text-xs italic">—</span>
                        )}
                      </td>

                      {/* Price */}
                      <td className="py-4 px-4 whitespace-nowrap">
                        <span className="font-semibold text-gray-900">
                          ฿{g.pricePerSqM.toLocaleString("th-TH", { minimumFractionDigits: 0, maximumFractionDigits: 2 })}
                        </span>
                        <span className="text-xs text-gray-400 ml-1">/ตร.ม.</span>
                      </td>

                      {/* Description */}
                      <td className="py-4 px-4 hidden lg:table-cell">
                        <p className="text-xs text-gray-400 truncate max-w-xs">
                          {g.description ?? <span className="italic">—</span>}
                        </p>
                      </td>

                      {/* Actions */}
                      <td className="py-4 px-4 sm:px-5 text-right">
                        <GlassActions
                          glass={{
                            id: g.id,
                            name: g.name,
                            category: g.category,
                            thicknessMm: g.thicknessMm,
                            pricePerSqM: g.pricePerSqM,
                            description: g.description,
                          }}
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Pagination Controls */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between bg-white rounded-2xl border border-gray-200 px-6 py-4 shadow-sm">
            <p className="text-sm text-gray-500">
              แสดง{" "}
              <span className="font-semibold text-gray-800">
                {((page - 1) * PAGE_SIZE + 1).toLocaleString()}–
                {Math.min(page * PAGE_SIZE, total).toLocaleString()}
              </span>{" "}
              จาก <span className="font-semibold text-gray-800">{total.toLocaleString()}</span> รายการ
            </p>

            <div className="flex items-center gap-2">
              {page > 1 ? (
                <Link
                  href={buildUrl({ page: page - 1 })}
                  className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors"
                >
                  <ChevronLeft className="w-4 h-4" /> ก่อนหน้า
                </Link>
              ) : (
                <span className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-300 bg-gray-50 rounded-xl cursor-not-allowed">
                  <ChevronLeft className="w-4 h-4" /> ก่อนหน้า
                </span>
              )}

              <span className="text-sm text-gray-500 px-2">
                หน้า <span className="font-bold text-gray-800">{page}</span> / {totalPages}
              </span>

              {page < totalPages ? (
                <Link
                  href={buildUrl({ page: page + 1 })}
                  className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors"
                >
                  ถัดไป <ChevronRight className="w-4 h-4" />
                </Link>
              ) : (
                <span className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-300 bg-gray-50 rounded-xl cursor-not-allowed">
                  ถัดไป <ChevronRight className="w-4 h-4" />
                </span>
              )}
            </div>
          </div>
        )}
        <HashRowHighlighter />
      </div>
    </div>
  );
}
