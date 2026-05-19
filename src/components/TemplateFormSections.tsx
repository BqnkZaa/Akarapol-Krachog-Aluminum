"use client";

import { Trash2, ArrowUp, ArrowDown, PlusCircle, FlaskConical, ShoppingBag, Layers } from "lucide-react";
import type { ComponentRow, AccessoryRow, GlassRow } from "./TemplateFormTypes";
import type { MaterialOption, CategoryOption } from "@/actions/template";

// ── Shared input styles ──────────────────────────────────────────────────────
const inp = "w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-shadow";
const inpSm = "px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-shadow";
const inpErr = "w-full px-3 py-2 border border-red-400 rounded-lg text-sm focus:ring-2 focus:ring-red-400 outline-none bg-red-50";

// ── Grouped materials for <optgroup> dropdowns ───────────────────────────────
function buildGrouped(materials: MaterialOption[]) {
  const map: Record<string, { name: string; items: MaterialOption[] }> = {};
  for (const m of materials) {
    if (!map[m.categoryId]) map[m.categoryId] = { name: m.categoryName, items: [] };
    map[m.categoryId].items.push(m);
  }
  return Object.values(map);
}

// ════════════════════════════════════════════════════════════════════════════
// COMPONENTS SECTION
// ════════════════════════════════════════════════════════════════════════════
type ComponentsSectionProps = {
  rows: ComponentRow[];
  categories: CategoryOption[];
  materials: MaterialOption[];
  onChange: (idx: number, field: keyof ComponentRow, value: string | number | null) => void;
  onAdd: () => void;
  onRemove: (idx: number) => void;
  onMove: (idx: number, dir: -1 | 1) => void;
};

export function ComponentsSection({ rows, categories, materials, onChange, onAdd, onRemove, onMove }: ComponentsSectionProps) {
  const grouped = buildGrouped(materials);
  return (
    <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
      <div className="h-1 bg-gradient-to-r from-blue-500 to-cyan-500" />
      <div className="p-5 sm:p-6">
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-blue-100 rounded-xl flex items-center justify-center">
              <Layers className="w-4 h-4 text-blue-600" />
            </div>
            <div>
              <h3 className="font-bold text-gray-900">ชิ้นส่วนโปรไฟล์</h3>
              <p className="text-xs text-gray-400">ชิ้นส่วนโปรไฟล์อลูมิเนียมพร้อมสูตรการตัด</p>
            </div>
          </div>
          <button type="button" onClick={onAdd}
            className="inline-flex items-center gap-1.5 text-sm font-semibold text-blue-600 hover:text-blue-700 bg-blue-50 hover:bg-blue-100 px-3 py-1.5 rounded-lg transition-colors">
            <PlusCircle className="w-4 h-4" /> เพิ่มชิ้นส่วนโปรไฟล์
          </button>
        </div>

        {rows.length === 0 && (
          <div className="text-center py-8 border-2 border-dashed border-gray-200 rounded-xl">
            <Layers className="w-8 h-8 text-gray-300 mx-auto mb-2" />
            <p className="text-sm text-gray-400">ยังไม่มีชิ้นส่วนโปรไฟล์ คลิก "เพิ่มชิ้นส่วนโปรไฟล์" เพื่อเริ่มต้น</p>
          </div>
        )}

        <div className="space-y-3">
          {rows.map((row, idx) => (
            <div key={row._key} className="border border-gray-200 rounded-xl p-4 bg-gray-50/50 hover:bg-white transition-colors">
              {/* Row header */}
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-bold text-gray-400 uppercase tracking-wide">โปรไฟล์ #{idx + 1}</span>
                <div className="flex items-center gap-1">
                  <button type="button" onClick={() => onMove(idx, -1)} disabled={idx === 0}
                    className="p-1 text-gray-400 hover:text-gray-700 disabled:opacity-30 rounded transition-colors" title="Move up">
                    <ArrowUp className="w-3.5 h-3.5" />
                  </button>
                  <button type="button" onClick={() => onMove(idx, 1)} disabled={idx === rows.length - 1}
                    className="p-1 text-gray-400 hover:text-gray-700 disabled:opacity-30 rounded transition-colors" title="Move down">
                    <ArrowDown className="w-3.5 h-3.5" />
                  </button>
                  <button type="button" onClick={() => onRemove(idx)}
                    className="p-1 text-gray-400 hover:text-red-500 rounded transition-colors ml-1" title="Remove">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>

              {/* Row fields — 2-col grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {/* Category */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    ซีรีส์ของวัสดุ
                  </label>
                  <select 
                    value={row.categoryId} 
                    onChange={e => {
                      onChange(idx, "categoryId", e.target.value);
                      onChange(idx, "materialId", "");
                      onChange(idx, "label", "");
                    }}
                    className={inp}
                  >
                    <option value="">— ทั้งหมด —</option>
                    {categories.map(c => (
                      <option key={c.id} value={c.id}>{c.name}</option>
                    ))}
                  </select>
                </div>

                {/* Material */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    วัสดุ <span className="text-red-500">*</span>
                  </label>
                  <select 
                    value={row.materialId} 
                    onChange={e => {
                      const newMaterialId = e.target.value;
                      onChange(idx, "materialId", newMaterialId);
                      
                      // Auto-populate the label using the selected material's name
                      const selectedMaterial = materials.find(m => m.id === newMaterialId);
                      if (selectedMaterial) {
                        onChange(idx, "label", selectedMaterial.name);
                        onChange(idx, "categoryId", selectedMaterial.categoryId);
                      }
                    }}
                    className={inp}
                  >
                    <option value="">— เลือกวัสดุ —</option>
                    {row.categoryId ? (
                      materials.filter(m => m.categoryId === row.categoryId).map(m => (
                        <option key={m.id} value={m.id}>{m.code} — {m.name}</option>
                      ))
                    ) : (
                      grouped.map(g => (
                        <optgroup key={g.name} label={g.name}>
                          {g.items.map(m => (
                            <option key={m.id} value={m.id}>{m.code} — {m.name}</option>
                          ))}
                        </optgroup>
                      ))
                    )}
                  </select>
                </div>

                {/* Quantity */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    จำนวน <span className="text-red-500">*</span>
                  </label>
                  <input type="number" min={1} value={row.quantity}
                    onChange={e => onChange(idx, "quantity", parseInt(e.target.value) || 1)}
                    className={`${inpSm} w-full`} />
                </div>

                {/* Bar length override */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    ความยาวเส้นเต็ม (มม.) กำหนดเอง
                  </label>
                  <input type="number" min={1} value={row.barLengthMm}
                    onChange={e => onChange(idx, "barLengthMm", e.target.value)}
                    placeholder="เว้นว่างไว้เพื่อใช้ค่าเริ่มต้นของรูปแบบงาน"
                    className={`${inpSm} w-full`} />
                </div>

                {/* Formula */}
                <div className="sm:col-span-2">
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    สูตรคำนวณ (W/H ในหน่วย มม.) <span className="text-red-500">*</span>
                  </label>
                  <input type="text" value={row.formula}
                    onChange={e => onChange(idx, "formula", e.target.value)}
                    placeholder='เช่น "H - 35" หรือ "W / 2 + 10"'
                    className={row.formulaError ? inpErr : inp} />
                  {row.formulaError ? (
                    <p className="text-xs text-red-600 mt-1 flex items-center gap-1">⚠ {row.formulaError}</p>
                  ) : row.formula && (
                    <p className="text-xs text-green-600 mt-1">✓ รูปแบบสูตรถูกต้อง</p>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// GLASS SECTION
// ════════════════════════════════════════════════════════════════════════════
type GlassSectionProps = {
  glass: GlassRow;
  onChange: (field: keyof GlassRow, value: string | number | boolean | null) => void;
};

export function GlassSection({ glass, onChange }: GlassSectionProps) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
      <div className={`h-1 ${glass.enabled ? "bg-gradient-to-r from-sky-400 to-blue-500" : "bg-gray-200"}`} />
      <div className="p-5 sm:p-6">
        <div className="flex items-center justify-between mb-1">
          <div className="flex items-center gap-3">
            <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${glass.enabled ? "bg-sky-100" : "bg-gray-100"}`}>
              <FlaskConical className={`w-4 h-4 ${glass.enabled ? "text-sky-600" : "text-gray-400"}`} />
            </div>
            <div>
              <h3 className="font-bold text-gray-900">ข้อมูลกระจก</h3>
              <p className="text-xs text-gray-400">ไม่บังคับ — สำหรับรูปแบบงานที่มีกระจก</p>
            </div>
          </div>
          {/* Toggle */}
          <button type="button" role="switch" aria-checked={glass.enabled}
            onClick={() => onChange("enabled", !glass.enabled)}
            className={`relative w-11 h-6 rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-sky-500 focus:ring-offset-2 ${glass.enabled ? "bg-sky-500" : "bg-gray-300"}`}>
            <span className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transform transition-transform ${glass.enabled ? "translate-x-5" : "translate-x-0"}`} />
          </button>
        </div>

        {glass.enabled && (
          <div className="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Width formula */}
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">
                สูตรความกว้าง (มม.) <span className="text-red-500">*</span>
              </label>
              <input type="text" value={glass.widthFormula}
                onChange={e => onChange("widthFormula", e.target.value)}
                placeholder='e.g. "W / 2 - 30"'
                className={glass.widthFormulaError ? inpErr : inp} />
              {glass.widthFormulaError
                ? <p className="text-xs text-red-600 mt-1">⚠ {glass.widthFormulaError}</p>
                : glass.widthFormula && <p className="text-xs text-green-600 mt-1">✓ ถูกต้อง</p>}
            </div>

            {/* Height formula */}
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">
                สูตรความสูง (มม.) <span className="text-red-500">*</span>
              </label>
              <input type="text" value={glass.heightFormula}
                onChange={e => onChange("heightFormula", e.target.value)}
                placeholder='e.g. "H - 80"'
                className={glass.heightFormulaError ? inpErr : inp} />
              {glass.heightFormulaError
                ? <p className="text-xs text-red-600 mt-1">⚠ {glass.heightFormulaError}</p>
                : glass.heightFormula && <p className="text-xs text-green-600 mt-1">✓ ถูกต้อง</p>}
            </div>

            {/* Panel count */}
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">จำนวนบานกระจก <span className="text-red-500">*</span></label>
              <input type="number" min={1} value={glass.panelCount}
                onChange={e => onChange("panelCount", parseInt(e.target.value) || 1)}
                className={`${inpSm} w-full`} />
            </div>

            {/* Price per m² */}
            <div>
              <label className="block text-xs font-semibold text-gray-600 mb-1">ราคาต่อตารางเมตร (฿) <span className="text-red-500">*</span></label>
              <input type="number" min={0} step={0.01} value={glass.pricePerSqM}
                onChange={e => onChange("pricePerSqM", parseFloat(e.target.value) || 0)}
                className={`${inpSm} w-full`} />
            </div>

            {/* Glass type */}
            <div className="sm:col-span-2">
              <label className="block text-xs font-semibold text-gray-600 mb-1">ชนิดกระจก <span className="text-red-500">*</span></label>
              <input type="text" value={glass.glassType}
                onChange={e => onChange("glassType", e.target.value)}
                placeholder='เช่น "6mm Clear Tempered"' className={inp} />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ACCESSORIES SECTION
// ════════════════════════════════════════════════════════════════════════════
type AccessoriesSectionProps = {
  rows: AccessoryRow[];
  onChange: (idx: number, field: keyof AccessoryRow, value: string | number) => void;
  onAdd: () => void;
  onRemove: (idx: number) => void;
  onMove: (idx: number, dir: -1 | 1) => void;
};

export function AccessoriesSection({ rows, onChange, onAdd, onRemove, onMove }: AccessoriesSectionProps) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
      <div className="h-1 bg-gradient-to-r from-purple-500 to-pink-500" />
      <div className="p-5 sm:p-6">
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-purple-100 rounded-xl flex items-center justify-center">
              <ShoppingBag className="w-4 h-4 text-purple-600" />
            </div>
            <div>
              <h3 className="font-bold text-gray-900">อุปกรณ์เสริม</h3>
              <p className="text-xs text-gray-400">รายการค่าใช้จ่ายคงที่ที่รวมอยู่ในทุกการประเมินราคา</p>
            </div>
          </div>
          <button type="button" onClick={onAdd}
            className="inline-flex items-center gap-1.5 text-sm font-semibold text-purple-600 hover:text-purple-700 bg-purple-50 hover:bg-purple-100 px-3 py-1.5 rounded-lg transition-colors">
            <PlusCircle className="w-4 h-4" /> เพิ่มอุปกรณ์เสริม
          </button>
        </div>

        {rows.length === 0 && (
          <div className="text-center py-6 border-2 border-dashed border-gray-200 rounded-xl">
            <ShoppingBag className="w-7 h-7 text-gray-300 mx-auto mb-2" />
            <p className="text-sm text-gray-400">ยังไม่มีอุปกรณ์เสริม สามารถเพิ่มมือจับ ลูกล้อ ตัวล็อค ฯลฯ</p>
          </div>
        )}

        <div className="space-y-3">
          {rows.map((row, idx) => (
            <div key={row._key} className="border border-gray-200 rounded-xl p-4 bg-gray-50/50 hover:bg-white transition-colors">
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-bold text-gray-400 uppercase tracking-wide">อุปกรณ์เสริม #{idx + 1}</span>
                <div className="flex items-center gap-1">
                  <button type="button" onClick={() => onMove(idx, -1)} disabled={idx === 0}
                    className="p-1 text-gray-400 hover:text-gray-700 disabled:opacity-30 rounded" title="Move up">
                    <ArrowUp className="w-3.5 h-3.5" />
                  </button>
                  <button type="button" onClick={() => onMove(idx, 1)} disabled={idx === rows.length - 1}
                    className="p-1 text-gray-400 hover:text-gray-700 disabled:opacity-30 rounded" title="Move down">
                    <ArrowDown className="w-3.5 h-3.5" />
                  </button>
                  <button type="button" onClick={() => onRemove(idx)}
                    className="p-1 text-gray-400 hover:text-red-500 rounded ml-1" title="Remove">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                {/* Name */}
                <div className="col-span-2 sm:col-span-2">
                  <label className="block text-xs font-semibold text-gray-600 mb-1">ชื่ออุปกรณ์ <span className="text-red-500">*</span></label>
                  <input type="text" value={row.name} onChange={e => onChange(idx, "name", e.target.value)}
                    placeholder='เช่น "ชุดล้อบานเลื่อน"' className={inp} />
                </div>

                {/* Unit */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">หน่วยนับ</label>
                  <input type="text" value={row.unit} onChange={e => onChange(idx, "unit", e.target.value)}
                    placeholder="ชุด" className={`${inpSm} w-full`} />
                </div>

                {/* Qty */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">จำนวน</label>
                  <input type="number" min={1} value={row.quantity}
                    onChange={e => onChange(idx, "quantity", parseInt(e.target.value) || 1)}
                    className={`${inpSm} w-full`} />
                </div>

                {/* Unit cost */}
                <div className="col-span-2">
                  <label className="block text-xs font-semibold text-gray-600 mb-1">ราคาต่อหน่วย (฿) <span className="text-red-500">*</span></label>
                  <input type="number" min={0} step={0.01} value={row.unitCost}
                    onChange={e => onChange(idx, "unitCost", parseFloat(e.target.value) || 0)}
                    className={`${inpSm} w-full`} />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
