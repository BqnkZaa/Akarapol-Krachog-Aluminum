"use client";

import { useState, useTransition } from "react";
import { X, ArrowRightLeft, AlertTriangle } from "lucide-react";
import { moveMaterialToAccessory } from "@/actions/admin";

interface Variant {
  id: string;
  colorName: string;
  unitCost: number;
}

interface MoveMaterialModalProps {
  material: {
    id: string;
    code: string;
    name: string;
    variants: Variant[];
  };
  onClose: () => void;
}

// The official categories/series matching Sidebar.tsx collapsible groups and filter badges
const ACCESSORY_SERIES = [
  { value: "ชุดบานเลื่อน", label: "อุปกรณ์บานเลื่อน" },
  { value: "ชุดบานเปิด, บานกระทุ้ง", label: "อุปกรณ์บานเปิด / บานกระทุ้ง" },
  { value: "ชุดบานเฟี้ยม", label: "อุปกรณ์บานเฟี้ยม" },
  { value: "ชุดท้องตลาด", label: "อุปกรณ์ชุดท้องตลาด" },
  { value: "ชุดบานเปลือย", label: "อุปกรณ์บานเปลือย" },
];

export default function MoveMaterialModal({ material, onClose }: MoveMaterialModalProps) {
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [targetSeries, setTargetSeries] = useState(ACCESSORY_SERIES[0].value);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!confirm(`คุณแน่ใจหรือไม่ว่าต้องการย้าย "${material.name}" ไปเป็นอุปกรณ์เสริม? การดำเนินการนี้จะลบข้อมูลจากตารางโปรไฟล์เส้นอลูมิเนียมและไปสร้างใหม่ในตารางอุปกรณ์เสริมโดยสมบูรณ์`)) {
      return;
    }

    startTransition(async () => {
      const res = await moveMaterialToAccessory(material.id, targetSeries);
      if (!res.success) {
        setError(res.error || "เกิดข้อผิดพลาดในการย้ายข้อมูล");
      } else {
        alert("ย้ายข้อมูลไปยังหมวดหมู่อุปกรณ์เสริมสำเร็จแล้ว!");
        onClose();
      }
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-2 text-blue-600">
            <ArrowRightLeft className="w-5 h-5" />
            <h2 className="text-lg font-bold text-gray-900">ย้ายไปอุปกรณ์เสริม</h2>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="overflow-y-auto p-6 space-y-5">
          {error && (
            <div className="p-4 bg-red-50 border border-red-100 rounded-xl flex items-start gap-3">
              <AlertTriangle className="w-5 h-5 text-red-600 shrink-0 mt-0.5" />
              <p className="text-sm text-red-800 font-medium">{error}</p>
            </div>
          )}

          {/* Warning Card */}
          <div className="p-4 bg-amber-50 border border-amber-100 rounded-xl flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
            <div className="text-xs text-amber-800 space-y-1">
              <p className="font-bold">โปรดทราบก่อนทำรายการ:</p>
              <p>ระบบจะย้ายข้อมูลชื่อ รหัส หน่วย รากฐานราคาสต็อก และค่าจัดกลุ่มสีทั้งหมดไปยังระบบอุปกรณ์เสริม และลบรายการจากตารางเส้นอลูมิเนียมนี้</p>
              <p className="font-semibold text-red-600 mt-1">
                ⚠️ การย้ายจะไม่สามารถทำได้หากรายการนี้ถูกนำไปใช้งานในการออกแบบ รูปแบบงาน (BOM) หรือใบเสนอราคาที่มีอยู่ในระบบ
              </p>
            </div>
          </div>

          <form id="move-material-form" onSubmit={handleSubmit} className="space-y-4">
            <div>
              <span className="block text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">
                รายการที่กำลังจะย้าย
              </span>
              <p className="font-bold text-gray-900 text-sm">{material.name}</p>
              <span className="font-mono text-xs text-blue-600 bg-blue-50 px-2 py-0.5 rounded-md mt-1 inline-block">
                {material.code}
              </span>
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                เลือกหมวดหมู่อุปกรณ์เสริมปลายทาง (Accessory Category)
              </label>
              <select
                value={targetSeries}
                onChange={(e) => setTargetSeries(e.target.value)}
                required
                className="w-full px-4 py-2.5 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 bg-gray-50 font-medium"
              >
                {ACCESSORY_SERIES.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>
          </form>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-gray-100 bg-gray-50 flex justify-end gap-3">
          <button
            type="button"
            onClick={onClose}
            disabled={isPending}
            className="px-5 py-2.5 text-sm font-semibold text-gray-600 bg-white border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors disabled:opacity-50"
          >
            ยกเลิก
          </button>
          <button
            type="submit"
            form="move-material-form"
            disabled={isPending}
            className="inline-flex items-center gap-2 px-5 py-2.5 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-xl shadow-sm transition-colors disabled:opacity-50"
          >
            <ArrowRightLeft className="w-4 h-4" />
            {isPending ? "กำลังย้ายข้อมูล..." : "ยืนยันการย้ายข้อมูล"}
          </button>
        </div>
      </div>
    </div>
  );
}
