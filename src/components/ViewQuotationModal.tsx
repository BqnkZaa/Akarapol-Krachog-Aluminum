"use client";

import { useEffect, useState, useTransition } from "react";
import {
  X, Loader2, Calculator, Box, Ruler, Palette, LayoutTemplate, Printer, AlertCircle, FileText, Calendar
} from "lucide-react";
import { getQuotationById } from "@/actions/quotation";

interface ViewQuotationModalProps {
  isOpen: boolean;
  onClose: () => void;
  quotationId: string | null;
}

export default function ViewQuotationModal({ isOpen, onClose, quotationId }: ViewQuotationModalProps) {
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    if (!isOpen || !quotationId) {
      setData(null);
      setError(null);
      return;
    }

    startTransition(async () => {
      try {
        const res = await getQuotationById(quotationId);
        if (res) {
          setData(res);
        } else {
          setError("ไม่พบข้อมูลใบเสนอราคานี้");
        }
      } catch (err) {
        console.error(err);
        setError("เกิดข้อผิดพลาดในการดึงข้อมูล");
      }
    });
  }, [isOpen, quotationId]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity duration-300"
        onClick={onClose}
      />

      {/* Modal Card */}
      <div className="relative bg-white rounded-2xl shadow-2xl max-w-5xl w-full max-h-[90vh] flex flex-col overflow-hidden transition-all animate-in fade-in zoom-in-95 duration-200 z-10">
        
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100 bg-gray-50/50">
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center">
              <FileText className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-gray-900 leading-tight">
                {data ? data.projectName : "รายละเอียดใบเสนอราคา"}
              </h2>
              {data && (
                <p className="text-xs text-gray-400 font-mono mt-0.5">
                  ID: {data.id.toUpperCase()}
                </p>
              )}
            </div>
          </div>
          <button 
            onClick={onClose}
            className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors text-gray-400 hover:text-gray-600"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto p-6 md:p-8 space-y-8 min-h-[300px]">
          {isPending ? (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-white/80 z-20">
              <Loader2 className="w-8 h-8 text-blue-600 animate-spin mb-2" />
              <p className="text-sm font-semibold text-gray-600">กำลังโหลดรายละเอียดใบเสนอราคา...</p>
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <AlertCircle className="w-12 h-12 text-red-500 mb-3" />
              <h3 className="font-bold text-gray-800 text-lg">เกิดข้อผิดพลาด</h3>
              <p className="text-sm text-gray-500 mt-1">{error}</p>
            </div>
          ) : !data ? (
            <div className="flex flex-col items-center justify-center py-12 text-center text-gray-400">
              <Loader2 className="w-8 h-8 animate-spin mb-2" />
              <p>กำลังเตรียมข้อมูล...</p>
            </div>
          ) : (
            <div className="space-y-8 animate-in fade-in duration-300">
              {/* Top Overview Section */}
              <div className="bg-blue-50/40 rounded-2xl p-6 border border-blue-100/50 grid grid-cols-2 md:grid-cols-4 gap-6 text-sm">
                <div>
                  <p className="text-gray-400 text-xs font-semibold uppercase tracking-wider mb-1 flex items-center gap-1.5">
                    <LayoutTemplate className="w-3.5 h-3.5" /> รูปแบบงาน
                  </p>
                  <p className="font-bold text-gray-800 leading-tight">{data.template.name}</p>
                </div>
                <div>
                  <p className="text-gray-400 text-xs font-semibold uppercase tracking-wider mb-1 flex items-center gap-1.5">
                    <Palette className="w-3.5 h-3.5" /> สีอลูมิเนียม
                  </p>
                  <p className="font-bold text-gray-800 flex items-center gap-2">
                    <span 
                      className="w-3.5 h-3.5 rounded-full border border-gray-200 shrink-0" 
                      style={{ backgroundColor: data.color.hexCode || '#fff' }} 
                    />
                    {data.color.name}
                  </p>
                </div>
                <div>
                  <p className="text-gray-400 text-xs font-semibold uppercase tracking-wider mb-1 flex items-center gap-1.5">
                    <Ruler className="w-3.5 h-3.5" /> ขนาด (กว้าง × สูง)
                  </p>
                  <p className="font-bold text-gray-800">
                    {(data.widthMm / 10).toLocaleString()} × {(data.heightMm / 10).toLocaleString()} ซม.
                  </p>
                </div>
                <div>
                  <p className="text-gray-400 text-xs font-semibold uppercase tracking-wider mb-1 flex items-center gap-1.5">
                    <Calendar className="w-3.5 h-3.5" /> วันที่เสนอราคา
                  </p>
                  <p className="font-bold text-gray-800">
                    {new Date(data.createdAt).toLocaleDateString("th-TH", {
                      year: "numeric",
                      month: "long",
                      day: "numeric"
                    })}
                  </p>
                </div>
                
                {data.customerName && (
                  <div className="col-span-full border-t border-blue-100/30 pt-4 flex flex-wrap gap-x-8 gap-y-2 text-xs">
                    <p className="text-gray-600">
                      <span className="font-semibold text-gray-500">ลูกค้า:</span> {data.customerName}
                    </p>
                    {data.customerPhone && (
                      <p className="text-gray-600">
                        <span className="font-semibold text-gray-500">เบอร์โทร:</span> {data.customerPhone}
                      </p>
                    )}
                    {data.customerAddress && (
                      <p className="text-gray-600 col-span-full">
                        <span className="font-semibold text-gray-500">ที่อยู่:</span> {data.customerAddress}
                      </p>
                    )}
                  </div>
                )}
              </div>

              {/* Component Breakdown */}
              {data.components && data.components.length > 0 && (
                <div className="bg-white rounded-2xl border border-gray-200 p-5">
                  <h3 className="font-bold text-gray-900 mb-4 pb-2 border-b border-gray-100 flex items-center gap-2">
                    <Ruler className="w-4 h-4 text-blue-500" /> รายการชิ้นส่วนและระยะตัด
                  </h3>
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm text-left">
                      <thead>
                        <tr className="text-xs text-gray-400 border-b border-gray-150 bg-gray-50/50">
                          <th className="py-2.5 px-3 font-semibold">ชิ้นส่วน (Component)</th>
                          <th className="py-2.5 px-3 font-semibold">โปรไฟล์วัสดุ</th>
                          <th className="py-2.5 px-3 font-semibold text-center">สูตรคำนวณ</th>
                          <th className="py-2.5 px-3 font-semibold text-right">ความยาวที่ตัด</th>
                          <th className="py-2.5 px-3 font-semibold text-right">จำนวน</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-gray-100">
                        {data.components.map((comp: any, idx: number) => (
                          <tr key={idx} className="hover:bg-gray-50/30 transition-colors">
                            <td className="py-3 px-3 font-medium text-gray-800">{comp.label}</td>
                            <td className="py-3 px-3 text-xs font-mono text-gray-500">
                              {comp.materialCode} — {comp.materialName}
                            </td>
                            <td className="py-3 px-3 text-center text-xs font-mono text-gray-400 bg-gray-50/30 rounded-md">
                              {comp.formula}
                            </td>
                            <td className="py-3 px-3 text-right font-semibold text-gray-800">
                              {(comp.lengthMm / 10).toFixed(1)} ซม.
                            </td>
                            <td className="py-3 px-3 text-right font-medium text-gray-600">
                              {comp.quantity} ชิ้น
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* 1D Cutting Optimization results */}
              {data.cuttingResults && data.cuttingResults.length > 0 && (
                <div className="bg-white rounded-2xl border border-gray-200 p-5 space-y-5">
                  <h3 className="font-bold text-gray-900 pb-2 border-b border-gray-100 flex items-center gap-2">
                    <Box className="w-4 h-4 text-blue-500" /> แผนการจัดเรียงการตัดวัสดุ (1D Cutting Plan)
                  </h3>
                  <div className="space-y-6">
                    {data.cuttingResults.map((cr: any, idx: number) => (
                      <div key={`${cr.materialId}-${idx}`} className="border border-gray-250 rounded-xl p-4 md:p-5 bg-gray-50/30">
                        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2 mb-4">
                          <div>
                            <h4 className="font-bold text-gray-800">{cr.materialName}</h4>
                            <p className="text-xs text-gray-400 font-mono">
                              รหัส: {cr.materialCode} • ขนาดเส้นหลัก: {(cr.barLengthMm / 10).toLocaleString()} ซม.
                            </p>
                          </div>
                          <div className="text-left sm:text-right">
                            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-blue-50 text-blue-700">
                              ใช้ {cr.barsRequired} เส้น
                            </span>
                            <span className="ml-2 text-xs text-gray-400">
                              ประสิทธิภาพ {cr.utilizationPercent.toFixed(1)}%
                            </span>
                          </div>
                        </div>

                        {/* Bar visualizations */}
                        <div className="space-y-3.5">
                          {cr.bars.map((bar: any) => (
                            <div key={bar.barIndex} className="relative">
                              <div className="flex items-center justify-between text-xs text-gray-400 mb-1">
                                <span className="font-semibold">เส้นที่ #{bar.barIndex}</span>
                                <span>เศษที่เหลือ: {(bar.wasteMm / 10).toFixed(1)} ซม.</span>
                              </div>
                              <div className="h-7 bg-gray-100 rounded-lg overflow-hidden flex border border-gray-200 w-full relative">
                                {bar.cuts.map((cut: any, idx: number) => {
                                  const pct = (cut.lengthMm / cr.barLengthMm) * 100;
                                  const colors = ['bg-blue-500', 'bg-emerald-500', 'bg-purple-500', 'bg-orange-500', 'bg-pink-500', 'bg-indigo-500'];
                                  const colorClass = colors[cut.label.length % colors.length];

                                  return (
                                    <div
                                      key={idx}
                                      style={{ width: `${pct}%` }}
                                      className={`${colorClass} h-full border-r border-white/30 flex items-center justify-center text-[10px] text-white font-bold px-1 overflow-hidden whitespace-nowrap`}
                                      title={`${cut.label}: ${(cut.lengthMm / 10).toFixed(1)} ซม.`}
                                    >
                                      {(cut.lengthMm / 10).toFixed(1)}
                                    </div>
                                  );
                                })}
                                {bar.wasteMm > 0 && (
                                  <div
                                    style={{ width: `${(bar.wasteMm / cr.barLengthMm) * 100}%` }}
                                    className="bg-stripes h-full opacity-35"
                                  />
                                )}
                              </div>
                              <div className="flex flex-wrap gap-x-3 gap-y-1 mt-1 text-[11px] text-gray-500">
                                {bar.cuts.map((cut: any, idx: number) => (
                                  <span key={idx}>
                                    <span className="font-medium text-gray-800">{(cut.lengthMm / 10).toFixed(1)} ซม.</span>{" "}
                                    <span className="text-gray-400">({cut.label})</span>
                                  </span>
                                ))}
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Glass & Accessories Side-by-side */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Glass detail */}
                {data.glassDetail && (
                  <div className="bg-white rounded-2xl border border-gray-200 p-5">
                    <h3 className="font-bold text-gray-900 mb-4 pb-2 border-b border-gray-100 flex items-center gap-2">
                      <LayoutTemplate className="w-4 h-4 text-blue-500" /> รายละเอียดกระจก
                    </h3>
                    <p className="font-bold text-gray-800 text-sm">{data.glassDetail.glassType}</p>
                    <div className="space-y-2 mt-4 text-xs text-gray-600">
                      <div className="flex justify-between">
                        <span>ขนาดต่อบาน</span>
                        <span className="font-semibold text-gray-800">
                          {(data.glassDetail.widthPerPanelMm / 10).toFixed(1)} × {(data.glassDetail.heightPerPanelMm / 10).toFixed(1)} ซม.
                        </span>
                      </div>
                      <div className="flex justify-between">
                        <span>จำนวนบาน</span>
                        <span className="font-semibold text-gray-800">{data.glassDetail.panelCount} บาน</span>
                      </div>
                      <div className="flex justify-between">
                        <span>พื้นที่รวม (Sq.Ft)</span>
                        <span className="font-semibold text-gray-800">{data.glassDetail.areaSqFt.toFixed(4)} ตร.ฟุต</span>
                      </div>
                      <div className="flex justify-between font-bold text-blue-600 text-sm border-t border-gray-100 pt-2 mt-2">
                        <span>ค่ากระจก</span>
                        <span>฿{data.glassCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                      </div>
                    </div>
                  </div>
                )}

                {/* Accessories detail */}
                {data.accessories && data.accessories.length > 0 && (
                  <div className="bg-white rounded-2xl border border-gray-200 p-5">
                    <h3 className="font-bold text-gray-900 mb-4 pb-2 border-b border-gray-100 flex items-center gap-2">
                      <Box className="w-4 h-4 text-blue-500" /> อุปกรณ์เสริมติดตั้ง
                    </h3>
                    <div className="space-y-3.5 max-h-[160px] overflow-y-auto pr-1">
                      {data.accessories.map((acc: any, idx: number) => (
                        <div key={idx} className="flex justify-between items-center text-xs text-gray-600">
                          <span>{acc.name}</span>
                          <div className="text-right">
                            <span className="text-gray-400 mr-2.5">{acc.quantity} {acc.unit}</span>
                            <span className="font-semibold text-gray-800">฿{acc.lineCost.toLocaleString()}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                    <div className="flex justify-between font-bold text-blue-600 text-sm border-t border-gray-100 pt-2.5 mt-3">
                      <span>ค่าอุปกรณ์เสริมรวม</span>
                      <span>฿{data.accessoryCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                    </div>
                  </div>
                )}
              </div>

              {/* Pricing breakdown summary */}
              <div className="bg-gray-900 rounded-2xl p-6 md:p-8 text-white relative overflow-hidden">
                <div className="absolute inset-0 bg-gradient-to-br from-blue-600/10 to-transparent pointer-events-none" />
                <h3 className="font-bold text-base mb-6 flex items-center gap-2 text-white/90">
                  <Calculator className="w-4 h-4 text-blue-400" /> รายละเอียดการประเมินราคาสุทธิ
                </h3>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-8 text-sm">
                  {/* Detailed lines */}
                  <div className="space-y-3.5 text-gray-400 font-medium">
                    <div className="flex justify-between">
                      <span>อลูมิเนียม ({data.totalBarsUsed} เส้น)</span>
                      <span className="text-white">฿{data.materialCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                    </div>
                    {data.glassCost > 0 && (
                      <div className="flex justify-between">
                        <span>ค่ากระจก</span>
                        <span className="text-white">฿{data.glassCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                      </div>
                    )}
                    {data.accessoryCost > 0 && (
                      <div className="flex justify-between">
                        <span>อุปกรณ์เสริม</span>
                        <span className="text-white">฿{data.accessoryCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                      </div>
                    )}
                    <div className="h-px bg-gray-800 my-2" />
                    <div className="flex justify-between text-white font-semibold">
                      <span>ราคารวมต้นทุน</span>
                      <span>฿{data.summary.subtotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                    </div>
                  </div>

                  {/* Profit markup & labor & final */}
                  <div className="space-y-3.5 text-gray-400 font-medium flex flex-col justify-between">
                    <div className="space-y-3.5">
                      <div className="flex justify-between text-blue-300">
                        <span>กำไร (+{data.profitMarginPercent}%)</span>
                        <span>฿{data.summary.marginAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                      </div>
                      <div className="flex justify-between text-emerald-300">
                        <span>ค่าแรงติดตั้ง</span>
                        <span>฿{data.laborCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                      </div>
                      {data.additionalCost > 0 && (
                        <div className="flex justify-between text-white/90">
                          <span>ค่าใช้จ่ายเพิ่มเติม</span>
                          <span>฿{data.additionalCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                        </div>
                      )}
                      {data.discountPercent > 0 && (
                        <div className="flex justify-between text-red-400 border-t border-gray-800 pt-2.5">
                          <span>ส่วนลด (-{data.discountPercent}%)</span>
                          <span>-฿{data.summary.discountAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                        </div>
                      )}
                    </div>

                    <div className="flex justify-between items-end pt-4 border-t border-gray-800 mt-2 flex-wrap gap-2">
                      <span className="text-gray-400 font-bold">ราคาสุทธิเสนอราคา</span>
                      <span className="text-3xl font-extrabold text-blue-400 tracking-tight leading-none">
                        ฿{data.summary.finalPrice.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="px-6 py-4 bg-gray-50 border-t border-gray-100 flex items-center justify-end gap-3 z-10">
          <button
            onClick={onClose}
            className="px-4.5 py-2.5 border border-gray-200 hover:bg-gray-100 text-gray-700 text-sm font-semibold rounded-xl transition-all"
          >
            ปิดหน้าต่าง
          </button>
          {data && (
            <button
              onClick={() => {
                window.print();
              }}
              className="px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl transition-all shadow-sm flex items-center gap-2"
            >
              <Printer className="w-4 h-4" /> พิมพ์ใบเสนอราคา / PDF
            </button>
          )}
        </div>

      </div>
    </div>
  );
}
