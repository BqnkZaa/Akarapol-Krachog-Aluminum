"use client";

import { useState, useTransition, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  Save, Loader2, AlertCircle, CheckCircle2, Settings, FolderOpen,
} from "lucide-react";
import {
  createTemplate, updateTemplate,
  type CategoryOption, type MaterialOption, type TemplateDetail,
} from "@/actions/template";
import { validateFormula } from "@/lib/formulaParser";
import {
  ComponentsSection, GlassSection, AccessoriesSection,
} from "./TemplateFormSections";
import type { ComponentRow, AccessoryRow, GlassRow } from "./TemplateFormTypes";
import {
  makeEmptyComponent, makeEmptyAccessory, defaultGlass,
} from "./TemplateFormTypes";

// ── Props ────────────────────────────────────────────────────────────────────
type Props =
  | { mode: "create"; initialData?: undefined; categories: CategoryOption[]; materials: MaterialOption[] }
  | { mode: "edit"; initialData: TemplateDetail; categories: CategoryOption[]; materials: MaterialOption[] };

// ── Helpers ──────────────────────────────────────────────────────────────────
const inp = "w-full px-4 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-shadow";

function slugify(s: string) {
  return s.toLowerCase().trim()
    .replace(/[^\w\s-]/g, "").replace(/[\s_]+/g, "-")
    .replace(/-+/g, "-").replace(/^-+|-+$/g, "");
}

function initComponents(data?: TemplateDetail, materials?: MaterialOption[]): ComponentRow[] {
  if (!data?.components.length) return [makeEmptyComponent(0)];
  return data.components.map((c, i) => {
    const mat = materials?.find(m => m.id === c.materialId);
    return {
      _key: `c-init-${i}`,
      categoryId: mat?.categoryId || "",
      materialId: c.materialId,
      label: c.label,
      formula: c.formula,
      formulaError: null,
      quantity: c.quantity,
      barLengthMm: c.barLengthMm != null ? String(c.barLengthMm) : "",
      sortOrder: c.sortOrder,
    };
  });
}

function initAccessories(data?: TemplateDetail): AccessoryRow[] {
  if (!data?.accessories.length) return [];
  return data.accessories.map((a, i) => ({
    _key: `a-init-${i}`,
    name: a.name,
    quantity: a.quantity,
    unitCost: a.unitCost,
    unit: a.unit,
    sortOrder: a.sortOrder,
  }));
}

function initGlass(data?: TemplateDetail): GlassRow {
  if (!data?.glass) return defaultGlass;
  return {
    enabled: true,
    widthFormula: data.glass.widthFormula,
    widthFormulaError: null,
    heightFormula: data.glass.heightFormula,
    heightFormulaError: null,
    panelCount: data.glass.panelCount,
    glassType: data.glass.glassType,
    pricePerSqM: data.glass.pricePerSqM,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
export default function TemplateForm({ mode, initialData, categories, materials }: Props) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  // ── Header state ──────────────────────────────────────────────────────────
  const [categoryId, setCategoryId] = useState(initialData?.categoryId ?? "");
  const [name, setName] = useState(initialData?.name ?? "");
  const [slug, setSlug] = useState(initialData?.slug ?? "");
  const [slugTouched, setSlugTouched] = useState(mode === "edit");
  const [description, setDescription] = useState(initialData?.description ?? "");
  const [imageUrl, setImageUrl] = useState(initialData?.imageUrl ?? "");
  const [barLengthMm, setBarLengthMm] = useState(initialData?.standardBarLengthMm ?? 6000);
  const [kerfMm] = useState(0);
  const [sortOrder, setSortOrder] = useState(initialData?.sortOrder ?? 0);
  const [isActive, setIsActive] = useState(initialData?.isActive ?? true);

  // ── Auto-slug ─────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!slugTouched && mode === "create") setSlug(slugify(name));
  }, [name, slugTouched, mode]);

  // ── Child arrays ──────────────────────────────────────────────────────────
  const [components, setComponents] = useState<ComponentRow[]>(() => initComponents(initialData, materials));
  const [glass, setGlass] = useState<GlassRow>(() => initGlass(initialData));
  const [accessories, setAccessories] = useState<AccessoryRow[]>(() => initAccessories(initialData));

  // ── Feedback ──────────────────────────────────────────────────────────────
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // ── Component handlers ────────────────────────────────────────────────────
  const updateComp = (idx: number, field: keyof ComponentRow, value: string | number | null) => {
    setComponents(prev => prev.map((row, i) => {
      if (i !== idx) return row;
      const updated = { ...row, [field]: value };
      // Live formula validation
      if (field === "formula") {
        const v = typeof value === "string" ? value : "";
        if (v.trim()) {
          const res = validateFormula(v.trim());
          updated.formulaError = res.valid ? null : res.error;
        } else {
          updated.formulaError = null;
        }
      }
      return updated;
    }));
  };

  const addComp = () => setComponents(prev => [...prev, makeEmptyComponent(prev.length)]);

  const removeComp = (idx: number) => setComponents(prev => prev.filter((_, i) => i !== idx));

  const moveComp = (idx: number, dir: -1 | 1) => {
    setComponents(prev => {
      const next = [...prev];
      const target = idx + dir;
      if (target < 0 || target >= next.length) return prev;
      [next[idx], next[target]] = [next[target], next[idx]];
      return next.map((r, i) => ({ ...r, sortOrder: i }));
    });
  };

  // ── Glass handlers ────────────────────────────────────────────────────────
  const updateGlass = (field: keyof GlassRow, value: string | number | boolean | null) => {
    setGlass(prev => {
      const updated = { ...prev, [field]: value };
      if (field === "widthFormula" && typeof value === "string") {
        const res = value.trim() ? validateFormula(value.trim()) : { valid: true };
        updated.widthFormulaError = res.valid ? null : (res as { valid: false; error: string }).error;
      }
      if (field === "heightFormula" && typeof value === "string") {
        const res = value.trim() ? validateFormula(value.trim()) : { valid: true };
        updated.heightFormulaError = res.valid ? null : (res as { valid: false; error: string }).error;
      }
      return updated;
    });
  };

  // ── Accessory handlers ────────────────────────────────────────────────────
  const addAcc = () => setAccessories(prev => [...prev, makeEmptyAccessory(prev.length)]);

  const removeAcc = (idx: number) => setAccessories(prev => prev.filter((_, i) => i !== idx));

  const updateAcc = (idx: number, field: keyof AccessoryRow, value: string | number) => {
    setAccessories(prev => prev.map((row, i) => i !== idx ? row : { ...row, [field]: value }));
  };

  const moveAcc = (idx: number, dir: -1 | 1) => {
    setAccessories(prev => {
      const next = [...prev];
      const target = idx + dir;
      if (target < 0 || target >= next.length) return prev;
      [next[idx], next[target]] = [next[target], next[idx]];
      return next.map((r, i) => ({ ...r, sortOrder: i }));
    });
  };

  // ── Submit ────────────────────────────────────────────────────────────────
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    // Client-side formula pre-check before network call
    for (const comp of components) {
      if (comp.formulaError) {
        setError(`โปรดแก้ไขข้อผิดพลาดของสูตรใน "${comp.label || `Component #${components.indexOf(comp) + 1}`}" ก่อนบันทึก`);
        return;
      }
    }
    if (glass.enabled && (glass.widthFormulaError || glass.heightFormulaError)) {
      setError("โปรดแก้ไขข้อผิดพลาดของสูตรกระจกก่อนบันทึก");
      return;
    }

    startTransition(async () => {
      const payload = {
        categoryId,
        name,
        slug,
        description: description || undefined,
        imageUrl: imageUrl || undefined,
        standardBarLengthMm: barLengthMm,
        kerfMm: 0,
        sortOrder,
        isActive,
        components: components.map((c, i) => ({
          materialId: c.materialId,
          label: c.label,
          formula: c.formula,
          quantity: c.quantity,
          barLengthMm: c.barLengthMm ? parseInt(c.barLengthMm) : undefined,
          sortOrder: i,
        })),
        glass: glass.enabled ? {
          widthFormula: glass.widthFormula,
          heightFormula: glass.heightFormula,
          panelCount: glass.panelCount,
          glassType: glass.glassType,
          pricePerSqM: glass.pricePerSqM,
        } : null,
        accessories: accessories.map((a, i) => ({
          name: a.name,
          quantity: a.quantity,
          unitCost: a.unitCost,
          unit: a.unit,
          sortOrder: i,
        })),
      };

      const result = mode === "edit" && initialData
        ? await updateTemplate(initialData.id, payload)
        : await createTemplate(payload);

      if (!result.success) {
        setError(result.error);
        return;
      }
      setSuccess(mode === "edit" ? "อัปเดตรูปแบบงานสำเร็จ!" : "สร้างรูปแบบงานสำเร็จ!");
      setTimeout(() => router.push("/admin/templates"), 800);
    });
  };

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <form onSubmit={handleSubmit} className="space-y-6" id="template-form">

      {/* ── SECTION 1: Header ─────────────────────────────────────────────── */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="h-1 bg-gradient-to-r from-indigo-500 to-purple-500" />
        <div className="p-5 sm:p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="w-9 h-9 bg-indigo-100 rounded-xl flex items-center justify-center">
              <Settings className="w-4 h-4 text-indigo-600" />
            </div>
            <div>
              <h3 className="font-bold text-gray-900">ข้อมูลรูปแบบงาน</h3>
              <p className="text-xs text-gray-400">ข้อมูลพื้นฐานเกี่ยวกับรูปแบบงานนี้</p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
            {/* Category */}
            <div className="sm:col-span-2">
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                ซีรีส์ (หมวดหมู่) <span className="text-red-500">*</span>
              </label>
              <select value={categoryId} onChange={e => setCategoryId(e.target.value)} className={inp}>
                <option value="">— เลือกซีรีส์ —</option>
                {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </div>

            {/* Name */}
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                ชื่อรูปแบบงาน <span className="text-red-500">*</span>
              </label>
              <input type="text" value={name} onChange={e => setName(e.target.value)}
                placeholder='เช่น "iConiq Sliding Door 2-Panel"' className={inp} />
            </div>

            {/* Slug */}
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">Slug <span className="text-red-500">*</span></label>
              <div className="flex items-center gap-2">
                <span className="text-sm text-gray-400">/</span>
                <input type="text" value={slug}
                  onChange={e => { setSlugTouched(true); setSlug(e.target.value); }}
                  placeholder="iconiq-sliding-door-2p"
                  className="flex-1 px-4 py-2.5 border border-gray-300 rounded-xl text-sm font-mono focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none" />
              </div>
            </div>

            {/* Description */}
            <div className="sm:col-span-2">
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">คำอธิบาย</label>
              <textarea rows={2} value={description} onChange={e => setDescription(e.target.value)}
                placeholder="คำอธิบายโดยย่อ (ไม่บังคับ)" className={`${inp} resize-none`} />
            </div>

            {/* Image URL */}
            <div className="sm:col-span-2">
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">URL รูปภาพ / ไดอะแกรม</label>
              <input type="url" value={imageUrl} onChange={e => setImageUrl(e.target.value)}
                placeholder="https://example.com/diagram.png (ไม่บังคับ)" className={inp} />
            </div>

            {/* Bar length */}
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                ความยาวเส้นเต็ม (ซม.) <span className="text-red-500">*</span>
              </label>
              <input type="number" min={10} value={barLengthMm / 10}
                onChange={e => setBarLengthMm((parseFloat(e.target.value) || 600) * 10)} className={inp} />
              <p className="text-xs text-gray-400 mt-1">มาตรฐานไทย: 600 ซม. | นำเข้า: 640 ซม.</p>
            </div>



            {/* Sort order + Active */}
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">ลำดับการแสดงผล</label>
              <input type="number" min={0} value={sortOrder}
                onChange={e => setSortOrder(parseInt(e.target.value) || 0)} className={inp} />
            </div>

            <div className="flex items-center gap-3 sm:pt-7">
              <button type="button" role="switch" aria-checked={isActive}
                onClick={() => setIsActive(p => !p)}
                className={`relative w-11 h-6 rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 ${isActive ? "bg-blue-600" : "bg-gray-300"}`}>
                <span className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transform transition-transform ${isActive ? "translate-x-5" : "translate-x-0"}`} />
              </button>
              <span className="text-sm font-medium text-gray-700">{isActive ? "เปิดใช้งาน" : "ปิดใช้งาน"}</span>
            </div>
          </div>
        </div>
      </div>

      {/* ── SECTION 2: Profile Components ─────────────────────────────────── */}
      <ComponentsSection
        rows={components}
        categories={categories}
        materials={materials}
        onChange={updateComp}
        onAdd={addComp}
        onRemove={removeComp}
        onMove={moveComp}
      />

      {/* ── SECTION 3: Glass Specification ────────────────────────────────── */}
      <GlassSection glass={glass} onChange={updateGlass} />

      {/* ── SECTION 4: Accessories ────────────────────────────────────────── */}
      <AccessoriesSection
        rows={accessories}
        onChange={updateAcc}
        onAdd={addAcc}
        onRemove={removeAcc}
        onMove={moveAcc}
      />

      {/* ── Feedback ──────────────────────────────────────────────────────── */}
      {error && (
        <div className="flex items-start gap-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl px-4 py-3">
          <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
          <p>{error}</p>
        </div>
      )}
      {success && (
        <div className="flex items-start gap-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-xl px-4 py-3">
          <CheckCircle2 className="w-4 h-4 mt-0.5 shrink-0" />
          <p>{success}</p>
        </div>
      )}

      {/* ── Submit bar ────────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between gap-3 bg-white rounded-2xl border border-gray-200 shadow-sm px-5 py-4">
        <p className="text-xs text-gray-400">
          {components.length} ชิ้นส่วนโปรไฟล์ ·{" "}
          {glass.enabled ? "รวมกระจก" : "ไม่รวมกระจก"} ·{" "}
          {accessories.length} อุปกรณ์เสริม
        </p>
        <div className="flex items-center gap-3">
          <button type="button" onClick={() => router.push("/admin/templates")}
            className="px-5 py-2.5 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-xl hover:bg-gray-50 transition-colors">
            ยกเลิก
          </button>
          <button type="submit" disabled={isPending} id="submit-template-btn"
            className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-6 py-2.5 rounded-xl shadow-sm transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
            {isPending ? <><Loader2 className="w-4 h-4 animate-spin" />{mode === "edit" ? "กำลังบันทึก…" : "กำลังสร้าง…"}</>
              : <><Save className="w-4 h-4" />{mode === "edit" ? "บันทึก" : "สร้างรูปแบบงาน"}</>}
          </button>
        </div>
      </div>
    </form>
  );
}
