"use client";

import { useState, useTransition } from "react";
import { X, Save, AlertCircle } from "lucide-react";
import { updateMaterial } from "@/actions/admin";

interface Variant {
  id: string;
  colorName: string;
  unitCost: number;
}

interface EditMaterialModalProps {
  material: {
    id: string;
    code: string;
    name: string;
    variants: Variant[];
  };
  onClose: () => void;
}

export default function EditMaterialModal({ material, onClose }: EditMaterialModalProps) {
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  // Form state
  const [code, setCode] = useState(material.code);
  const [name, setName] = useState(material.name);
  const [variants, setVariants] = useState(
    material.variants.map((v) => ({ ...v, unitCost: v.unitCost.toString() }))
  );

  const handleVariantChange = (index: number, newCostStr: string) => {
    const updated = [...variants];
    updated[index].unitCost = newCostStr;
    setVariants(updated);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    startTransition(async () => {
      const payload = {
        id: material.id,
        code,
        name,
        variants: variants.map((v) => ({
          id: v.id,
          unitCost: parseFloat(v.unitCost) || 0,
        })),
      };

      const res = await updateMaterial(payload);
      if (!res.success) {
        setError(res.error || "Failed to update material.");
      } else {
        onClose();
      }
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 className="text-lg font-bold text-gray-900">แก้ไขเส้นอลูมิเนียม</h2>
          <button
            onClick={onClose}
            className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="overflow-y-auto p-6">
          {error && (
            <div className="mb-6 p-4 bg-red-50 border border-red-100 rounded-xl flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-red-600 shrink-0 mt-0.5" />
              <p className="text-sm text-red-800">{error}</p>
            </div>
          )}

          <form id="edit-material-form" onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                รหัสเส้นอลูมิเนียม
              </label>
              <input
                type="text"
                required
                value={code}
                onChange={(e) => setCode(e.target.value)}
                className="w-full px-4 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 bg-gray-50"
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                ชื่อเส้นอลูมิเนียม
              </label>
              <input
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full px-4 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 bg-gray-50"
              />
            </div>

            {variants.length > 0 && (
              <div className="pt-2">
                <label className="block text-sm font-semibold text-gray-700 mb-3">
                  ราคาย่อยตามสี (฿)
                </label>
                <div className="space-y-3">
                  {variants.map((v, idx) => (
                    <div
                      key={v.id}
                      className="flex items-center justify-between gap-4 p-3 bg-gray-50 border border-gray-100 rounded-xl"
                    >
                      <span className="text-sm font-medium text-gray-700">{v.colorName}</span>
                      <div className="relative w-32">
                        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-sm font-medium">
                          ฿
                        </span>
                        <input
                          type="number"
                          min="0"
                          step="0.01"
                          required
                          value={v.unitCost}
                          onChange={(e) => handleVariantChange(idx, e.target.value)}
                          className="w-full pl-7 pr-3 py-1.5 text-sm font-semibold text-gray-900 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white text-right"
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
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
            form="edit-material-form"
            disabled={isPending}
            className="inline-flex items-center gap-2 px-5 py-2.5 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-xl shadow-sm transition-colors disabled:opacity-50"
          >
            <Save className="w-4 h-4" />
            {isPending ? "กำลังบันทึก..." : "บันทึกการเปลี่ยนแปลง"}
          </button>
        </div>
      </div>
    </div>
  );
}
