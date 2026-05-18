import Link from "next/link";
import { ChevronLeft, ChevronRight, FileText } from "lucide-react";
import { getQuotations } from "@/actions/quotation";
import QuotationActions from "@/components/QuotationActions";

export const dynamic = "force-dynamic";

export const metadata = {
  title: "ประวัติใบเสนอราคา — SmartQuote",
};

interface PageProps {
  searchParams: Promise<{ page?: string }>;
}

export default async function QuotationsPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const page = Math.max(1, parseInt(params.page ?? "1", 10));

  const { items, total, totalPages } = await getQuotations(page);

  function buildUrl(pageNumber: number) {
    const p = new URLSearchParams();
    p.set("page", String(pageNumber));
    return `/quotations?${p.toString()}`;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Page Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-6xl mx-auto px-6 py-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">ประวัติใบเสนอราคา</h1>
            <p className="text-sm text-gray-500 mt-0.5">
              จัดการและดูประวัติใบเสนอราคาย้อนหลัง
            </p>
          </div>
          <Link
            href="/"
            className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl shadow-sm transition-colors"
          >
            สร้างใบเสนอราคาใหม่
          </Link>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-8 space-y-8">
        {items.length === 0 ? (
          <div className="bg-white rounded-2xl border border-gray-200 p-16 text-center shadow-sm">
            <FileText className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h3 className="font-semibold text-gray-700">ไม่พบประวัติใบเสนอราคา</h3>
            <p className="text-sm text-gray-400 mt-1 mb-6">
              คุณยังไม่เคยสร้างใบเสนอราคาใดๆ ในระบบ
            </p>
            <Link
              href="/"
              className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-5 py-2.5 rounded-xl transition-colors"
            >
              สร้างใบเสนอราคาใหม่
            </Link>
          </div>
        ) : (
          <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50/70">
                    <th className="text-left py-3 px-4 sm:px-5 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap">
                      วันที่
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap">
                      เลขที่เอกสาร
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide min-w-[150px]">
                      ชื่อลูกค้า / ชื่อโปรเจกต์
                    </th>
                    <th className="text-left py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide min-w-[150px]">
                      รูปแบบงาน
                    </th>
                    <th className="text-right py-3 px-4 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap">
                      ยอดรวมสุทธิ
                    </th>
                    <th className="text-right py-3 px-4 sm:px-5 font-semibold text-gray-500 text-xs uppercase tracking-wide whitespace-nowrap">
                      จัดการ
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {items.map((item) => (
                    <tr key={item.id} className="hover:bg-gray-50/60 transition-colors">
                      {/* Date */}
                      <td className="py-4 px-4 sm:px-5 whitespace-nowrap">
                        <span className="text-gray-600">
                          {item.createdAt.toLocaleDateString("th-TH", {
                            year: "numeric",
                            month: "short",
                            day: "numeric",
                          })}
                        </span>
                      </td>

                      {/* ID */}
                      <td className="py-4 px-4 whitespace-nowrap">
                        <span className="font-mono text-xs font-semibold text-gray-500 bg-gray-100 px-2 py-1 rounded-md">
                          {item.id.slice(-6).toUpperCase()}
                        </span>
                      </td>

                      {/* Customer / Project */}
                      <td className="py-4 px-4 min-w-[150px]">
                        <p className="font-medium text-gray-900">{item.projectName}</p>
                        {item.customerName && (
                          <p className="text-xs text-gray-500 mt-0.5">{item.customerName}</p>
                        )}
                      </td>

                      {/* Template */}
                      <td className="py-4 px-4 min-w-[150px]">
                        <span className="inline-flex items-center text-xs font-medium text-blue-700 bg-blue-50 px-2.5 py-1 rounded-md">
                          {item.templateName}
                        </span>
                      </td>

                      {/* Total Amount */}
                      <td className="py-4 px-4 text-right whitespace-nowrap">
                        <span className="font-bold text-gray-900">
                          ฿{item.finalPrice.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </span>
                      </td>

                      {/* Actions */}
                      <td className="py-4 px-5 text-right whitespace-nowrap">
                        <QuotationActions quotationId={item.id} />
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
              หน้า <span className="font-semibold text-gray-800">{page}</span> จาก <span className="font-semibold text-gray-800">{totalPages}</span>
              {" "} (ทั้งหมด {total} รายการ)
            </p>

            <div className="flex items-center gap-2">
              {/* Previous */}
              {page > 1 ? (
                <Link
                  href={buildUrl(page - 1)}
                  className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors"
                >
                  <ChevronLeft className="w-4 h-4" /> ก่อนหน้า
                </Link>
              ) : (
                <span className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-semibold text-gray-300 bg-gray-50 rounded-xl cursor-not-allowed">
                  <ChevronLeft className="w-4 h-4" /> ก่อนหน้า
                </span>
              )}

              {/* Next */}
              {page < totalPages ? (
                <Link
                  href={buildUrl(page + 1)}
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
      </div>
    </div>
  );
}
