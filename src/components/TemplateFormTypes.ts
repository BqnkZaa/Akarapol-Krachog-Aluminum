// Shared row types for TemplateForm client state.
// Separate from the server DTO types in actions/template.ts because the
// form needs a stable client-side `_key` for React list rendering and
// stores intermediate validation state per-row.

export type ComponentRow = {
  _key: string;
  categoryId: string; // Used to filter the materials dropdown
  materialId: string;
  label: string;
  formula: string;
  formulaError: string | null; // live client-side validation feedback
  quantity: number;
  barLengthMm: string; // stored as string so the input can be empty
  sortOrder: number;
};

export type AccessoryRow = {
  _key: string;
  name: string;
  quantity: number;
  unitCost: number;
  unit: string;
  sortOrder: number;
};

export type GlassRow = {
  enabled: boolean;
  widthFormula: string;
  widthFormulaError: string | null;
  heightFormula: string;
  heightFormulaError: string | null;
  panelCount: number;
  glassType: string;
  pricePerSqM: number;
};

export function makeEmptyComponent(order: number): ComponentRow {
  return {
    _key: `c-${Date.now()}-${order}`,
    categoryId: "",
    materialId: "",
    label: "",
    formula: "",
    formulaError: null,
    quantity: 1,
    barLengthMm: "",
    sortOrder: order,
  };
}

export function makeEmptyAccessory(order: number): AccessoryRow {
  return {
    _key: `a-${Date.now()}-${order}`,
    name: "",
    quantity: 1,
    unitCost: 0,
    unit: "ชุด",
    sortOrder: order,
  };
}

export const defaultGlass: GlassRow = {
  enabled: false,
  widthFormula: "",
  widthFormulaError: null,
  heightFormula: "",
  heightFormulaError: null,
  panelCount: 1,
  glassType: "6mm Clear Tempered",
  pricePerSqM: 0,
};
