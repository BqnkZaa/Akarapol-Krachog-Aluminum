"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Save, ArrowLeft, CheckCircle2, AlertCircle } from "lucide-react";
import Link from "next/link";
import { createGlass } from "@/actions/admin";

export default function NewGlassForm() {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  const [name, setName] = useState("");
  const [category, setCategory] = useState("กระจกธรรมดา");
  const [thicknessMm, setThicknessMm] = useState("");
  const [pricePerSqM, setPricePerSqM] = useState("");
  const [description, setDescription] = useState("");
  const [sortOrder, setSortOrder] = useState("0");

  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setMessage(null);

    if (!name.trim()) {
      setMessage({ type: "error", text: "กรุณากรอกชื่อกระจก" });
      return;
    }
    const price = parseFloat(pricePerSqM);
    if (isNaN(price) || price < 0) {
      setMessage({ type: "error", text: "กรุณากรอกราคาต่อตารางเมตรที่ถูกต้อง" });
      return;
    }

    startTransition(async () => {
      const result = await createGlass({
        name: name.trim(),
        category: category,
        thicknessMm: thicknessMm ? parseInt(thicknessMm) : undefined,
        pricePerSqM: price,
        description: description.trim() || undefined,
        sortOrder: parseInt(sortOrder) || 0,
      });

      if (result.success) {
        setMessage({ type: "success", text: "เพิ่มข้อมูลกระจกสำเร็จ! กำลังกลับไปหน้ารายการ..." });
        setTimeout(() => router.push("/admin/glass"), 1200);
      } else {
        setMessage({ type: "error", text: result.error });
      }
    });
  };

  const inputCls =
    "w-full px-3.5 py-2.5 rounded-xl border border-gray-300 focus:ring-2 focus:ring-sky-500 focus:border-sky-500 outline-none transition-all text-sm text-gray-900 bg-white";

  return (
    <form onSubmit={handleSubmit} className="space-y-8">

      {/* ── Card: Basic Information ─────────────────────── */}
      <section className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="bg-gray-50 px-6 py-4 border-b border-gray-100">
          <h2 className="text-sm font-bold text-gray-700 uppercase tracking-wider">
            ข้อมูลกระจก
          </h2>
          <p className="text-xs text-gray-400 mt-0.5">
            กรอกข้อมูลชนิดกระจกที่จะใช้ในการประเมินราคา
          </p>
        </div>
        <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-5">

          {/* Name */}
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              ชื่อกระจก <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder='เช่น "กระจกใส 6มม." หรือ "6mm Clear Tempered"'
              required
              className={inputCls}
            />
            <p className="mt-1 text-xs text-gray-400">
              ต้องไม่ซ้ำกับกระจกอื่นในระบบ
            </p>
          </div>

          {/* Category */}
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
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

          {/* Thickness */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              ความหนา (มม.) <span className="text-gray-400 font-normal">(ไม่บังคับ)</span>
            </label>
            <input
              type="number"
              min={1}
              value={thicknessMm}
              onChange={(e) => setThicknessMm(e.target.value)}
              placeholder="เช่น 6, 8, 10"
              className={inputCls}
            />
          </div>

          {/* Price per m² */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              ราคาต่อตารางเมตร (฿) <span className="text-red-500">*</span>
            </label>
            <div className="relative">
              <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 text-sm font-medium">
                ฿
              </span>
              <input
                type="number"
                min={0}
                step={0.01}
                value={pricePerSqM}
                onChange={(e) => setPricePerSqM(e.target.value)}
                placeholder="0.00"
                required
                className={`${inputCls} pl-8`}
              />
            </div>
          </div>

          {/* Sort order */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              ลำดับการแสดง
            </label>
            <input
              type="number"
              min={0}
              value={sortOrder}
              onChange={(e) => setSortOrder(e.target.value)}
              className={inputCls}
            />
          </div>

          {/* Description */}
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              หมายเหตุ <span className="text-gray-400 font-normal">(ไม่บังคับ)</span>
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="คำอธิบายเพิ่มเติมเกี่ยวกับกระจกชนิดนี้..."
              rows={2}
              className={`${inputCls} resize-none`}
            />
          </div>
        </div>
      </section>

      {/* ── Feedback Message ─────────────────────────────── */}
      {message && (
        <div
          className={`flex items-start gap-3 p-4 rounded-xl text-sm font-medium ${
            message.type === "success"
              ? "bg-green-50 text-green-700 border border-green-200"
              : "bg-red-50 text-red-700 border border-red-200"
          }`}
        >
          {message.type === "success" ? (
            <CheckCircle2 className="w-5 h-5 shrink-0 mt-0.5" />
          ) : (
            <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" />
          )}
          {message.text}
        </div>
      )}

      {/* ── Form Actions ─────────────────────────────────── */}
      <div className="flex items-center justify-between gap-4 pb-8">
        <Link
          href="/admin/glass"
          className="inline-flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-gray-900 px-4 py-2.5 rounded-xl hover:bg-gray-100 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          กลับไปรายการกระจก
        </Link>

        <button
          type="submit"
          disabled={isPending}
          className="inline-flex items-center gap-2 bg-sky-600 hover:bg-sky-700 disabled:bg-sky-400 disabled:cursor-not-allowed text-white text-sm font-semibold px-6 py-2.5 rounded-xl shadow-sm transition-all active:scale-[0.98]"
        >
          {isPending ? (
            <span className="animate-pulse">กำลังบันทึก...</span>
          ) : (
            <>
              <Save className="w-4 h-4" />
              บันทึกข้อมูลกระจก
            </>
          )}
        </button>
      </div>
    </form>
  );
}
