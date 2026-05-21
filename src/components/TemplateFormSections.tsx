"use client";

import { Trash2, ArrowUp, ArrowDown, PlusCircle, FlaskConical, ShoppingBag, Layers } from "lucide-react";
import type { ComponentRow, AccessoryRow, GlassRow } from "./TemplateFormTypes";
import type { MaterialOption, CategoryOption, AccessoryOption, GlassOption } from "@/actions/template";

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

// ── Grouped accessories by series for <optgroup> dropdowns ─────────────────────
function buildGroupedAccessories(accessories: AccessoryOption[]) {
  const map: Record<string, AccessoryOption[]> = {};
  for (const a of accessories) {
    const key = a.series || "ทั่วไป";
    if (!map[key]) map[key] = [];
    map[key].push(a);
  }
  // Sort groups: "ทั่วไป" (General) last, others alphabetically
  const entries = Object.entries(map).sort(([a], [b]) => {
    if (a === "ทั่วไป") return 1;
    if (b === "ทั่วไป") return -1;
    return a.localeCompare(b);
  });
  return entries;
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
            <p className="text-sm text-gray-400">ยังไม่มีชิ้นส่วนโปรไฟล์ คลิก &quot;เพิ่มชิ้นส่วนโปรไฟล์&quot; เพื่อเริ่มต้น</p>
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
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
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
                    ความยาวเส้นเต็ม (ซม.) — กำหนดเอง
                  </label>
                  <input type="number" min={1} value={row.barLengthMm ? Number(row.barLengthMm) / 10 : ""}
                    onChange={e => onChange(idx, "barLengthMm", e.target.value ? String(Number(e.target.value) * 10) : "")}
                    placeholder="เว้นว่างไว้เพื่อใช้ค่าเริ่มต้นของรูปแบบงาน"
                    className={`${inpSm} w-full`} />
                </div>

                {/* Formula */}
                <div className="sm:col-span-2">
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    สูตรคำนวณ — W/H หน่วย ซม. <span className="text-red-500">*</span>
                  </label>
                  <input type="text" value={row.formula}
                    onChange={e => onChange(idx, "formula", e.target.value)}
                    placeholder='เช่น "H - 35" หรือ "W / 2 + 10"'
                    className={row.formulaError ? inpErr : inp} />
                  <p className="text-xs text-gray-400 mt-1">
                    ตัวแปรที่ใช้ได้: <strong className="text-gray-600">W</strong> (กว้าง), <strong className="text-gray-600">H</strong> (สูง), <strong className="text-gray-600">H1</strong> (ความสูงช่องบน), <strong className="text-gray-600">H2</strong> (ความสูงช่องล่าง), <strong className="text-gray-600">W1</strong> (ความกว้างช่องซ้าย), <strong className="text-gray-600">W2</strong> (ความกว้างช่องขวา)
                  </p>
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
  rows: GlassRow[];
  glassOptions: GlassOption[];
  onChange: (idx: number, field: keyof GlassRow, value: string | number) => void;
  onAdd: () => void;
  onRemove: (idx: number) => void;
  onMove: (idx: number, dir: -1 | 1) => void;
};

export function GlassSection({ rows, glassOptions, onChange, onAdd, onRemove, onMove }: GlassSectionProps) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
      <div className="h-1 bg-gradient-to-r from-sky-400 to-blue-500" />
      <div className="p-5 sm:p-6">
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-sky-100 rounded-xl flex items-center justify-center">
              <FlaskConical className="w-4 h-4 text-sky-600" />
            </div>
            <div>
              <h3 className="font-bold text-gray-900">ข้อมูลกระจก</h3>
              <p className="text-xs text-gray-400">รายการชุดกระจกที่มีอยู่ในรูปแบบงาน (ไม่บังคับ)</p>
            </div>
          </div>
          <button type="button" onClick={onAdd}
            className="inline-flex items-center gap-1.5 text-sm font-semibold text-sky-600 hover:text-sky-700 bg-sky-50 hover:bg-sky-100 px-3 py-1.5 rounded-lg transition-colors">
            <PlusCircle className="w-4 h-4" /> เพิ่มชุดกระจก
          </button>
        </div>

        {rows.length === 0 && (
          <div className="text-center py-6 border-2 border-dashed border-gray-200 rounded-xl">
            <FlaskConical className="w-7 h-7 text-gray-300 mx-auto mb-2" />
            <p className="text-sm text-gray-400">ยังไม่มีรายการชุดกระจก คลิก &quot;เพิ่มชุดกระจก&quot; เพื่อสร้างสูตรคำนวณกระจก</p>
          </div>
        )}

        <div className="space-y-3">
          {rows.map((row, idx) => (
            <div key={row._key} className="border border-gray-200 rounded-xl p-4 bg-gray-50/50 hover:bg-white transition-colors">
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-bold text-gray-400 uppercase tracking-wide">ชุดกระจก #{idx + 1}</span>
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

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Label / Name */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    ชื่อตำแหน่งกระจก <span className="text-red-500">*</span>
                  </label>
                  <input type="text" value={row.label}
                    onChange={e => onChange(idx, "label", e.target.value)}
                    placeholder='เช่น "กระจกบานเลื่อน" หรือ "กระจกช่องแสง"'
                    className={inp} />
                </div>

                {/* Glass type dropdown */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    ชนิดกระจก <span className="text-red-500">*</span>
                  </label>
                  {glassOptions.length > 0 ? (
                    <select
                      value={row.glassType}
                      onChange={e => {
                        const selectedName = e.target.value;
                        onChange(idx, "glassType", selectedName);
                        // Auto-fill price from master data
                        const found = glassOptions.find(g => g.name === selectedName);
                        if (found) {
                          onChange(idx, "pricePerSqM", found.pricePerSqM);
                        }
                      }}
                      className={inp}
                    >
                      <option value="">— เลือกชนิดกระจก —</option>
                      {glassOptions.map(g => (
                        <option key={g.id} value={g.name}>
                          {g.name}
                        </option>
                      ))}
                    </select>
                  ) : (
                    <input
                      type="text"
                      value={row.glassType}
                      onChange={e => onChange(idx, "glassType", e.target.value)}
                      placeholder='เช่น "6mm Clear Tempered"'
                      className={inp}
                    />
                  )}
                  {glassOptions.length === 0 && (
                    <p className="text-xs text-amber-600 mt-1">
                      ⚠ ยังไม่มีข้อมูลกระจกในระบบ —{" "}
                      <a href="/admin/glass/new" target="_blank" className="underline">เพิ่มกระจก</a>
                    </p>
                  )}
                </div>

                {/* Width formula */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    สูตรความกว้างกระจก (ผลลัพธ์หน่วย ซม.) <span className="text-red-500">*</span>
                  </label>
                  <input type="text" value={row.widthFormula}
                    onChange={e => onChange(idx, "widthFormula", e.target.value)}
                    placeholder='เช่น "W / 2 - 30"'
                    className={row.widthFormulaError ? inpErr : inp} />
                  <p className="text-xs text-gray-400 mt-1">
                    ตัวแปรที่ใช้ได้: W, H, W1, W2, H1, H2
                  </p>
                  {row.widthFormulaError
                    ? <p className="text-xs text-red-600 mt-1">⚠ {row.widthFormulaError}</p>
                    : row.widthFormula && <p className="text-xs text-green-600 mt-1">✓ ถูกต้อง</p>}
                </div>

                {/* Height formula */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    สูตรความสูงกระจก (ผลลัพธ์หน่วย ซม.) <span className="text-red-500">*</span>
                  </label>
                  <input type="text" value={row.heightFormula}
                    onChange={e => onChange(idx, "heightFormula", e.target.value)}
                    placeholder='เช่น "H - 80"'
                    className={row.heightFormulaError ? inpErr : inp} />
                  <p className="text-xs text-gray-400 mt-1">
                    ตัวแปรที่ใช้ได้: W, H, W1, W2, H1, H2
                  </p>
                  {row.heightFormulaError
                    ? <p className="text-xs text-red-600 mt-1">⚠ {row.heightFormulaError}</p>
                    : row.heightFormula && <p className="text-xs text-green-600 mt-1">✓ ถูกต้อง</p>}
                </div>

                {/* Panel count */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">จำนวนบานกระจก <span className="text-red-500">*</span></label>
                  <input type="number" min={1} value={row.panelCount}
                    onChange={e => onChange(idx, "panelCount", parseInt(e.target.value) || 1)}
                    className={`${inpSm} w-full`} />
                </div>

                {/* Price per m² */}
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">ราคาต่อตารางเมตร (฿) <span className="text-red-500">*</span></label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-sm">฿</span>
                    <input type="number" min={0} step={0.01} value={row.pricePerSqM}
                      onChange={e => onChange(idx, "pricePerSqM", parseFloat(e.target.value) || 0)}
                      className={`${inpSm} w-full pl-7`} />
                  </div>
                  {row.glassType && (
                    <p className="text-xs text-gray-400 mt-1">สามารถแก้ไขราคาได้หลังจากเลือกชนิดกระจก</p>
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
// ACCESSORIES SECTION
// ════════════════════════════════════════════════════════════════════════════
type AccessoriesSectionProps = {
  rows: AccessoryRow[];
  accessoryOptions: AccessoryOption[];
  onChange: (idx: number, field: keyof AccessoryRow, value: string | number) => void;
  onAdd: () => void;
  onRemove: (idx: number) => void;
  onMove: (idx: number, dir: -1 | 1) => void;
};

export function AccessoriesSection({ rows, accessoryOptions, onChange, onAdd, onRemove, onMove }: AccessoriesSectionProps) {
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

              <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
                {/* Name Dropdown */}
                <div className="col-span-2 sm:col-span-2">
                  <label className="block text-xs font-semibold text-gray-600 mb-1">
                    ชื่ออุปกรณ์ <span className="text-red-500">*</span>
                  </label>
                  <select
                    value={row.name}
                    onChange={(e) => {
                      const selectedName = e.target.value;
                      onChange(idx, "name", selectedName);
                      
                      const acc = accessoryOptions.find((a) => a.name === selectedName);
                      if (acc) {
                        onChange(idx, "unit", acc.unit);
                        onChange(idx, "unitCost", acc.baseCost);
                      }
                    }}
                    className={inp}
                  >
                    <option value="">— เลือกอุปกรณ์เสริม —</option>
                    {buildGroupedAccessories(accessoryOptions).map(([series, items]) => (
                      <optgroup key={series} label={series}>
                        {items.map((acc) => (
                          <option key={acc.id} value={acc.name}>
                            {acc.code} — {acc.name}
                          </option>
                        ))}
                      </optgroup>
                    ))}
                  </select>
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
