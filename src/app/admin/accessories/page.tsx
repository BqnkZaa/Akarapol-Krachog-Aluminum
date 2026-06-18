import Link from "next/link";
import { PlusCircle, Tag, Palette, ChevronLeft, ChevronRight, Search } from "lucide-react";
import prisma from "@/lib/prisma";
import AccessoryActions from "@/components/AccessoryActions";
import { Metadata } from "next";
import HashRowHighlighter from "@/components/HashRowHighlighter";

// ── Series badge ───────────────────────────────────────────────────────────
const SERIES_COLORS: Record<string, string> = {
  iConiq: "bg-indigo-100 text-indigo-700 border-indigo-200",
  Euro: "bg-emerald-100 text-emerald-700 border-emerald-200",
  "Smart X": "bg-sky-100 text-sky-700 border-sky-200",
  Vista: "bg-amber-100 text-amber-700 border-amber-200",
  Flexi: "bg-rose-100 text-rose-700 border-rose-200",
  "ชุดบานเลื่อน": "bg-blue-100 text-blue-700 border-blue-200",
  "ชุดบานเปิด, บานกระทุ้ง": "bg-emerald-100 text-emerald-700 border-emerald-200",
  "ชุดบานเฟี้ยม": "bg-purple-100 text-purple-700 border-purple-200",
  "ชุดท้องตลาด": "bg-amber-100 text-amber-700 border-amber-200",
  "ทั่วไป": "bg-amber-100 text-amber-700 border-amber-200",
  "ชุดบานเปลือย": "bg-rose-100 text-rose-700 border-rose-200",
};

function SeriesBadge({ series }: { series: string }) {
  const displaySeries = series === "ทั่วไป" ? "ชุดท้องตลาด" : series;
  const cls = SERIES_COLORS[displaySeries] ?? "bg-gray-100 text-gray-600 border-gray-200";
  return (
    <span className={`inline-block text-xs font-semibold px-2.5 py-0.5 rounded-full border ${cls}`}>
      {displaySeries}
    </span>
  );
}

export const dynamic = "force-dynamic";

interface PageProps {
  searchParams: Promise<{ page?: string; q?: string; series?: string }>;
}

export async function generateMetadata({ searchParams }: PageProps): Promise<Metadata> {
  const params = await searchParams;
  const series = params.series?.trim() ?? "";
  let title = "อุปกรณ์เสริม — SmartQuote";
  if (series) {
    if (series.includes("ชุดบานเลื่อน")) title = "อุปกรณ์บานเลื่อน — SmartQuote";
    else if (series.includes("ชุดบานเปิด")) title = "อุปกรณ์บานเปิด — SmartQuote";
    else if (series.includes("ชุดบานเฟี้ยม")) title = "อุปกรณ์บานเฟี้ยม — SmartQuote";
    else if (series.includes("ชุดท้องตลาด")) title = "อุปกรณ์ชุดท้องตลาด — SmartQuote";
    else if (series.includes("ชุดบานเปลือย")) title = "อุปกรณ์บานเปลือย — SmartQuote";
  }
  return { title };
}

const PAGE_SIZE = 50;

async function getAccessories(page: number, query: string, series?: string) {
  const skip = (page - 1) * PAGE_SIZE;

  let seriesFilter: any = undefined;
  if (series) {
    let seriesList = series.split(",").map((s) => s.trim());
    // Map official "ชุดท้องตลาด" filter to also display legacy "ทั่วไป" entries
    if (seriesList.includes("ชุดท้องตลาด")) {
      seriesList.push("ทั่วไป");
    }
    seriesFilter = { in: seriesList };
  }

  const where = {
    isActive: true,
    ...(seriesFilter ? { series: seriesFilter } : {}),
    ...(query
      ? {
          OR: [
            { name: { contains: query } },
            { code: { contains: query } },
          ],
        }
      : {}),
  };

  const [accessories, total] = await Promise.all([
    prisma.accessory.findMany({
      where,
      orderBy: [
        { series: "asc" },
        { code: "asc" },
      ],
      include: {
        variants: {
          where: { isActive: true },
          include: { color: { select: { id: true, name: true, hexCode: true } } },
          orderBy: { color: { sortOrder: "asc" } },
        },
      },
      take: PAGE_SIZE,
      skip,
    }),
    prisma.accessory.count({ where }),
  ]);

  return { accessories, total };
}

export default async function AccessoriesPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const page = Math.max(1, parseInt(params.page ?? "1", 10));
  const query = params.q?.trim() ?? "";
  const series = params.series?.trim() ?? "";

  const { accessories, total } = await getAccessories(page, query, series);

  const totalPages = Math.ceil(total / PAGE_SIZE);

  function buildUrl(overrides: Record<string, string | number>) {
    const p = new URLSearchParams();
    if (query) p.set("q", query);
    if (series) p.set("series", series);
    p.set("page", String(page));
    Object.entries(overrides).forEach(([k, v]) => {
      if (v) p.set(k, String(v));
      else p.delete(k);
    });
    return `/admin/accessories?${p.toString()}`;
  }

  let pageHeader = "จัดการข้อมูล: อุปกรณ์ทั้งหมด";
  if (series) {
    if (series.includes("ชุดบานเลื่อน")) pageHeader = "จัดการข้อมูล: อุปกรณ์บานเลื่อน";
    else if (series.includes("ชุดบานเปิด")) pageHeader = "จัดการข้อมูล: อุปกรณ์บานเปิด";
    else if (series.includes("ชุดบานเฟี้ยม")) pageHeader = "จัดการข้อมูล: อุปกรณ์บานเฟี้ยม";
    else if (series.includes("ชุดท้องตลาด")) pageHeader = "จัดการข้อมูล: อุปกรณ์ชุดท้องตลาด";
    else if (series.includes("ชุดบานเปลือย")) pageHeader = "จัดการข้อมูล: อุปกรณ์บานเปลือย";
    else pageHeader = `จัดการข้อมูล: อุปกรณ์${series}`;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Page Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-6xl mx-auto px-4 md:px-8 py-4 md:py-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">{pageHeader}</h1>
            <p className="text-sm text-gray-500 mt-0.5">
              {total.toLocaleString()} hardware item{total !== 1 ? "s" : ""} total
              {query || series ? ` — filtered view` : ""}
            </p>
          </div>
          <Link
            href="/admin/accessories/new"
            className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl shadow-sm transition-colors"
          >
            <PlusCircle className="w-4 h-4" />
            Add Accessory
          </Link>
        </div>
      </div>

      {/* Filters Bar */}
      <div className="bg-white border-b border-gray-100 sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-4 md:px-8 py-3 flex flex-col sm:flex-row gap-3">
          {/* Search */}
          <form method="GET" action="/admin/accessories" className="flex-1 flex gap-2">
            {series && <input type="hidden" name="series" value={series} />}
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
              <input
                type="text"
                name="q"
                defaultValue={query}
                placeholder="Search by code or name…"
                className="w-full pl-9 pr-4 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-gray-50"
              />
            </div>
            <button
              type="submit"
              className="px-4 py-2 text-sm font-semibold bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors"
            >
              Search
            </button>
            {(query || series) && (
              <Link
                href="/admin/accessories"
                className="px-4 py-2 text-sm font-semibold text-gray-600 bg-gray-100 rounded-xl hover:bg-gray-200 transition-colors whitespace-nowrap"
              >
                Clear
              </Link>
            )}
          </form>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-6xl mx-auto px-4 md:px-8 py-6 md:py-8 space-y-6 md:space-y-10">
        {accessories.length === 0 && (
          <div className="bg-white rounded-2xl border border-gray-200 p-16 text-center">
            <Tag className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h3 className="font-semibold text-gray-700">
              {query || series ? "No accessories match your search" : "No accessories yet"}
            </h3>
            <p className="text-sm text-gray-400 mt-1 mb-6">
              {query || series
                ? "Try adjusting your search terms or filters."
                : "Add your first hardware item to get started."}
            </p>
            {!query && !series && (
              <Link
                href="/admin/accessories/new"
                className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl transition-colors"
              >
                <PlusCircle className="w-4 h-4" /> Add First Accessory
              </Link>
            )}
          </div>
        )}

        {accessories.length > 0 && (
          <div className="w-full bg-white rounded-lg shadow-sm overflow-hidden">
            <div className="w-full max-w-full overflow-x-auto">
              <table className="w-full text-sm min-w-[800px] text-left border-collapse">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50/70">
                    <th className="text-left py-3 pl-6 pr-4 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap">
                      Code
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide min-w-[150px] sm:min-w-[200px] whitespace-nowrap">
                      Name
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap hidden lg:table-cell">
                      ซีรีส์
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap hidden md:table-cell">
                      Unit
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                      <span className="flex items-center gap-1.5">
                        <Palette className="w-3.5 h-3.5" /> Pricing (THB)
                      </span>
                    </th>
                    <th className="w-[150px] min-w-[150px] whitespace-nowrap text-right py-3 pl-4 pr-8 font-semibold text-gray-500 text-xs uppercase tracking-wide">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {accessories.map((acc) => (
                    <tr
                      key={acc.id}
                      id={`accessory-${acc.id}`}
                      className={`scroll-mt-24 hover:bg-gray-50/60 transition-colors duration-500 ${!acc.isActive ? "opacity-50" : ""}`}
                    >
                      {/* Code */}
                      <td className="align-top py-4 pl-6 pr-4 whitespace-nowrap">
                        <span className="font-mono text-xs font-semibold text-blue-600 bg-blue-50 px-2 py-1 rounded-lg">
                          {acc.code}
                        </span>
                      </td>

                      {/* Name */}
                      <td className="align-top p-4 min-w-[150px] sm:min-w-[200px] whitespace-nowrap">
                        <p className="font-medium text-gray-900">{acc.name}</p>
                        {acc.description && (
                          <p className="text-xs text-gray-400 mt-0.5 truncate max-w-[150px] sm:max-w-[200px] md:max-w-xs">
                            {acc.description}
                          </p>
                        )}
                        {!acc.isActive && (
                          <span className="inline-block mt-1 text-xs text-red-500 bg-red-50 px-2 py-0.5 rounded-full">
                            Inactive
                          </span>
                        )}
                      </td>

                      {/* Series badge */}
                      <td className="align-top p-4 whitespace-nowrap hidden lg:table-cell">
                        <SeriesBadge series={acc.series} />
                      </td>

                      {/* Unit */}
                      <td className="align-top p-4 whitespace-nowrap hidden md:table-cell">
                        <span className="text-gray-600">{acc.unit}</span>
                      </td>

                      {/* Variants */}
                      <td className="align-top p-4">
                        <div className="flex flex-row flex-wrap items-center gap-1.5">
                          {acc.variants.map((v) => (
                            <div
                              key={v.id}
                              title={v.color.name}
                              className="inline-flex items-center w-max gap-1.5 bg-white border border-slate-200 rounded-md px-2 py-1 text-xs shadow-sm whitespace-nowrap cursor-help"
                            >
                              {v.color.hexCode && (
                                <span
                                  className="w-3 h-3 rounded-full border border-slate-300 shrink-0"
                                  style={{ backgroundColor: v.color.hexCode }}
                                />
                              )}
                              <span className="font-semibold text-slate-900">
                                ฿{v.unitCost.toLocaleString()}
                              </span>
                            </div>
                          ))}
                          {acc.variants.length === 0 && (
                            <span className="text-gray-400 italic text-xs">No variants</span>
                          )}
                        </div>
                      </td>

                      {/* Actions */}
                      <td className="align-top py-4 pl-4 pr-8 text-right whitespace-nowrap w-[150px] min-w-[150px]">
                        <AccessoryActions 
                          accessory={{
                            id: acc.id,
                            code: acc.code,
                            name: acc.name,
                            series: acc.series,
                            variants: acc.variants.map(v => ({
                              id: v.id,
                              colorName: v.color.name,
                              unitCost: v.unitCost,
                            })),
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
              Showing{" "}
              <span className="font-semibold text-gray-800">
                {((page - 1) * PAGE_SIZE + 1).toLocaleString()}–
                {Math.min(page * PAGE_SIZE, total).toLocaleString()}
              </span>{" "}
              of <span className="font-semibold text-gray-800">{total.toLocaleString()}</span>
            </p>

            <div className="flex items-center gap-2">
              {/* Previous */}
              {page > 1 ? (
                <Link
                  href={buildUrl({ page: page - 1 })}
                  className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors"
                >
                  <ChevronLeft className="w-4 h-4" /> Previous
                </Link>
              ) : (
                <span className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-300 bg-gray-50 rounded-xl cursor-not-allowed">
                  <ChevronLeft className="w-4 h-4" /> Previous
                </span>
              )}

              {/* Page indicator */}
              <span className="text-sm text-gray-500 px-2">
                Page{" "}
                <span className="font-bold text-gray-800">{page}</span>
                {" "}/ {totalPages}
              </span>

              {/* Next */}
              {page < totalPages ? (
                <Link
                  href={buildUrl({ page: page + 1 })}
                  className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors"
                >
                  Next <ChevronRight className="w-4 h-4" />
                </Link>
              ) : (
                <span className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-300 bg-gray-50 rounded-xl cursor-not-allowed">
                  Next <ChevronRight className="w-4 h-4" />
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

