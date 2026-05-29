"use client";

import { useState, useEffect, useTransition } from "react";
import { X, ArrowRightLeft, AlertTriangle, Loader2 } from "lucide-react";
import { moveAccessoryToMaterial } from "@/actions/admin";
import { getCategories, CategoryDTO } from "@/actions/category";

interface Variant {
  id: string;
  colorName: string;
  unitCost: number;
}

interface MoveAccessoryModalProps {
  accessory: {
    id: string;
    code: string;
    name: string;
    variants: Variant[];
  };
  onClose: () => void;
}

export default function MoveAccessoryModal({ accessory, onClose }: MoveAccessoryModalProps) {
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [categories, setCategories] = useState<CategoryDTO[]>([]);
  const [isLoadingCategories, setIsLoadingCategories] = useState(true);
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>("");

  useEffect(() => {
    async function loadCategories() {
      try {
        const cats = await getCategories();
        // filter only active ones
        const activeCats = cats.filter(c => c.isActive);
        setCategories(activeCats);
        if (activeCats.length > 0) {
          setSelectedCategoryId(activeCats[0].id);
        }
      } catch (err) {
        console.error("Failed to load categories:", err);
        setError("ไม่สามารถโหลดข้อมูลหมวดหมู่เส้นอลูมิเนียมได้");
      } finally {
        setIsLoadingCategories(false);
      }
    }

    loadCategories();
  }, []);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!selectedCategoryId) {
      setError("กรุณาเลือกหมวดหมู่ปลายทาง");
      return;
    }

    const targetCategory = categories.find((c) => c.id === selectedCategoryId);
    const categoryName = targetCategory ? targetCategory.name : "เส้นอลูมิเนียม";

    if (
      !confirm(
        `คุณแน่ใจหรือไม่ว่าต้องการย้าย "${accessory.name}" ไปเป็นเส้นอลูมิเนียม (${categoryName})? การดำเนินการนี้จะลบข้อมูลจากตารางอุปกรณ์เสริมและไปสร้างใหม่ในตารางเส้นอลูมิเนียมโดยสมบูรณ์`
      )
    ) {
      return;
    }

    startTransition(async () => {
      const res = await moveAccessoryToMaterial(accessory.id, selectedCategoryId);
      if (!res.success) {
        setError(res.error || "เกิดข้อผิดพลาดในการย้ายข้อมูล");
      } else {
        alert("ย้ายข้อมูลไปยังหมวดหมู่เส้นอลูมิเนียมสำเร็จแล้ว!");
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
            <h2 className="text-lg font-bold text-gray-900">ย้ายไปเส้นอลูมิเนียม</h2>
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
              <p>ระบบจะย้ายข้อมูลชื่อ รหัส หน่วย รากฐานราคาสต็อก และค่าจัดกลุ่มสีทั้งหมดไปยังระบบเส้นอลูมิเนียม และลบรายการจากตารางอุปกรณ์เสริมนี้</p>
              <p className="font-semibold text-red-600 mt-1">
                ⚠️ การย้ายจะไม่สามารถทำได้หากรายการนี้ถูกนำไปใช้งานในระบบที่มีการอ้างอิงเชิงสัมพันธ์
              </p>
            </div>
          </div>

          <form id="move-accessory-form" onSubmit={handleSubmit} className="space-y-4">
            <div>
              <span className="block text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">
                รายการที่กำลังจะย้าย
              </span>
              <p className="font-bold text-gray-900 text-sm">{accessory.name}</p>
              <span className="font-mono text-xs text-blue-600 bg-blue-50 px-2 py-0.5 rounded-md mt-1 inline-block">
                {accessory.code}
              </span>
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                เลือกซีรีส์เส้นอลูมิเนียมปลายทาง (Aluminum Profile Category)
              </label>
              {isLoadingCategories ? (
                <div className="flex items-center gap-2 text-sm text-gray-500 py-2.5">
                  <Loader2 className="w-4 h-4 animate-spin text-blue-600" />
                  <span>กำลังโหลดหมวดหมู่...</span>
                </div>
              ) : (
                <select
                  value={selectedCategoryId}
                  onChange={(e) => setSelectedCategoryId(e.target.value)}
                  required
                  className="w-full px-4 py-2.5 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 bg-gray-50 font-medium"
                >
                  {categories.length === 0 ? (
                    <option value="">-- ไม่มีหมวดหมู่ที่ใช้งานได้ --</option>
                  ) : (
                    categories.map((opt) => (
                      <option key={opt.id} value={opt.id}>
                        {opt.name}
                      </option>
                    ))
                  )}
                </select>
              )}
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
            form="move-accessory-form"
            disabled={isPending || isLoadingCategories || !selectedCategoryId}
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
