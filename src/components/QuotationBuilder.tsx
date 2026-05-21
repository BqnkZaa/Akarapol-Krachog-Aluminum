"use client";

import React, { useState, useEffect } from "react";
import {
  ArrowRight, AlertCircle, Printer,
  Calculator, Box, Check, Ruler, Settings2, LayoutTemplate, Palette, ArrowLeft, Image as ImageIcon,
  Loader2, Trash2
} from "lucide-react";
import { useSearchParams } from "next/navigation";
import {
  runParametricEstimation,
  getAvailableColors,
  type TemplateOption,
  type ColorOption,
  type RunEstimationResult
} from "@/actions/estimation";
import { getQuotationById, updateQuotation } from "@/actions/quotation";

type QuotationBuilderProps = {
  initialTemplates: TemplateOption[];
};

interface EstimationResultWithComponents {
  components?: Array<{
    label: string;
    formula: string;
    lengthMm: number;
    quantity: number;
  }>;
}

export default function QuotationBuilder({ initialTemplates }: QuotationBuilderProps) {
  // --- Search Params & Edit Mode ---
  const searchParams = useSearchParams();
  const editId = searchParams.get("edit");
  const [isHydrating, setIsHydrating] = useState(false);

  // --- Wizard State ---
  // Steps: 1: Template, 2: Color, 3: Dimensions, 4: Pricing
  const [currentStep, setCurrentStep] = useState<number>(1);

  // --- Form Data ---
  const [selectedCategoryName, setSelectedCategoryName] = useState<string | null>(null);
  const [selectedTemplate, setSelectedTemplate] = useState<TemplateOption | null>(null);
  const [availableColors, setAvailableColors] = useState<ColorOption[]>([]);
  const [isLoadingColors, setIsLoadingColors] = useState(false);
  const [selectedColor, setSelectedColor] = useState<ColorOption | null>(null);

  const [widthCm, setWidthCm] = useState<number>(200);
  const [heightCm, setHeightCm] = useState<number>(150);
  const [h1Cm, setH1Cm] = useState<number | "">("");
  const [h2Cm, setH2Cm] = useState<number | "">("");
  const [w1Cm, setW1Cm] = useState<number | "">("");
  const [w2Cm, setW2Cm] = useState<number | "">("");
  const [projectName, setProjectName] = useState("");
  const [customerName, setCustomerName] = useState("");

  const [marginPercent, setMarginPercent] = useState<number>(20);
  const [laborCostPerSqM, setLaborCostPerSqM] = useState<number>(0);
  const [discountPercent, setDiscountPercent] = useState<number>(0);

  // --- Flexible Pricing & Quantity Overrides ---
  const [setsCount, setSetsCount] = useState<number>(1);
  const [customUnitPrice, setCustomUnitPrice] = useState<string>("");

  // --- Submission State ---
  const [isCalculating, setIsCalculating] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [result, setResult] = useState<Extract<RunEstimationResult, { success: true }> | null>(null);

  // --- Hybrid Parametric + Manual Override Local States ---
  const [isManualOverride, setIsManualOverride] = useState<boolean>(false);
  const [editableMaterials, setEditableMaterials] = useState<any[]>([]);
  const [editableAccessories, setEditableAccessories] = useState<any[]>([]);
  const [editableGlass, setEditableGlass] = useState<any[]>([]);
  const [isSavingOverride, setIsSavingOverride] = useState<boolean>(false);

  // --- Effects ---
  useEffect(() => {
    if (selectedTemplate) {
      getAvailableColors(selectedTemplate.id).then((colors) => {
        setAvailableColors(colors);
        setIsLoadingColors(false);
      });
    }
  }, [selectedTemplate]);

  // Hydration effect for Edit Mode
  useEffect(() => {
    if (!editId) {
      return;
    }

    setIsHydrating(true);
    setErrorMsg(null);

    getQuotationById(editId).then((project) => {
      setIsHydrating(false);
      if (!project) {
        setErrorMsg("ไม่พบข้อมูลใบเสนอราคาที่เลือกแก้ไข");
        return;
      }

      // Pre-populate/hydrate the entire wizard state
      setProjectName(project.projectName);
      setCustomerName(project.customerName || "");
      setWidthCm(project.widthMm / 10);
      setHeightCm(project.heightMm / 10);
      setH1Cm(project.h1 !== null && project.h1 !== undefined ? project.h1 / 10 : "");
      setH2Cm(project.h2 !== null && project.h2 !== undefined ? project.h2 / 10 : "");
      setW1Cm(project.w1 !== null && project.w1 !== undefined ? project.w1 / 10 : "");
      setW2Cm(project.w2 !== null && project.w2 !== undefined ? project.w2 / 10 : "");
      setMarginPercent(project.profitMarginPercent);
      setDiscountPercent(project.discountPercent);

      // Reconstruct laborCostPerSqM from flat laborCost and dimensions
      const openingAreaSqM = (project.widthMm * project.heightMm) / 1_000_000;
      const laborPerSqM = openingAreaSqM > 0 
        ? Math.round(project.laborCost / openingAreaSqM) 
        : 0;
      setLaborCostPerSqM(laborPerSqM);

      // Hydrate selected Template matching the ID from initialTemplates
      const templateOpt = initialTemplates.find((t) => t.id === project.templateId);
      if (templateOpt) {
        setSelectedTemplate(templateOpt);
        setSelectedCategoryName(templateOpt.categoryName);
      }

      // Hydrate selected Color
      setSelectedColor({
        id: project.color.id,
        name: project.color.name,
        hexCode: project.color.hexCode,
      });

      // Hydrate local editable states
      const hydratedMaterials = project.cuttingResults as any || [];
      const hydratedAccessories = project.accessories as any || [];
      let hydratedGlass: any[] = [];
      if (project.glassDetail) {
        if (Array.isArray(project.glassDetail)) {
          hydratedGlass = project.glassDetail;
        } else {
          hydratedGlass = [project.glassDetail];
        }
      }
      setEditableMaterials(hydratedMaterials);
      setEditableAccessories(hydratedAccessories);
      setEditableGlass(hydratedGlass);
      setIsManualOverride(project.isManualOverride || false);

      // Hydrate result view immediately with snapshotted details
      setResult({
        success: true,
        projectId: project.id,
        templateName: project.template.name,
        colorName: project.color.name,
        widthMm: project.widthMm,
        heightMm: project.heightMm,
        w1: project.w1 ?? undefined,
        w2: project.w2 ?? undefined,
        h1: project.h1 ?? undefined,
        h2: project.h2 ?? undefined,
        cuttingResults: project.cuttingResults as any,
        glassDetail: project.glassDetail as any,
        accessories: project.accessories as any,
        summary: project.summary as any,
      });

      setCurrentStep(4);
    }).catch((err) => {
      console.error(err);
      setIsHydrating(false);
      setErrorMsg("ไม่สามารถดึงข้อมูลใบเสนอราคาได้");
    });
  }, [editId, initialTemplates]);

  // --- Handlers ---
  const handleWidthChange = (w: number) => {
    setWidthCm(w);
    if (w1Cm !== "" && typeof w1Cm === "number") {
      setW2Cm(Math.max(0, parseFloat((w - w1Cm).toFixed(2))));
    } else if (w2Cm !== "" && typeof w2Cm === "number") {
      setW1Cm(Math.max(0, parseFloat((w - w2Cm).toFixed(2))));
    }
  };

  const handleHeightChange = (h: number) => {
    setHeightCm(h);
    if (h1Cm !== "" && typeof h1Cm === "number") {
      setH2Cm(Math.max(0, parseFloat((h - h1Cm).toFixed(2))));
    } else if (h2Cm !== "" && typeof h2Cm === "number") {
      setH1Cm(Math.max(0, parseFloat((h - h2Cm).toFixed(2))));
    }
  };

  const handleW1Change = (val: string) => {
    if (val === "") {
      setW1Cm("");
      return;
    }
    const num = Number(val);
    setW1Cm(num);
    setW2Cm(Math.max(0, parseFloat((widthCm - num).toFixed(2))));
  };

  const handleW2Change = (val: string) => {
    if (val === "") {
      setW2Cm("");
      return;
    }
    const num = Number(val);
    setW2Cm(num);
    setW1Cm(Math.max(0, parseFloat((widthCm - num).toFixed(2))));
  };

  const handleH1Change = (val: string) => {
    if (val === "") {
      setH1Cm("");
      return;
    }
    const num = Number(val);
    setH1Cm(num);
    setH2Cm(Math.max(0, parseFloat((heightCm - num).toFixed(2))));
  };

  const handleH2Change = (val: string) => {
    if (val === "") {
      setH2Cm("");
      return;
    }
    const num = Number(val);
    setH2Cm(num);
    setH1Cm(Math.max(0, parseFloat((heightCm - num).toFixed(2))));
  };

  const handleSelectTemplate = (template: TemplateOption) => {
    setSelectedTemplate(template);
    setSelectedColor(null);
    setIsLoadingColors(true);
    setCurrentStep(2);
  };

  const handleSelectColor = (color: ColorOption) => {
    setSelectedColor(color);
    setCurrentStep(3);
  };

  const handleCalculate = async () => {
    if (!selectedTemplate || !selectedColor) return;
    if (!projectName.trim()) {
      setErrorMsg("กรุณาระบุชื่อโปรเจกต์");
      return;
    }

    setIsCalculating(true);
    setErrorMsg(null);

    const payload = {
      templateId: selectedTemplate.id,
      colorId: selectedColor.id,
      widthMm: widthCm * 10,
      heightMm: heightCm * 10,
      h1: h1Cm !== "" ? Number(h1Cm) * 10 : undefined,
      h2: h2Cm !== "" ? Number(h2Cm) * 10 : undefined,
      w1: w1Cm !== "" ? Number(w1Cm) * 10 : undefined,
      w2: w2Cm !== "" ? Number(w2Cm) * 10 : undefined,
      projectName,
      customerName,
      profitMarginPercent: marginPercent,
      laborCostPerSqM,
      discountPercent,
    };

    const res = editId
      ? await updateQuotation(editId, payload)
      : await runParametricEstimation(payload);

    setIsCalculating(false);

    if (res.success) {
      setResult(res);
      // Initialize local states from result
      setEditableMaterials(res.cuttingResults || []);
      setEditableAccessories(res.accessories || []);
      if (res.glassDetail) {
        if (Array.isArray(res.glassDetail)) {
          setEditableGlass(res.glassDetail);
        } else {
          setEditableGlass([res.glassDetail]);
        }
      } else {
        setEditableGlass([]);
      }
      setIsManualOverride(false);

      // Dynamically push to edit mode URL to support immediate manual overrides
      if (!editId && res.projectId) {
        const newUrl = `${window.location.pathname}?edit=${res.projectId}`;
        window.history.pushState({ path: newUrl }, "", newUrl);
      }

      window.scrollTo({ top: 0, behavior: 'smooth' });
    } else {
      setErrorMsg(res.error);
    }
  };

  // --- Materials Handlers ---
  const handleUpdateMaterial = (index: number, updates: Partial<any>) => {
    setIsManualOverride(true);
    setEditableMaterials(prev => prev.map((item, idx) => {
      if (idx === index) {
        const updated = { ...item, ...updates };
        updated.materialLineCost = updated.barsRequired * updated.barUnitCost;
        return updated;
      }
      return item;
    }));
  };

  const handleDeleteMaterial = (index: number) => {
    setIsManualOverride(true);
    setEditableMaterials(prev => prev.filter((_, idx) => idx !== index));
  };

  const handleAddMaterial = () => {
    setIsManualOverride(true);
    const newMaterial = {
      materialId: "",
      materialCode: "CUSTOM-MAT",
      materialName: "รายการอลูมิเนียมกำหนดเอง",
      barLengthMm: selectedTemplate ? selectedTemplate.standardBarLengthMm : 6000,
      barsRequired: 1,
      barUnitCost: 0,
      materialLineCost: 0,
      totalCutsMm: 0,
      totalWasteMm: 0,
      wastePercent: 0,
      utilizationPercent: 100,
      bars: []
    };
    setEditableMaterials(prev => [...prev, newMaterial]);
  };

  // --- Accessories Handlers ---
  const handleUpdateAccessory = (index: number, updates: Partial<any>) => {
    setIsManualOverride(true);
    setEditableAccessories(prev => prev.map((item, idx) => {
      if (idx === index) {
        const updated = { ...item, ...updates };
        updated.lineCost = updated.quantity * updated.unitCost;
        return updated;
      }
      return item;
    }));
  };

  const handleDeleteAccessory = (index: number) => {
    setIsManualOverride(true);
    setEditableAccessories(prev => prev.filter((_, idx) => idx !== index));
  };

  const handleAddAccessory = () => {
    setIsManualOverride(true);
    const newAccessory = {
      name: "รายการอุปกรณ์เสริมกำหนดเอง",
      quantity: 1,
      unitCost: 0,
      unit: "ชิ้น",
      lineCost: 0
    };
    setEditableAccessories(prev => [...prev, newAccessory]);
  };

  // --- Glass Handlers ---
  const handleUpdateGlass = (index: number, updates: Partial<any>) => {
    setIsManualOverride(true);
    setEditableGlass(prev => prev.map((item, idx) => {
      if (idx === index) {
        const updated = { ...item, ...updates };
        const width = updated.widthPerPanelMm || 0;
        const height = updated.heightPerPanelMm || 0;
        const panels = updated.panelCount || 0;
        const price = updated.pricePerSqFt || 0;
        
        const MM2_PER_SQFT = 92903.04;
        const areaSqFt = panels * (width * height) / MM2_PER_SQFT;
        
        updated.areaSqFt = Math.round(areaSqFt * 10000) / 10000;
        if (updates.glassCost === undefined) {
          updated.glassCost = Math.round(areaSqFt * price * 100) / 100;
        }
        return updated;
      }
      return item;
    }));
  };

  const handleDeleteGlass = (index: number) => {
    setIsManualOverride(true);
    setEditableGlass(prev => prev.filter((_, idx) => idx !== index));
  };

  const handleAddGlass = () => {
    setIsManualOverride(true);
    const newGlass = {
      glassType: "กระจกกำหนดเอง",
      panelCount: 1,
      widthPerPanelMm: 1000,
      heightPerPanelMm: 1000,
      areaSqFt: 10.7639,
      pricePerSqFt: 0,
      glassCost: 0
    };
    setEditableGlass(prev => [...prev, newGlass]);
  };

  // --- Save Manual Overrides ---
  const handleSaveManualOverrides = async () => {
    const activeEditId = editId || result?.projectId;
    if (!activeEditId) {
      setErrorMsg("สามารถบันทึกการแก้ไขแบบกำหนดเองได้เฉพาะใบเสนอราคาเดิมที่บันทึกแล้วเท่านั้น");
      return;
    }
    if (!projectName.trim()) {
      setErrorMsg("กรุณาระบุชื่อโปรเจกต์");
      return;
    }

    setIsSavingOverride(true);
    setErrorMsg(null);

    const payload = {
      templateId: selectedTemplate?.id || "",
      colorId: selectedColor?.id || "",
      widthMm: widthCm * 10,
      heightMm: heightCm * 10,
      h1: h1Cm !== "" ? Number(h1Cm) * 10 : undefined,
      h2: h2Cm !== "" ? Number(h2Cm) * 10 : undefined,
      w1: w1Cm !== "" ? Number(w1Cm) * 10 : undefined,
      w2: w2Cm !== "" ? Number(w2Cm) * 10 : undefined,
      projectName,
      customerName,
      profitMarginPercent: marginPercent,
      laborCostPerSqM,
      discountPercent,
      isManualOverride: true,
      manualMaterials: editableMaterials,
      manualAccessories: editableAccessories,
      manualGlass: editableGlass,
    };

    try {
      const res = await updateQuotation(activeEditId, payload);
      setIsSavingOverride(false);

      if (res.success) {
        setResult(res);
        setEditableMaterials(res.cuttingResults || []);
        setEditableAccessories(res.accessories || []);
        if (res.glassDetail) {
          if (Array.isArray(res.glassDetail)) {
            setEditableGlass(res.glassDetail);
          } else {
            setEditableGlass([res.glassDetail]);
          }
        } else {
          setEditableGlass([]);
        }
        setIsManualOverride(true);
        alert("บันทึกการแก้ไขแบบกำหนดเองเรียบร้อยแล้ว!");
      } else {
        setErrorMsg(res.error);
      }
    } catch (err: any) {
      setIsSavingOverride(false);
      setErrorMsg("เกิดข้อผิดพลาดในการบันทึกข้อมูล: " + (err.message || err));
    }
  };

  // --- RENDER: Result View ────────────────────────────────────────────────────────
  if (result) {
    // Dynamic real-time calculation of subtotal and totals based on local editable states
    const computedMaterialCost = editableMaterials.reduce((sum, item) => sum + (item.barsRequired * item.barUnitCost), 0);
    const computedGlassCost = editableGlass.reduce((sum, item) => sum + (item.glassCost || 0), 0);
    const computedAccessoryCost = editableAccessories.reduce((sum, item) => sum + (item.quantity * item.unitCost), 0);

    const computedSubtotal = computedMaterialCost + computedGlassCost + computedAccessoryCost;
    const computedMarginAmount = computedSubtotal * (marginPercent / 100);
    
    // Labor cost computed from opening area
    const openingAreaSqM = ((widthCm * 10) * (heightCm * 10)) / 1_000_000;
    const computedLaborCost = Math.round(openingAreaSqM * laborCostPerSqM * 100) / 100;
    const computedAdditionalCost = result.summary.additionalCost || 0;

    const computedBeforeDiscount = computedSubtotal + computedMarginAmount + computedLaborCost + computedAdditionalCost;
    const computedDiscountAmount = computedBeforeDiscount * (discountPercent / 100);
    const computedFinalPrice = computedBeforeDiscount - computedDiscountAmount;

    const finalPriceOneSet = computedFinalPrice;
    const unitPrice = customUnitPrice !== "" ? (parseFloat(customUnitPrice) || 0) : finalPriceOneSet;
    const totalPrice = unitPrice * setsCount;
    const resultWithComponents = result as Extract<RunEstimationResult, { success: true }> & EstimationResultWithComponents;

    return (
      <div className="max-w-7xl mx-auto p-3 md:p-8 grid grid-cols-1 lg:grid-cols-12 gap-8 print:block print:p-0">

        {/* Left Column: BOM & Cut Sheet */}
        <div className="lg:col-span-8 space-y-8 print:w-full print:space-y-4">
          {/* Header Info with Elevation Drawing */}
          <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm print:shadow-none print:border-gray-300 print:p-4">
            <div className="flex flex-col md:flex-row gap-6">

              {/* Visual Drawing / Image Placeholder */}
              <div className="w-full md:w-48 h-48 bg-gray-50 border-2 border-dashed border-gray-200 rounded-xl flex flex-col items-center justify-center shrink-0 overflow-hidden relative print:border-solid print:bg-white print:border-gray-300 print:w-32 print:h-32">
                {selectedTemplate?.imageUrl ? (
                  <img src={selectedTemplate.imageUrl} alt={result.templateName} className="object-cover w-full h-full" />
                ) : (
                  <>
                    <ImageIcon className="w-8 h-8 text-gray-300 mb-2" />
                    <span className="text-xs text-gray-400 font-medium px-4 text-center">รอรูปภาพประกอบ</span>
                  </>
                )}
              </div>

              {/* Project Details */}
              <div className="flex-1">
                <div className="flex justify-between items-start mb-6 print:mb-3">
                  <div>
                    <h2 className="text-2xl font-bold text-gray-900">{projectName}</h2>
                    {customerName && <p className="text-gray-500 mt-1">ลูกค้า: {customerName}</p>}
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-gray-500">รหัส: {result.projectId.slice(-8).toUpperCase()}</p>
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-6 border-t border-gray-100 text-sm print:pt-3 print:mt-3 print:gap-2">
                  <div>
                    <p className="text-gray-500 mb-1">รูปแบบงาน</p>
                    <p className="font-semibold text-gray-900 leading-tight">{result.templateName}</p>
                  </div>
                  <div>
                    <p className="text-gray-500 mb-1">สี</p>
                    <p className="font-semibold text-gray-900">{result.colorName}</p>
                  </div>
                  <div>
                    <p className="text-gray-500 mb-1">ความกว้าง (W)</p>
                    <p className="font-semibold text-gray-900">{(result.widthMm / 10).toLocaleString()} ซม.</p>
                    {((result as any).w1 !== undefined && (result as any).w1 !== null || (result as any).w2 !== undefined && (result as any).w2 !== null) && (
                      <p className="text-[11px] text-gray-400 mt-0.5 leading-none">
                        (ซ้าย W1: {(result as any).w1 ? ((result as any).w1 / 10).toLocaleString() : "0"} / ขวา W2: {(result as any).w2 ? ((result as any).w2 / 10).toLocaleString() : ((result.widthMm - ((result as any).w1 || 0)) / 10).toLocaleString()} ซม.)
                      </p>
                    )}
                  </div>
                  <div>
                    <p className="text-gray-500 mb-1">ความสูง (H)</p>
                    <p className="font-semibold text-gray-900">{(result.heightMm / 10).toLocaleString()} ซม.</p>
                    {((result as any).h1 !== undefined && (result as any).h1 !== null || (result as any).h2 !== undefined && (result as any).h2 !== null) && (
                      <p className="text-[11px] text-gray-400 mt-0.5 leading-none">
                        (บน H1: {(result as any).h1 ? ((result as any).h1 / 10).toLocaleString() : "0"} / ล่าง H2: {(result as any).h2 ? ((result as any).h2 / 10).toLocaleString() : ((result.heightMm - ((result as any).h1 || 0)) / 10).toLocaleString()} ซม.)
                      </p>
                    )}
                  </div>
                </div>
              </div>

            </div>
          </div>

          {/* Component Breakdown / Itemized List (Updated to cm) */}
          {!isManualOverride && resultWithComponents.components && resultWithComponents.components.length > 0 && (
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 print:break-inside-avoid mb-8 print:mb-4 print:shadow-none print:border-gray-300 print:p-4">
              <h3 className="font-semibold text-gray-900 mb-4 border-b border-gray-100 pb-2 print:mb-2 print:pb-1">รายการชิ้นส่วน (Component Breakdown)</h3>
              <div className="space-y-4 print:space-y-2">
                {resultWithComponents.components.map((comp, idx) => (
                  <div key={idx} className="flex justify-between items-center text-sm border-b border-gray-50 pb-2">
                    <div>
                      <span className="font-medium text-gray-900">{comp.label}</span>
                      <span className="text-gray-500 ml-2 text-xs">(สูตร: {comp.formula})</span>
                    </div>
                    <div className="text-right">
                      <span className="text-gray-600 mr-4">
                        ความยาวชิ้นงาน: <span className="font-medium text-gray-900">{(comp.lengthMm / 10).toFixed(1)}</span> ซม.
                      </span>
                      <span className="text-gray-600">
                        จำนวน: <span className="font-medium text-gray-900">{comp.quantity}</span> ชิ้น
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Cutting Results */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden print:shadow-none print:border-gray-300">
            <div className="bg-gray-50 p-4 border-b border-gray-100 flex justify-between items-center print:p-3">
              <div className="flex items-center gap-2">
                <Box className="w-5 h-5 text-blue-600" />
                <h3 className="font-semibold text-gray-900">รายการวัสดุอลูมิเนียม</h3>
              </div>
              <button
                onClick={handleAddMaterial}
                className="text-xs font-bold text-blue-600 hover:text-blue-700 bg-blue-50 hover:bg-blue-100 px-2.5 py-1 rounded-lg transition-all print:hidden"
              >
                + เพิ่มรายการอลูมิเนียมนอกสูตร
              </button>
            </div>
            <div className="divide-y divide-gray-100">
              {editableMaterials.map((cr, idx) => (
                <div key={`${cr.materialId}-${idx}`} className="p-4 md:p-6 print:p-4 print:break-inside-avoid">
                  <div className="flex justify-between items-start gap-4 mb-4 print:mb-2">
                    <div className="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                      <div>
                        <input
                          type="text"
                          value={cr.materialName}
                          onChange={(e) => handleUpdateMaterial(idx, { materialName: e.target.value })}
                          placeholder="ชื่อโปรไฟล์อลูมิเนียม"
                          className="w-full text-base font-bold text-gray-900 border border-gray-200 rounded px-2.5 py-1 focus:ring-1 focus:ring-blue-500 print:border-none print:bg-transparent print:p-0 print:text-base print:font-bold print:shadow-none print:outline-none print:focus:ring-0 print:pointer-events-none"
                        />
                      </div>
                      <div className="flex flex-wrap items-center gap-2">
                        <input
                          type="text"
                          value={cr.materialCode}
                          onChange={(e) => handleUpdateMaterial(idx, { materialCode: e.target.value })}
                          placeholder="รหัสวัสดุ"
                          className="w-28 text-xs text-gray-600 font-mono border border-gray-200 rounded px-2 py-1.5 focus:ring-1 focus:ring-blue-500 print:border-none print:bg-transparent print:p-0 print:text-xs print:shadow-none print:outline-none print:focus:ring-0 print:pointer-events-none"
                        />
                        <div className="flex items-center gap-1 text-xs text-gray-500">
                          <span className="print:hidden">ยาว:</span>
                          <input
                            type="number"
                            min="1"
                            value={cr.barLengthMm / 10}
                            onChange={(e) => handleUpdateMaterial(idx, { barLengthMm: Number(e.target.value) * 10 })}
                            className="w-16 text-right border border-gray-200 rounded px-1 py-0.5 text-xs focus:ring-1 focus:ring-blue-500 print:hidden font-mono"
                          />
                          <span className="font-semibold text-gray-800">{(cr.barLengthMm / 10).toLocaleString()} ซม. ต่อเส้น</span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-3 shrink-0">
                      <button
                        onClick={() => handleDeleteMaterial(idx)}
                        className="p-2 text-red-500 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors print:hidden"
                        title="ลบรายการอลูมิเนียม"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>

                  <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center bg-gray-50/50 rounded-xl p-3 border border-gray-100 gap-3 text-sm print:bg-transparent print:border-none print:p-0 print:mt-1">
                    <div className="flex flex-wrap items-center gap-4">
                      <div className="flex items-center gap-1.5">
                        <span className="font-medium text-gray-600">จำนวนที่ใช้:</span>
                        <input
                          type="number"
                          min="0"
                          value={cr.barsRequired}
                          onChange={(e) => handleUpdateMaterial(idx, { barsRequired: Math.max(0, parseInt(e.target.value) || 0) })}
                          className="w-16 text-right border border-gray-200 rounded px-2 py-0.5 text-xs font-bold text-blue-600 focus:ring-1 focus:ring-blue-500 print:hidden"
                        />
                        <span className="hidden print:inline font-bold text-blue-600">{cr.barsRequired}</span>
                        <span className="font-bold text-blue-600">เส้น</span>
                      </div>

                      <div className="flex items-center gap-1.5">
                        <span className="font-medium text-gray-600">ราคาต่อเส้น:</span>
                        <span className="text-gray-400">฿</span>
                        <input
                          type="number"
                          min="0"
                          value={cr.barUnitCost}
                          onChange={(e) => handleUpdateMaterial(idx, { barUnitCost: Number(e.target.value) })}
                          className="w-24 text-right border border-gray-200 rounded px-2 py-0.5 text-xs font-bold text-gray-800 focus:ring-1 focus:ring-blue-500 print:hidden"
                        />
                        <span className="hidden print:inline font-bold text-gray-800">{cr.barUnitCost.toLocaleString()}</span>
                      </div>
                    </div>

                    <div className="text-left sm:text-right font-semibold text-gray-800 print:text-right">
                      {cr.bars && cr.bars.length > 0 ? (
                        <span className="text-xs text-gray-400 mr-3 print:hidden">ประสิทธิภาพ {cr.utilizationPercent.toFixed(1)}%</span>
                      ) : (
                        <span className="text-xs text-amber-600 mr-3 font-normal print:hidden">แก้ไขแบบกำหนดเอง</span>
                      )}
                      <span>ราคารวม: <span className="text-blue-600 font-bold">฿{cr.materialLineCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span></span>
                    </div>
                  </div>

                  {/* Cut Sheet Visuals */}
                  {cr.bars && cr.bars.length > 0 ? (
                    <div className="space-y-3 mt-4 print:space-y-2 print:mt-2">
                      {cr.bars.map((bar: any) => (
                        <div key={bar.barIndex} className="relative">
                          <div className="flex items-center justify-between text-xs text-gray-500 mb-1">
                            <span>เส้นที่ #{bar.barIndex}</span>
                            <span>เศษเหลือ: {(bar.wasteMm / 10).toFixed(1)} ซม.</span>
                          </div>
                          <div className="h-8 print:h-6 bg-gray-100 rounded-md overflow-hidden flex border border-gray-200 w-full relative">
                            {bar.cuts.map((cut: any, idx: number) => {
                              const pct = (cut.lengthMm / cr.barLengthMm) * 100;
                              const colors = ['bg-blue-500', 'bg-emerald-500', 'bg-purple-500', 'bg-orange-500', 'bg-pink-500', 'bg-indigo-500'];
                              const colorClass = colors[cut.label.length % colors.length];

                              return (
                                <div
                                  key={idx}
                                  style={{ width: `${pct}%` }}
                                  className={`${colorClass} h-full border-r border-white/40 flex items-center justify-center text-[10px] text-white font-bold px-1 overflow-hidden whitespace-nowrap`}
                                  title={`${cut.label}: ${(cut.lengthMm / 10).toFixed(1)} ซม.`}
                                >
                                  {(cut.lengthMm / 10).toFixed(1)}
                                </div>
                              );
                            })}
                            {/* Waste segment */}
                            {bar.wasteMm > 0 && (
                              <div
                                style={{ width: `${(bar.wasteMm / cr.barLengthMm) * 100}%` }}
                                className="bg-stripes h-full opacity-30"
                              />
                            )}
                          </div>
                          <div className="flex flex-wrap gap-x-3 gap-y-1 mt-1.5 print:mt-1 text-[11px] text-gray-600">
                            {bar.cuts.map((cut: any, idx: number) => (
                              <span key={idx}><span className="font-medium text-gray-900">{(cut.lengthMm / 10).toFixed(1)} ซม.</span> ({cut.label})</span>
                            ))}
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="mt-3 text-xs text-gray-400 bg-gray-50 border border-dashed border-gray-200 rounded-lg p-3 text-center print:hidden">
                      ไม่มีแผนภาพการตัดสำหรับรายการนอกเหนือสูตร
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Glass & Accessories side-by-side */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 print:block print:space-y-4">
            
            {/* Glass */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 print:shadow-none print:border-gray-300 print:break-inside-avoid print:p-4">
              <div className="flex justify-between items-center mb-4 border-b border-gray-100 pb-2 print:mb-2 print:pb-1">
                <h3 className="font-semibold text-gray-900">ข้อมูลกระจก</h3>
                <button
                  onClick={handleAddGlass}
                  className="text-xs font-bold text-blue-600 hover:text-blue-700 bg-blue-50 hover:bg-blue-100 px-2.5 py-1 rounded-lg transition-all print:hidden"
                >
                  + เพิ่มกระจกนอกสูตร
                </button>
              </div>

              {editableGlass.length === 0 ? (
                <p className="text-sm text-gray-400 py-2">ไม่มีข้อมูลกระจก</p>
              ) : (
                <div className="space-y-6 divide-y divide-gray-100">
                  {editableGlass.map((g, idx) => (
                    <div key={idx} className={idx > 0 ? "pt-4" : ""}>
                      <div className="flex justify-between items-center gap-2 mb-3">
                        <div className="flex-1">
                          <input
                            type="text"
                            value={g.glassType}
                            onChange={(e) => handleUpdateGlass(idx, { glassType: e.target.value })}
                            placeholder="ประเภทกระจก"
                            className="w-full text-sm font-semibold text-gray-900 border border-gray-200 rounded px-2 py-1 focus:ring-1 focus:ring-blue-500 print:border-none print:bg-transparent print:p-0 print:text-base print:font-bold print:shadow-none print:outline-none print:focus:ring-0 print:pointer-events-none"
                          />
                        </div>
                        <button
                          onClick={() => handleDeleteGlass(idx)}
                          className="p-1.5 text-red-500 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors print:hidden"
                          title="ลบรายการกระจก"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>

                      <div className="grid grid-cols-2 gap-x-4 gap-y-2.5 text-sm text-gray-600">
                        <div className="flex items-center justify-between">
                          <span className="text-xs text-gray-500">ความกว้าง W (ซม.)</span>
                          <div className="flex items-center gap-1">
                            <input
                              type="number"
                              min="0"
                              step="0.1"
                              value={g.widthPerPanelMm / 10}
                              onChange={(e) => handleUpdateGlass(idx, { widthPerPanelMm: Number(e.target.value) * 10 })}
                              className="w-16 text-right border border-gray-200 rounded px-1.5 py-0.5 text-xs focus:ring-1 focus:ring-blue-500 print:hidden font-medium"
                            />
                            <span className="hidden print:inline font-medium text-gray-950">{(g.widthPerPanelMm / 10).toFixed(1)} ซม.</span>
                          </div>
                        </div>

                        <div className="flex items-center justify-between">
                          <span className="text-xs text-gray-500">ความสูง H (ซม.)</span>
                          <div className="flex items-center gap-1">
                            <input
                              type="number"
                              min="0"
                              step="0.1"
                              value={g.heightPerPanelMm / 10}
                              onChange={(e) => handleUpdateGlass(idx, { heightPerPanelMm: Number(e.target.value) * 10 })}
                              className="w-16 text-right border border-gray-200 rounded px-1.5 py-0.5 text-xs focus:ring-1 focus:ring-blue-500 print:hidden font-medium"
                            />
                            <span className="hidden print:inline font-medium text-gray-950">{(g.heightPerPanelMm / 10).toFixed(1)} ซม.</span>
                          </div>
                        </div>

                        <div className="flex items-center justify-between">
                          <span className="text-xs text-gray-500">จำนวนบาน</span>
                          <div className="flex items-center gap-1">
                            <input
                              type="number"
                              min="1"
                              value={g.panelCount}
                              onChange={(e) => handleUpdateGlass(idx, { panelCount: Math.max(1, parseInt(e.target.value) || 1) })}
                              className="w-16 text-right border border-gray-200 rounded px-1.5 py-0.5 text-xs focus:ring-1 focus:ring-blue-500 print:hidden font-semibold text-gray-900"
                            />
                            <span className="hidden print:inline font-semibold text-gray-900">{g.panelCount} บาน</span>
                          </div>
                        </div>

                        <div className="flex items-center justify-between">
                          <span className="text-xs text-gray-500">พื้นที่รวม (ตร.ฟุต)</span>
                          <span className="font-semibold text-gray-800">{g.areaSqFt.toFixed(4)} Sq.Ft</span>
                        </div>

                        <div className="flex items-center justify-between">
                          <span className="text-xs text-gray-500">ราคาต่อ ตร.ฟุต</span>
                          <div className="flex items-center gap-1">
                            <span className="text-xs text-gray-400">฿</span>
                            <input
                              type="number"
                              min="0"
                              step="1"
                              value={g.pricePerSqFt}
                              onChange={(e) => handleUpdateGlass(idx, { pricePerSqFt: Number(e.target.value) })}
                              className="w-20 text-right border border-gray-200 rounded px-1.5 py-0.5 text-xs focus:ring-1 focus:ring-blue-500 print:hidden font-semibold text-gray-900"
                            />
                            <span className="hidden print:inline font-semibold text-gray-900">฿{g.pricePerSqFt.toLocaleString()}</span>
                          </div>
                        </div>

                        <div className="flex items-center justify-between">
                          <span className="text-xs text-gray-500">ค่ากระจก</span>
                          <div className="flex items-center gap-1">
                            <span className="text-xs text-gray-400">฿</span>
                            <input
                              type="number"
                              min="0"
                              step="0.01"
                              value={g.glassCost}
                              onChange={(e) => handleUpdateGlass(idx, { glassCost: Number(e.target.value) })}
                              className="w-24 text-right border border-gray-200 rounded px-1.5 py-0.5 text-xs focus:ring-1 focus:ring-blue-500 print:hidden font-bold text-blue-600"
                            />
                            <span className="hidden print:inline font-bold text-blue-600">฿{g.glassCost.toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                  <div className="flex justify-between font-semibold text-blue-600 mt-2 pt-2 border-t border-gray-50">
                    <span>ค่ากระจกรวม</span>
                    <span>฿{computedGlassCost.toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                  </div>
                </div>
              )}
            </div>

            {/* Accessories */}
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 print:shadow-none print:border-gray-300 print:break-inside-avoid print:p-4">
              <div className="flex justify-between items-center mb-4 border-b border-gray-100 pb-2 print:mb-2 print:pb-1">
                <h3 className="font-semibold text-gray-900">อุปกรณ์เสริม</h3>
                <button
                  onClick={handleAddAccessory}
                  className="text-xs font-bold text-blue-600 hover:text-blue-700 bg-blue-50 hover:bg-blue-100 px-2.5 py-1 rounded-lg transition-all print:hidden"
                >
                  + เพิ่มอุปกรณ์นอกสูตร
                </button>
              </div>

              {editableAccessories.length === 0 ? (
                <p className="text-sm text-gray-400 py-2">ไม่มีอุปกรณ์เสริม</p>
              ) : (
                <div className="space-y-4">
                  {editableAccessories.map((acc, idx) => (
                    <div key={idx} className="flex flex-col gap-2 border-b border-gray-50 pb-3 last:border-0 last:pb-0">
                      <div className="flex justify-between items-center gap-2">
                        <div className="flex-1">
                          <input
                            type="text"
                            value={acc.name}
                            onChange={(e) => handleUpdateAccessory(idx, { name: e.target.value })}
                            placeholder="ชื่ออุปกรณ์เสริม"
                            className="w-full text-sm text-gray-800 border border-gray-200 rounded px-2 py-0.5 focus:ring-1 focus:ring-blue-500 font-medium print:border-none print:bg-transparent print:p-0 print:text-sm print:font-semibold print:shadow-none print:outline-none print:focus:ring-0 print:pointer-events-none"
                          />
                        </div>
                        <button
                          onClick={() => handleDeleteAccessory(idx)}
                          className="p-1.5 text-red-500 hover:text-red-700 hover:bg-red-50 rounded-lg transition-colors print:hidden"
                          title="ลบรายการอุปกรณ์"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>

                      <div className="flex items-center justify-between text-xs text-gray-500">
                        <div className="flex items-center gap-1.5">
                          <span>จำนวน:</span>
                          <input
                            type="number"
                            min="0"
                            step="1"
                            value={acc.quantity}
                            onChange={(e) => handleUpdateAccessory(idx, { quantity: Math.max(0, parseInt(e.target.value) || 0) })}
                            className="w-12 text-right border border-gray-200 rounded px-1 py-0.5 text-xs focus:ring-1 focus:ring-blue-500 font-semibold print:hidden"
                          />
                          <span className="hidden print:inline font-semibold text-gray-900">{acc.quantity}</span>
                          
                          <input
                            type="text"
                            value={acc.unit}
                            onChange={(e) => handleUpdateAccessory(idx, { unit: e.target.value })}
                            placeholder="หน่วย"
                            className="w-10 border border-gray-200 rounded px-1 py-0.5 text-xs focus:ring-1 focus:ring-blue-500 print:hidden text-center"
                          />
                          <span className="text-gray-600 font-medium">{acc.unit}</span>
                        </div>

                        <div className="flex items-center gap-2">
                          <div className="flex items-center gap-1">
                            <span className="text-[10px] text-gray-400">@฿</span>
                            <input
                              type="number"
                              min="0"
                              step="0.5"
                              value={acc.unitCost}
                              onChange={(e) => handleUpdateAccessory(idx, { unitCost: Number(e.target.value) })}
                              className="w-16 text-right border border-gray-200 rounded px-1 py-0.5 text-xs focus:ring-1 focus:ring-blue-500 font-semibold print:hidden"
                            />
                            <span className="hidden print:inline font-semibold text-gray-700">฿{acc.unitCost}</span>
                          </div>
                          
                          <span className="font-semibold text-gray-900 ml-1">฿{acc.lineCost.toLocaleString()}</span>
                        </div>
                      </div>
                    </div>
                  ))}
                  <div className="flex justify-between font-semibold text-blue-600 mt-2 pt-2 border-t border-gray-50">
                    <span>ค่าอุปกรณ์เสริมรวม</span>
                    <span>฿{computedAccessoryCost.toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                  </div>
                </div>
              )}
            </div>

          </div>
        </div>

        {/* Right Column: Pricing Summary */}
        <div className="lg:col-span-4 space-y-6 print:w-full print:break-inside-avoid print:mt-4">
          <div className="bg-gray-900 rounded-2xl shadow-xl overflow-hidden text-white relative print:bg-white print:text-black print:shadow-none print:border print:border-gray-300 sticky top-8">
            <div className="absolute inset-0 bg-gradient-to-br from-blue-600/20 to-transparent pointer-events-none print:hidden" />
            <div className="p-6 print:p-4 relative">
              <h2 className="text-xl font-bold text-white mb-6 print:text-black print:mb-4 flex items-center gap-2">
                <Calculator className="w-5 h-5 text-blue-400 print:text-blue-600" /> 
                {editId ? "อัปเดตและบันทึกใบเสนอราคา" : "สรุปการประเมินราคา"}
              </h2>

              <div className="space-y-3 print:space-y-2 text-sm font-medium text-gray-300 print:text-gray-700">
                <div className="flex justify-between items-center">
                  <span>วัสดุอลูมิเนียม ({editableMaterials.reduce((sum, c) => sum + c.barsRequired, 0)} เส้น)</span>
                  <span>฿{computedMaterialCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>
                {computedGlassCost > 0 && (
                  <div className="flex justify-between items-center">
                    <span>ค่ากระจก</span>
                    <span>฿{computedGlassCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                  </div>
                )}
                {computedAccessoryCost > 0 && (
                  <div className="flex justify-between items-center">
                    <span>อุปกรณ์เสริม</span>
                    <span>฿{computedAccessoryCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                  </div>
                )}

                <div className="h-px bg-gray-700 my-4 print:bg-gray-200 print:my-2" />

                <div className="flex justify-between items-center text-white print:text-black font-semibold">
                  <span>รวมเป็นเงิน (ต่อชุด)</span>
                  <span>฿{computedSubtotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>

                <div className="flex justify-between items-center text-blue-300 print:text-blue-700 mt-2">
                  <span>กำไร (+{marginPercent}%)</span>
                  <span>฿{computedMarginAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>
                <div className="flex justify-between items-center text-emerald-300 print:text-emerald-700">
                  <span>ค่าแรง (ต่อ ตร.ม.)</span>
                  <span>฿{computedLaborCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>

                {computedDiscountAmount > 0 && (
                  <>
                    <div className="h-px bg-gray-700 my-4 print:bg-gray-200 print:my-2" />
                    <div className="flex justify-between items-center text-red-400 print:text-red-600">
                      <span>ส่วนลด (-{discountPercent}%)</span>
                      <span>-฿{computedDiscountAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                    </div>
                  </>
                )}

                <div className="flex justify-between items-center text-white print:text-black font-semibold border-t border-gray-800 print:border-gray-200 pt-3 mt-2">
                  <span>ราคาแนะนำต่อชุด</span>
                  <span>฿{finalPriceOneSet.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>

                <div className="h-px bg-gray-700 my-4 print:bg-gray-200 print:my-2" />

                {/* Harga Jual per set input */}
                <div className="flex justify-between items-center text-white print:text-black font-semibold">
                  <span className="text-xs text-gray-400 print:text-gray-500">ราคาขายต่อชุด (บาท)</span>
                  <div className="flex items-center gap-2">
                    <span className="hidden print:inline">฿{unitPrice.toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                    <div className="print:hidden relative text-black w-36">
                      <span className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400 text-xs">฿</span>
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={customUnitPrice}
                        onChange={(e) => setCustomUnitPrice(e.target.value)}
                        placeholder={finalPriceOneSet.toFixed(2)}
                        className="w-full pl-6 pr-2 py-1 text-xs rounded border border-gray-700 bg-white font-semibold outline-none focus:ring-1 focus:ring-blue-500 transition-all text-right"
                      />
                    </div>
                  </div>
                </div>

                {/* Jumlah Set input */}
                <div className="flex justify-between items-center text-white print:text-black font-semibold mt-2">
                  <span className="text-xs text-gray-400 print:text-gray-500">จำนวนชุด</span>
                  <div className="flex items-center gap-2">
                    <span className="hidden print:inline">{setsCount} ชุด</span>
                    <div className="print:hidden text-black w-36">
                      <input
                        type="number"
                        min="1"
                        step="1"
                        value={setsCount}
                        onChange={(e) => setSetsCount(Math.max(1, parseInt(e.target.value) || 1))}
                        className="w-full px-2 py-1 text-xs rounded border border-gray-700 bg-white font-semibold outline-none focus:ring-1 focus:ring-blue-500 transition-all text-right"
                      />
                    </div>
                  </div>
                </div>

                <div className="h-px bg-gray-700 my-4 print:bg-gray-200 print:my-2" />

                {/* Total Net Price */}
                <div className="flex justify-between items-end pt-2 mt-2 border-t border-gray-700 print:border-gray-300 flex-wrap gap-2">
                  <span className="text-base text-gray-400 print:text-gray-600 mb-1">ราคาสุทธิรวม ({setsCount} ชุด)</span>
                  <span className="text-2xl md:text-3xl font-extrabold text-white print:text-black leading-none break-all sm:break-normal">
                    ฿{totalPrice.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </span>
                </div>
              </div>

              <div className="mt-8 space-y-3 print:hidden">
                {isManualOverride && (
                  <button
                    onClick={handleSaveManualOverrides}
                    disabled={isSavingOverride}
                    className="w-full py-3.5 rounded-xl font-bold text-white bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 shadow-lg shadow-amber-950/50 flex items-center justify-center gap-2 transition-all active:scale-[0.98] animate-pulse hover:animate-none"
                  >
                    {isSavingOverride ? (
                      <>
                        <Loader2 className="w-5 h-5 animate-spin" />
                        กำลังบันทึกการปรับปรุง...
                      </>
                    ) : (
                      <>
                        <Check className="w-5 h-5" /> บันทึกการแก้ไขแบบกำหนดเอง
                      </>
                    )}
                  </button>
                )}

                <button
                  onClick={() => window.print()}
                  className="w-full py-3.5 rounded-xl font-bold text-white bg-blue-600 hover:bg-blue-500 shadow-lg shadow-blue-900/50 flex items-center justify-center gap-2 transition-all active:scale-[0.98]"
                >
                  <Printer className="w-5 h-5" /> พิมพ์ใบเสนอราคา / ส่งออก PDF
                </button>
                <button
                  onClick={() => {
                    setResult(null);
                    setCurrentStep(editId ? 3 : 1);
                    setSetsCount(1);
                    setCustomUnitPrice("");
                  }}
                  className="w-full py-3.5 rounded-xl font-semibold text-blue-100 bg-white/10 hover:bg-white/20 flex items-center justify-center gap-2 transition-all"
                >
                  {editId ? "แก้ไขขนาดและการตั้งค่า" : "ประเมินราคาใหม่"}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (isHydrating) {
    return (
      <div className="max-w-4xl mx-auto p-12 bg-white rounded-2xl border border-gray-100 shadow-sm flex flex-col items-center justify-center min-h-[300px]">
        <Loader2 className="w-10 h-10 text-blue-600 animate-spin mb-3" />
        <p className="font-bold text-gray-700">กำลังโหลดรายละเอียดใบเสนอราคา...</p>
        <p className="text-sm text-gray-400 mt-1">กำลังดึงข้อมูลและเตรียมระบบสำหรับการแก้ไข</p>
      </div>
    );
  }

  // --- RENDER: Wizard View ──────────────────────────────────────────────────────
  return (
    <div className="max-w-4xl mx-auto p-4 md:p-8">
      {editId && (
        <div className="mb-6 p-4 rounded-xl bg-amber-50 border border-amber-250 text-amber-800 text-sm flex items-center justify-between shadow-sm animate-in fade-in duration-200">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-amber-500 animate-pulse shrink-0" />
            <p className="font-semibold">
              กำลังอยู่ในโหมดแก้ไขใบเสนอราคา: <span className="font-mono text-xs bg-amber-100 px-2 py-0.5 rounded font-bold">{editId.slice(-6).toUpperCase()}</span>
            </p>
          </div>
          <button
            onClick={() => {
              window.location.href = "/";
            }}
            className="text-xs font-bold underline hover:text-amber-950 transition-colors"
          >
            ยกเลิกแก้ไข / สร้างใบเสนอราคาใหม่
          </button>
        </div>
      )}

      {/* Wizard Header */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden mb-8">
        <div className="bg-blue-50/50 p-5 border-b border-gray-100 flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-900 flex items-center gap-2">
            <Calculator className="w-6 h-6 text-blue-600" /> ตัวช่วยประเมินราคา (Parametric Wizard)
          </h2>
          <div className="hidden sm:flex items-center gap-3 text-sm font-medium text-gray-400">
            <span className={currentStep >= 1 ? "text-blue-600" : ""}>1. รูปแบบงาน</span>
            <ArrowRight className="w-4 h-4" />
            <span className={currentStep >= 2 ? "text-blue-600" : ""}>2. สี</span>
            <ArrowRight className="w-4 h-4" />
            <span className={currentStep >= 3 ? "text-blue-600" : ""}>3. ข้อมูลจำเพาะ</span>
            <ArrowRight className="w-4 h-4" />
            <span className={currentStep >= 4 ? "text-blue-600" : ""}>4. คำนวณ</span>
          </div>
        </div>

        <div className="p-6 md:p-8">

          {/* Step 1: Template Selection (Hierarchical) */}
          {currentStep === 1 && (
            <div className="animate-in fade-in slide-in-from-bottom-4 duration-500">
              {!selectedCategoryName ? (
                <>
                  <h3 className="text-lg font-semibold text-gray-800 mb-6 flex items-center gap-2">
                    <LayoutTemplate className="w-5 h-5 text-gray-500" /> เลือกซีรีส์ / แบรนด์
                  </h3>
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {Array.from(new Set(initialTemplates.map(t => t.categoryName))).map(catName => {
                      const count = initialTemplates.filter(t => t.categoryName === catName).length;
                      return (
                        <button
                          key={catName}
                          onClick={() => setSelectedCategoryName(catName)}
                          className="text-left p-6 rounded-2xl border-2 border-gray-100 hover:border-blue-500 hover:bg-blue-50/50 transition-all group relative overflow-hidden flex flex-col justify-between min-h-[120px]"
                        >
                          <div className="absolute top-0 right-0 p-4 opacity-0 group-hover:opacity-100 transition-opacity">
                            <ArrowRight className="w-5 h-5 text-blue-600" />
                          </div>
                          <h4 className="text-xl font-bold text-gray-900 leading-tight mb-2 pr-6">{catName}</h4>
                          <span className="text-sm font-medium text-blue-600 bg-blue-50 px-3 py-1 rounded-full w-fit">
                            {count} รูปแบบงาน
                          </span>
                        </button>
                      );
                    })}
                    {initialTemplates.length === 0 && (
                      <p className="text-gray-500 col-span-full">ยังไม่มีรูปแบบงานที่เปิดใช้งาน</p>
                    )}
                  </div>
                </>
              ) : (
                <>
                  <button
                    onClick={() => setSelectedCategoryName(null)}
                    className="flex items-center gap-2 text-sm font-semibold text-gray-500 hover:text-gray-900 mb-6 transition-colors"
                  >
                    <ArrowLeft className="w-4 h-4" /> กลับไปเลือกซีรีส์
                  </button>
                  <h3 className="text-lg font-semibold text-gray-800 mb-6 flex items-center gap-2">
                    <LayoutTemplate className="w-5 h-5 text-gray-500" /> เลือกรุปแบบงาน — {selectedCategoryName}
                  </h3>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    {initialTemplates.filter(t => t.categoryName === selectedCategoryName).map(t => (
                      <button
                        key={t.id}
                        onClick={() => handleSelectTemplate(t)}
                        className="text-left p-5 rounded-2xl border-2 border-gray-100 hover:border-blue-500 hover:bg-blue-50/50 transition-all group relative overflow-hidden"
                      >
                        <div className="absolute top-0 right-0 p-4 opacity-0 group-hover:opacity-100 transition-opacity">
                          <ArrowRight className="w-5 h-5 text-blue-600" />
                        </div>
                        <h4 className="text-lg font-bold text-gray-900 leading-tight mb-2 pr-6">{t.name}</h4>
                        {t.description && <p className="text-sm text-gray-500 mb-4 line-clamp-2">{t.description}</p>}
                        <div className="flex flex-wrap gap-2 text-xs font-medium text-gray-600">
                          <span className="bg-gray-100 px-2 py-1 rounded-md">{t.componentCount} ชิ้นส่วน</span>
                          {t.hasGlass && <span className="bg-cyan-50 text-cyan-700 px-2 py-1 rounded-md">รวมกระจก</span>}
                        </div>
                      </button>
                    ))}
                  </div>
                </>
              )}
            </div>
          )}

          {/* Step 2: Color Selection */}
          {currentStep === 2 && selectedTemplate && (
            <div className="animate-in fade-in slide-in-from-right-8 duration-500">
              <button onClick={() => setCurrentStep(1)} className="flex items-center gap-2 text-sm font-semibold text-gray-500 hover:text-gray-900 mb-6">
                <ArrowLeft className="w-4 h-4" /> กลับไปเลือกรุปแบบงาน
              </button>
              <h3 className="text-lg font-semibold text-gray-800 mb-2 flex items-center gap-2">
                <Palette className="w-5 h-5 text-gray-500" /> เลือกสีอลูมิเนียม
              </h3>
              <p className="text-sm text-gray-500 mb-6">แสดงเฉพาะสีที่มีในทุก {selectedTemplate.componentCount} โปรไฟล์ของรูปแบบงานนี้</p>

              {isLoadingColors ? (
                <div className="flex items-center justify-center p-12 text-gray-400">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                </div>
              ) : availableColors.length === 0 ? (
                <div className="p-6 bg-red-50 text-red-600 rounded-xl text-sm font-medium flex gap-2">
                  <AlertCircle className="w-5 h-5 shrink-0" />
                  รูปแบบงานนี้มีข้อมูลราคาไม่สมบูรณ์ ไม่มีสีใดที่มีครบในทุกโปรไฟล์ที่จำเป็น
                </div>
              ) : (
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  {availableColors.map(c => (
                    <button
                      key={c.id}
                      onClick={() => handleSelectColor(c)}
                      className="flex flex-col items-center justify-center p-6 rounded-2xl border-2 border-gray-100 hover:border-blue-500 hover:bg-blue-50/50 transition-all"
                    >
                      <div className="w-10 h-10 rounded-full border border-gray-200 shadow-inner mb-3" style={{ backgroundColor: c.hexCode || '#fff' }} />
                      <span className="font-semibold text-gray-900">{c.name}</span>
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Step 3: Dimensions & Project Details */}
          {currentStep === 3 && selectedTemplate && selectedColor && (
            <div className="animate-in fade-in slide-in-from-right-8 duration-500">
              <button onClick={() => setCurrentStep(2)} className="flex items-center gap-2 text-sm font-semibold text-gray-500 hover:text-gray-900 mb-6">
                <ArrowLeft className="w-4 h-4" /> กลับไปเลือกสี
              </button>

              <div className="bg-gray-50 rounded-xl p-4 mb-8 flex items-start gap-4">
                <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center shrink-0">
                  <Check className="w-5 h-5 text-blue-600" />
                </div>
                <div>
                  <p className="text-sm text-gray-500">การตั้งค่าที่คุณเลือก</p>
                  <p className="font-bold text-gray-900">{selectedTemplate.name} <span className="text-gray-400 font-normal mx-2">|</span> {selectedColor.name}</p>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-6">
                <div className="col-span-full">
                  <h3 className="text-lg font-semibold text-gray-800 flex items-center gap-2 border-b border-gray-100 pb-2">
                    <Ruler className="w-5 h-5 text-gray-500" /> ขนาดช่องเปิด (ซม.)
                  </h3>
                </div>

                <div>
                  <label className="block text-sm font-bold text-gray-700 mb-2">ความกว้าง (ซม.)</label>
                  <div className="relative">
                    <input
                      type="number" min="10" max="1000" step="0.5"
                      value={widthCm} onChange={(e) => handleWidthChange(Number(e.target.value))}
                      className="w-full pl-4 pr-16 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-lg font-semibold text-gray-900"
                    />
                    <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 font-medium">ซม.</span>
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-bold text-gray-700 mb-2">ความสูง (ซม.)</label>
                  <div className="relative">
                    <input
                      type="number" min="10" max="1000" step="0.5"
                      value={heightCm} onChange={(e) => handleHeightChange(Number(e.target.value))}
                      className="w-full pl-4 pr-16 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-lg font-semibold text-gray-900"
                    />
                    <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 font-medium">ซม.</span>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-bold text-gray-700 mb-2">จำนวนชุด (ชุด)</label>
                  <div className="relative">
                    <input
                      type="number" min="1" step="1"
                      value={setsCount} onChange={(e) => setSetsCount(Math.max(1, parseInt(e.target.value) || 1))}
                      className="w-full pl-4 pr-4 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-lg font-semibold text-gray-900"
                    />
                  </div>
                </div>

                <div className="col-span-full mt-6 bg-slate-50 border border-slate-200 rounded-2xl p-5 shadow-sm">
                  <h4 className="text-base font-bold text-slate-800 flex items-center gap-2 mb-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-blue-500 shrink-0" />
                    การกำหนดช่องแสงและช่องข้าง (Parametric Transoms & Sidelights)
                  </h4>
                  <p className="text-xs text-slate-500 mb-6">
                    สำหรับงานอลูมิเนียมที่มีช่องแสงด้านบน/ด้านล่าง หรือช่องข้าง (ช่องซ้าย/ขวา) 
                    ระบบจะคำนวณ H1, H2, W1, W2 และป้อนเข้าสู่สูตรการประเมินราคาโดยอัตโนมัติ 
                    (โดยความสูงรวม H = H1 + H2 และความกว้างรวม W = W1 + W2)
                  </p>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                    {/* Width Sub-dimensions */}
                    <div className="space-y-4 bg-white p-4 rounded-xl border border-slate-100 shadow-inner-sm">
                      <h5 className="text-sm font-bold text-slate-700 border-b border-slate-100 pb-1.5 flex items-center justify-between">
                        <span>สัดส่วนความกว้าง (Width Panels)</span>
                        <span className="text-[10px] bg-slate-100 text-slate-500 px-2 py-0.5 rounded-md font-mono">W = {widthCm} ซม.</span>
                      </h5>
                      <div className="grid grid-cols-2 gap-3">
                        <div>
                          <label className="block text-xs font-semibold text-slate-600 mb-1.5">ช่องซ้าย W1 (ซม.)</label>
                          <div className="relative">
                            <input
                              type="number" min="0" max={widthCm} step="0.5"
                              value={w1Cm} onChange={(e) => handleW1Change(e.target.value)}
                              className="w-full px-3 py-2 rounded-lg border border-slate-200 focus:ring-1 focus:ring-blue-500 outline-none text-sm font-bold text-slate-800"
                              placeholder="ช่องซ้าย"
                            />
                            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-medium font-mono">ซม.</span>
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-semibold text-slate-600 mb-1.5">ช่องขวา W2 (ซม.)</label>
                          <div className="relative">
                            <input
                              type="number" min="0" max={widthCm} step="0.5"
                              value={w2Cm} onChange={(e) => handleW2Change(e.target.value)}
                              className="w-full px-3 py-2 rounded-lg border border-slate-200 focus:ring-1 focus:ring-blue-500 outline-none text-sm font-bold text-slate-800"
                              placeholder="ช่องขวา"
                            />
                            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-medium font-mono">ซม.</span>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Height Sub-dimensions */}
                    <div className="space-y-4 bg-white p-4 rounded-xl border border-slate-100 shadow-inner-sm">
                      <h5 className="text-sm font-bold text-slate-700 border-b border-slate-100 pb-1.5 flex items-center justify-between">
                        <span>สัดส่วนความสูง (Height Panels)</span>
                        <span className="text-[10px] bg-slate-100 text-slate-500 px-2 py-0.5 rounded-md font-mono">H = {heightCm} ซม.</span>
                      </h5>
                      <div className="grid grid-cols-2 gap-3">
                        <div>
                          <label className="block text-xs font-semibold text-slate-600 mb-1.5">ช่องบน H1 (ซม.)</label>
                          <div className="relative">
                            <input
                              type="number" min="0" max={heightCm} step="0.5"
                              value={h1Cm} onChange={(e) => handleH1Change(e.target.value)}
                              className="w-full px-3 py-2 rounded-lg border border-slate-200 focus:ring-1 focus:ring-blue-500 outline-none text-sm font-bold text-slate-800"
                              placeholder="ช่องบน"
                            />
                            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-medium font-mono">ซม.</span>
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-semibold text-slate-600 mb-1.5">ช่องล่าง H2 (ซม.)</label>
                          <div className="relative">
                            <input
                              type="number" min="0" max={heightCm} step="0.5"
                              value={h2Cm} onChange={(e) => handleH2Change(e.target.value)}
                              className="w-full px-3 py-2 rounded-lg border border-slate-200 focus:ring-1 focus:ring-blue-500 outline-none text-sm font-bold text-slate-800"
                              placeholder="ช่องล่าง"
                            />
                            <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[10px] text-slate-400 font-medium font-mono">ซม.</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="col-span-full mt-4">
                  <h3 className="text-lg font-semibold text-gray-800 flex items-center gap-2 border-b border-gray-100 pb-2">
                    Project Information
                  </h3>
                </div>

                <div className="col-span-full">
                  <label className="block text-sm font-bold text-gray-700 mb-2">Project Name <span className="text-red-500">*</span></label>
                  <input
                    type="text" placeholder="e.g. Master Bedroom Balcony Door"
                    value={projectName} onChange={(e) => setProjectName(e.target.value)}
                    className="w-full px-4 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-gray-900"
                  />
                </div>
                <div className="col-span-full">
                  <label className="block text-sm font-bold text-gray-700 mb-2">Customer Name (Optional)</label>
                  <input
                    type="text" placeholder="e.g. John Doe"
                    value={customerName} onChange={(e) => setCustomerName(e.target.value)}
                    className="w-full px-4 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-gray-900"
                  />
                </div>

                <div className="col-span-full mt-4 flex justify-end">
                  <button
                    onClick={() => setCurrentStep(4)}
                    disabled={!projectName.trim()}
                    className="px-8 py-3.5 bg-gray-900 disabled:bg-gray-300 text-white font-bold rounded-xl flex items-center gap-2 transition-all hover:bg-gray-800"
                  >
                    ไปที่การตั้งราคา <ArrowRight className="w-5 h-5" />
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Step 4: Pricing Modifiers & Calculate */}
          {currentStep === 4 && selectedTemplate && selectedColor && (
            <div className="animate-in fade-in slide-in-from-right-8 duration-500">
              <button onClick={() => setCurrentStep(3)} className="flex items-center gap-2 text-sm font-semibold text-gray-500 hover:text-gray-900 mb-6">
                <ArrowLeft className="w-4 h-4" /> กลับไปตั้งขนาด
              </button>

              <h3 className="text-lg font-semibold text-gray-800 mb-6 flex items-center gap-2 border-b border-gray-100 pb-2">
                <Settings2 className="w-5 h-5 text-gray-500" /> ตั้งราคา
              </h3>

              <div className="space-y-8 max-w-lg mb-10">
                <div>
                  <div className="flex justify-between items-end mb-2">
                    <label className="block text-sm font-bold text-gray-700">อัตรากำไร (%)</label>
                    <span className="text-xl font-bold text-blue-600">{marginPercent}%</span>
                  </div>
                  <input
                    type="range" min="0" max="100" step="5"
                    value={marginPercent} onChange={(e) => setMarginPercent(Number(e.target.value))}
                    className="w-full accent-blue-600 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                  />
                </div>



                <div>
                  <label className="block text-sm font-bold text-gray-700 mb-2">ค่าแรงต่อ ตร.ม. (฿/m²)</label>
                  <p className="text-xs text-gray-500 mb-2">คูณกับพื้นที่ช่องเปิด ({((widthCm * heightCm) / 10_000).toFixed(4)} m²)</p>
                  <input
                    type="number" min="0" step="50"
                    value={laborCostPerSqM} onChange={(e) => setLaborCostPerSqM(Number(e.target.value))}
                    className="w-full px-4 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-gray-900 font-semibold"
                  />
                </div>

                <div>
                  <label className="block text-sm font-bold text-gray-700 mb-2">ส่วนลด (%)</label>
                  <input
                    type="number" min="0" max="100"
                    value={discountPercent} onChange={(e) => setDiscountPercent(Number(e.target.value))}
                    className="w-full px-4 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-gray-900 font-semibold"
                  />
                </div>
              </div>

              {errorMsg && (
                <div className="mb-6 p-4 bg-red-50 text-red-600 rounded-xl font-medium flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" />
                  {errorMsg}
                </div>
              )}

              <button
                onClick={handleCalculate}
                disabled={isCalculating}
                className={`w-full py-5 rounded-2xl font-black text-xl text-white flex items-center justify-center gap-3 transition-all relative overflow-hidden
                   ${isCalculating
                    ? 'bg-blue-400 cursor-wait'
                    : 'bg-blue-600 hover:bg-blue-500 shadow-xl shadow-blue-900/30 active:scale-[0.98]'
                  }`}
              >
                {isCalculating ? (
                  <>
                    <div className="absolute inset-0 bg-white/20 animate-pulse" />
                    <div className="w-6 h-6 border-4 border-white/30 border-t-white rounded-full animate-spin" />
                    กำลังคำนวณสูตรและจัดเรียงการตัด...
                  </>
                ) : (
                  <>
                    <Calculator className="w-6 h-6" /> คำนวณและบันทึก
                  </>
                )}
              </button>
              <p className="text-center text-sm text-gray-400 mt-4">
                กำลังรันอัลกอริธึมจัดเรียงการตัดบน {selectedTemplate.componentCount} โปรไฟล์...
              </p>
            </div>
          )}

        </div>
      </div>
    </div>
  );
}

