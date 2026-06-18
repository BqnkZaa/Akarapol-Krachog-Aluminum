"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2, X, Save, AlertCircle, CheckCircle2 } from "lucide-react";
import { updateGlass, deleteGlass } from "@/actions/admin";

type GlassData = {
  id: string;
  name: string;
  category: string;
  thicknessMm: number | null;
  pricePerSqM: number;
  description: string | null;
};

type Props = {
  glass: GlassData;
};

export default function GlassActions({ glass }: Props) {
  const [showEdit, setShowEdit] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isPending, startTransition] = useTransition();
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const handleDelete = () => {
    setDeleteError(null);
    startTransition(async () => {
      const result = await deleteGlass(glass.id);
      if (!result.success) {
        setDeleteError(result.error);
        setShowDeleteConfirm(false);
      }
    });
  };

  return (
    <>
      <div className="flex items-center justify-end gap-2">
        <button
          type="button"
          onClick={() => setShowEdit(true)}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
        >
          <Pencil className="w-3 h-3" /> แก้ไข
        </button>
        {!showDeleteConfirm ? (
          <button
            type="button"
            onClick={() => setShowDeleteConfirm(true)}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition-colors"
          >
            <Trash2 className="w-3 h-3" /> ลบ
          </button>
        ) : (
          <span className="flex items-center gap-1.5">
            <span className="text-xs text-red-600 font-medium">ยืนยันลบ?</span>
            <button
              type="button"
              disabled={isPending}
              onClick={handleDelete}
              className="px-2.5 py-1 text-xs font-bold text-white bg-red-600 hover:bg-red-700 rounded-lg disabled:opacity-50 transition-colors"
            >
              {isPending ? "..." : "ใช่"}
            </button>
            <button
              type="button"
              onClick={() => setShowDeleteConfirm(false)}
              className="px-2.5 py-1 text-xs font-semibold text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
            >
              ยกเลิก
            </button>
          </span>
        )}
      </div>

      {deleteError && (
        <p className="mt-1 text-xs text-red-600 text-right">{deleteError}</p>
      )}

      {/* Edit Modal */}
      {showEdit && (
        <EditGlassModal
          glass={glass}
          onClose={() => setShowEdit(false)}
        />
      )}
    </>
  );
}

// ── Inline Edit Modal ─────────────────────────────────────────────────────────

function EditGlassModal({ glass, onClose }: { glass: GlassData; onClose: () => void }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [name, setName] = useState(glass.name);
  const [category, setCategory] = useState(glass.category);
  const [thicknessMm, setThicknessMm] = useState(glass.thicknessMm?.toString() ?? "");
  const [pricePerSqM, setPricePerSqM] = useState(glass.pricePerSqM.toString());
  const [description, setDescription] = useState(glass.description ?? "");
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    setMessage(null);

    const price = parseFloat(pricePerSqM);
    if (!name.trim()) {
      setMessage({ type: "error", text: "กรุณากรอกชื่อกระจก" });
      return;
    }
    if (isNaN(price) || price < 0) {
      setMessage({ type: "error", text: "กรุณากรอกราคาที่ถูกต้อง" });
      return;
    }

    startTransition(async () => {
      const result = await updateGlass({
        id: glass.id,
        name: name.trim(),
        category: category,
        thicknessMm: thicknessMm ? parseInt(thicknessMm) : null,
        pricePerSqM: price,
        description: description.trim() || null,
      });

      if (result.success) {
        setMessage({ type: "success", text: "บันทึกสำเร็จ!" });
        router.push(`/admin/glass#glass-${glass.id}`);
        setTimeout(onClose, 800);
      } else {
        setMessage({ type: "error", text: result.error });
      }
    });
  };

  const inputCls =
    "w-full px-3.5 py-2.5 rounded-xl border border-gray-300 focus:ring-2 focus:ring-sky-500 focus:border-sky-500 outline-none transition-all text-sm text-gray-900 bg-white";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div>
            <h2 className="font-bold text-gray-900 text-base">แก้ไขข้อมูลกระจก</h2>
            <p className="text-xs text-gray-400 mt-0.5 font-mono truncate max-w-[280px]">{glass.name}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Body */}
        <form onSubmit={handleSave} className="p-6 space-y-4">
          <div>
            <label className="block text-xs font-semibold text-gray-600 mb-1.5">
              ชื่อกระจก <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className={inputCls}
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-600 mb-1.5">
              หมวดหมู่กระจก <span className="text-red-500">*</span>
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className={inputCls}
              required
            >
              <option value="กระจกธรรมดา">กระจกธรรมดา</option>
              <option value="กระจกเทมเปอร์">กระจกเทมเปอร์</option>
              <option value="กระจกลามิเนต">กระจกลามิเนต</option>
              <option value="กระจกเทมเปอร์ลามิเนต">กระจกเทมเปอร์ลามิเนต</option>
              <option value="กระจกอินซูเลท">กระจกอินซูเลท</option>
              <option value="กระจกเทมเปอร์อินซูเลท">กระจกเทมเปอร์อินซูเลท</option>
            </select>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1.5">
                ความหนา (มม.)
              </label>
              <input
                type="number"
                min={1}
                value={thicknessMm}
                onChange={(e) => setThicknessMm(e.target.value)}
                placeholder="เช่น 6"
                className={inputCls}
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1.5">
                ราคา/ตร.ม. (฿) <span className="text-red-500">*</span>
              </label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-sm">฿</span>
                <input
                  type="number"
                  min={0}
                  step={0.01}
                  value={pricePerSqM}
                  onChange={(e) => setPricePerSqM(e.target.value)}
                  className={`${inputCls} pl-7`}
                />
              </div>
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-600 mb-1.5">
              หมายเหตุ
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              className={`${inputCls} resize-none`}
            />
          </div>

          {message && (
            <div
              className={`flex items-center gap-2 p-3 rounded-xl text-sm font-medium ${
                message.type === "success"
                  ? "bg-green-50 text-green-700 border border-green-200"
                  : "bg-red-50 text-red-700 border border-red-200"
              }`}
            >
              {message.type === "success" ? (
                <CheckCircle2 className="w-4 h-4 shrink-0" />
              ) : (
                <AlertCircle className="w-4 h-4 shrink-0" />
              )}
              {message.text}
            </div>
          )}

          <div className="flex items-center justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors"
            >
              ยกเลิก
            </button>
            <button
              type="submit"
              disabled={isPending}
              className="inline-flex items-center gap-2 px-5 py-2 text-sm font-semibold text-white bg-sky-600 hover:bg-sky-700 rounded-xl disabled:opacity-50 transition-colors"
            >
              {isPending ? (
                <span className="animate-pulse">กำลังบันทึก...</span>
              ) : (
                <>
                  <Save className="w-3.5 h-3.5" /> บันทึก
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
