"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Save, ArrowLeft, CheckCircle2, AlertCircle } from "lucide-react";
import Link from "next/link";
import { createAccessory } from "@/actions/admin";
import type { ColorDTO } from "@/actions/material";

type Props = {
  colors: ColorDTO[];
};

type VariantPrice = {
  colorId: string;
  unitCost: string; // string for input binding, parsed on submit
};

export default function NewAccessoryForm({ colors }: Props) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  // ── Form field state ────────────────────────────────────────
  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [unit, setUnit] = useState("ชิ้น");
  const [series, setSeries] = useState("");
  const [description, setDescription] = useState("");

  // One price row per color — initialised with empty prices
  const [variantPrices, setVariantPrices] = useState<VariantPrice[]>(
    colors.map((c) => ({ colorId: c.id, unitCost: "" }))
  );

  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // ── Update a single variant price ──────────────────────────
  const setVariantPrice = (colorId: string, value: string) => {
    setVariantPrices((prev) =>
      prev.map((vp) => (vp.colorId === colorId ? { ...vp, unitCost: value } : vp))
    );
  };

  // ── Submit ─────────────────────────────────────────────────
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setMessage(null);

    // Only include variants where a price has been entered
    const filledVariants = variantPrices.filter((vp) => vp.unitCost.trim() !== "");

    startTransition(async () => {
      const result = await createAccessory({
        code: code.trim(),
        name: name.trim(),
        unit: unit.trim(),
        series: series.trim() || "ทั่วไป",
        description: description.trim() || undefined,
        variants: filledVariants.map((vp) => ({
          colorId: vp.colorId,
          unitCost: parseFloat(vp.unitCost),
        })),
      });

      if (result.success) {
        setMessage({ type: "success", text: "Accessory added successfully! Redirecting..." });
        setTimeout(() => router.push("/admin/accessories"), 1200);
      } else {
        setMessage({ type: "error", text: result.error });
      }
    });
  };

  // ── Shared input class ─────────────────────────────────────
  const inputCls =
    "w-full px-3.5 py-2.5 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all text-sm text-gray-900 bg-white";

  return (
    <form onSubmit={handleSubmit} className="space-y-8">

      {/* ── Card 1: Basic Information ─────────────────────── */}
      <section className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="bg-gray-50 px-6 py-4 border-b border-gray-100">
          <h2 className="text-sm font-bold text-gray-700 uppercase tracking-wider">
            Basic Information
          </h2>
        </div>
        <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-5">

          {/* Code */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              Accessory Code <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="e.g. ACC-01"
              required
              className={`${inputCls} font-mono`}
            />
            <p className="mt-1 text-xs text-gray-400">
              Must be unique across all accessories.
            </p>
          </div>

          {/* Unit */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              Unit <span className="text-red-500">*</span>
            </label>
            <select
              value={unit}
              onChange={(e) => setUnit(e.target.value)}
              required
              className={inputCls}
            >
              <option value="ชิ้น">ชิ้น (piece)</option>
              <option value="ม้วน">ม้วน (roll)</option>
              <option value="แพค">แพค (pack)</option>
              <option value="ชุด">ชุด (set)</option>
            </select>
          </div>

          {/* Series */}
          <div className="sm:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              ซีรีส์ / หมวดหมู่ <span className="text-gray-400 font-normal">(Series / Category)</span>
            </label>
            <input
              type="text"
              list="series-suggestions"
              value={series}
              onChange={(e) => setSeries(e.target.value)}
              placeholder="e.g. ชุดบานเลื่อน, ชุดบานเปิด, บานกระทุ้ง"
              className={inputCls}
            />
            <datalist id="series-suggestions">
              <option value="ชุดบานเลื่อน" />
              <option value="ชุดบานเปิด, บานกระทุ้ง" />
              <option value="ชุดบานเฟี้ยม" />
              <option value="ชุดท้องตลาด" />
              <option value="ชุดบานเปลือย" />
            </datalist>
            <p className="mt-1 text-xs text-gray-400">
              การจัดหมวดหมู่อุปกรณ์เสริมตามซีรีส์อลูมิเนียม
            </p>
          </div>

          {/* Name */}
          <div className="sm:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              Accessory Name <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. บานพับ"
              required
              className={inputCls}
            />
          </div>

          {/* Description */}
          <div className="sm:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1.5">
              Description <span className="text-gray-400 font-normal">(optional)</span>
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Brief note about this accessory..."
              rows={2}
              className={`${inputCls} resize-none`}
            />
          </div>
        </div>
      </section>

      {/* ── Card 2: Color Variant Pricing ─────────────────── */}
      <section className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="bg-gray-50 px-6 py-4 border-b border-gray-100">
          <h2 className="text-sm font-bold text-gray-700 uppercase tracking-wider">
            Color Variant Pricing (THB per unit)
          </h2>
          <p className="text-xs text-gray-400 mt-0.5">
            Leave a color blank to skip creating that variant.
          </p>
        </div>
        <div className="p-6 grid grid-cols-1 md:grid-cols-3 gap-5">
          {colors.map((color) => {
            const vp = variantPrices.find((v) => v.colorId === color.id);
            return (
              <div key={color.id}>
                <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-1.5">
                  {color.hexCode && (
                    <span
                      className="w-4 h-4 rounded-full border border-gray-300 shrink-0"
                      style={{ backgroundColor: color.hexCode }}
                    />
                  )}
                  {color.name}
                </label>
                <div className="relative">
                  <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 text-sm font-medium">
                    ฿
                  </span>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    value={vp?.unitCost ?? ""}
                    onChange={(e) => setVariantPrice(color.id, e.target.value)}
                    placeholder="0.00"
                    className={`${inputCls} pl-8`}
                  />
                </div>
              </div>
            );
          })}
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
          href="/admin/accessories"
          className="inline-flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-gray-900 px-4 py-2.5 rounded-xl hover:bg-gray-100 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Accessories
        </Link>

        <button
          type="submit"
          disabled={isPending}
          className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 disabled:cursor-not-allowed text-white text-sm font-semibold px-6 py-2.5 rounded-xl shadow-sm transition-all active:scale-[0.98]"
        >
          {isPending ? (
            <span className="animate-pulse">Saving...</span>
          ) : (
            <>
              <Save className="w-4 h-4" />
              Save Accessory
            </>
          )}
        </button>
      </div>
    </form>
  );
}
