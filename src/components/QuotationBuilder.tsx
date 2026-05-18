"use client";

import React, { useState, useEffect } from "react";
import { 
  ArrowRight, Save, CheckCircle2, AlertCircle, Printer, 
  Calculator, Box, Check, Ruler, Settings2, LayoutTemplate, Palette, ArrowLeft, Image as ImageIcon
} from "lucide-react";
import { 
  runParametricEstimation, 
  getAvailableColors, 
  type TemplateOption, 
  type ColorOption,
  type RunEstimationResult 
} from "@/actions/estimation";

type QuotationBuilderProps = {
  initialTemplates: TemplateOption[];
};

export default function QuotationBuilder({ initialTemplates }: QuotationBuilderProps) {
  // --- Wizard State ---
  // Steps: 1: Template, 2: Color, 3: Dimensions, 4: Pricing
  const [currentStep, setCurrentStep] = useState<number>(1);
  
  // --- Form Data ---
  const [selectedCategoryName, setSelectedCategoryName] = useState<string | null>(null);
  const [selectedTemplate, setSelectedTemplate] = useState<TemplateOption | null>(null);
  const [availableColors, setAvailableColors] = useState<ColorOption[]>([]);
  const [isLoadingColors, setIsLoadingColors] = useState(false);
  const [selectedColor, setSelectedColor] = useState<ColorOption | null>(null);
  
  const [widthMm, setWidthMm] = useState<number>(2000);
  const [heightMm, setHeightMm] = useState<number>(1500);
  const [projectName, setProjectName] = useState("");
  const [customerName, setCustomerName] = useState("");
  
  const [marginPercent, setMarginPercent] = useState<number>(20);
  const [laborCost, setLaborCost] = useState<number>(500);
  const [laborCostPerSqM, setLaborCostPerSqM] = useState<number>(0);
  const [discountPercent, setDiscountPercent] = useState<number>(0);

  // --- Submission State ---
  const [isCalculating, setIsCalculating] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [result, setResult] = useState<Extract<RunEstimationResult, { success: true }> | null>(null);

  // --- Effects ---
  useEffect(() => {
    if (selectedTemplate) {
      setIsLoadingColors(true);
      getAvailableColors(selectedTemplate.id).then((colors) => {
        setAvailableColors(colors);
        setIsLoadingColors(false);
      });
    }
  }, [selectedTemplate]);

  // --- Handlers ---
  const handleSelectTemplate = (template: TemplateOption) => {
    setSelectedTemplate(template);
    setSelectedColor(null);
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

    const res = await runParametricEstimation({
      templateId: selectedTemplate.id,
      colorId: selectedColor.id,
      widthMm,
      heightMm,
      projectName,
      customerName,
      profitMarginPercent: marginPercent,
      laborCost,
      laborCostPerSqM,
      discountPercent,
    });

    setIsCalculating(false);

    if (res.success) {
      setResult(res);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } else {
      setErrorMsg(res.error);
    }
  };

  // --- RENDER: Result View ────────────────────────────────────────────────────────
  if (result) {
    const { summary, cuttingResults, glassDetail, accessories } = result;
    return (
      <div className="max-w-7xl mx-auto p-4 md:p-8 grid grid-cols-1 lg:grid-cols-12 gap-8 print:block print:p-0">
        
        {/* Left Column: BOM & Cut Sheet */}
        <div className="lg:col-span-8 space-y-8 print:w-full">
          {/* Header Info with Elevation Drawing */}
          <div className="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm print:shadow-none print:border-gray-300">
             <div className="flex flex-col md:flex-row gap-6">
                
                {/* Visual Drawing / Image Placeholder */}
                <div className="w-full md:w-48 h-48 bg-gray-50 border-2 border-dashed border-gray-200 rounded-xl flex flex-col items-center justify-center shrink-0 overflow-hidden relative print:border-solid print:bg-white print:border-gray-300">
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
                   <div className="flex justify-between items-start mb-6">
                      <div>
                        <h2 className="text-2xl font-bold text-gray-900">{projectName}</h2>
                        {customerName && <p className="text-gray-500 mt-1">ลูกค้า: {customerName}</p>}
                      </div>
                      <div className="text-right">
                        <p className="text-sm text-gray-500">รหัส: {result.projectId.slice(-8).toUpperCase()}</p>
                      </div>
                   </div>

                   <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 pt-6 border-t border-gray-100 text-sm">
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
                        <p className="font-semibold text-gray-900">{result.widthMm} mm</p>
                      </div>
                      <div>
                        <p className="text-gray-500 mb-1">ความสูง (H)</p>
                        <p className="font-semibold text-gray-900">{result.heightMm} mm</p>
                      </div>
                   </div>
                </div>

             </div>
          </div>

          {/* Cutting Results */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden print:shadow-none print:border-gray-300">
            <div className="bg-gray-50 p-4 border-b border-gray-100 flex items-center gap-2">
              <Box className="w-5 h-5 text-blue-600" />
              <h3 className="font-semibold text-gray-900">รายการตัดวัสดุ (1D Bin Packing)</h3>
            </div>
            <div className="divide-y divide-gray-100">
              {cuttingResults.map((cr) => (
                <div key={cr.materialId} className="p-4 md:p-6 break-inside-avoid">
                  <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-4 gap-2">
                    <div>
                      <h4 className="font-bold text-gray-900">{cr.materialName}</h4>
                      <p className="text-sm text-gray-500 font-mono">{cr.materialCode} • {cr.barLengthMm}mm Bar</p>
                    </div>
                    <div className="text-left md:text-right">
                      <p className="font-semibold text-blue-600">ต้องใช้ {cr.barsRequired} เส้น</p>
                      <p className="text-sm text-gray-500">ประสิทธิภาพ {cr.utilizationPercent.toFixed(1)}% | ฿{cr.materialLineCost.toLocaleString()}</p>
                    </div>
                  </div>

                  {/* Cut Sheet Visuals */}
                  <div className="space-y-3 mt-4">
                    {cr.bars.map((bar) => (
                      <div key={bar.barIndex} className="relative">
                        <div className="flex items-center justify-between text-xs text-gray-500 mb-1">
                          <span>เส้นที่ #{bar.barIndex}</span>
                          <span>เศษเหลือ: {bar.wasteMm}mm</span>
                        </div>
                        <div className="h-8 bg-gray-100 rounded-md overflow-hidden flex border border-gray-200 w-full relative">
                          {bar.cuts.map((cut, idx) => {
                            // width = (cutLength / barLength) * 100
                            const pct = (cut.lengthMm / cr.barLengthMm) * 100;
                            // Generate a distinct color based on the cut label
                            const colors = ['bg-blue-500', 'bg-emerald-500', 'bg-purple-500', 'bg-orange-500', 'bg-pink-500', 'bg-indigo-500'];
                            const colorClass = colors[cut.label.length % colors.length];
                            
                            return (
                              <div 
                                key={idx} 
                                style={{ width: `${pct}%` }} 
                                className={`${colorClass} h-full border-r border-white/40 flex items-center justify-center text-[10px] text-white font-bold px-1 overflow-hidden whitespace-nowrap`}
                                title={`${cut.label}: ${cut.lengthMm}mm`}
                              >
                                {cut.lengthMm}
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
                        <div className="flex flex-wrap gap-x-3 gap-y-1 mt-1.5 text-[11px] text-gray-600">
                          {bar.cuts.map((cut, idx) => (
                            <span key={idx}><span className="font-medium text-gray-900">{cut.lengthMm}</span> ({cut.label})</span>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Glass & Accessories side-by-side */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 print:block print:space-y-8">
            {/* Glass */}
            {glassDetail && (
              <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 print:shadow-none print:border-gray-300 break-inside-avoid">
                <h3 className="font-semibold text-gray-900 mb-4 border-b border-gray-100 pb-2">ข้อมูลกระจก</h3>
                <p className="font-medium text-gray-900">{glassDetail.glassType}</p>
                <div className="space-y-2 mt-3 text-sm text-gray-600">
                  <div className="flex justify-between">
                    <span>ขนาด</span>
                    <span className="font-medium text-gray-900">{glassDetail.widthPerPanelMm} × {glassDetail.heightPerPanelMm} mm</span>
                  </div>
                  <div className="flex justify-between">
                    <span>จำนวน</span>
                    <span className="font-medium text-gray-900">{glassDetail.panelCount} บาน</span>
                  </div>
                  <div className="flex justify-between">
                    <span>พื้นที่รวม</span>
                    <span className="font-medium text-gray-900">{glassDetail.areaSqFt.toFixed(4)} ตร.ฟุต (Sq.Ft)</span>
                  </div>
                  <div className="flex justify-between">
                    <span>ราคาต่อ ตร.ฟุต</span>
                    <span className="font-medium text-gray-900">฿{glassDetail.pricePerSqFt.toLocaleString()}/Sq.Ft</span>
                  </div>
                  <div className="flex justify-between font-semibold text-blue-600 mt-2 pt-2 border-t border-gray-50">
                    <span>ค่ากระจก</span>
                    <span>฿{glassDetail.glassCost.toLocaleString(undefined, {minimumFractionDigits:2})}</span>
                  </div>
                </div>
              </div>
            )}
            
            {/* Accessories */}
            {accessories.length > 0 && (
              <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 print:shadow-none print:border-gray-300 break-inside-avoid">
                <h3 className="font-semibold text-gray-900 mb-4 border-b border-gray-100 pb-2">อุปกรณ์เสริม</h3>
                <div className="space-y-3">
                  {accessories.map((acc, idx) => (
                    <div key={idx} className="flex justify-between text-sm items-center">
                      <span className="text-gray-700">{acc.name}</span>
                      <div className="text-right">
                         <span className="text-gray-500 mr-3">{acc.quantity} {acc.unit}</span>
                         <span className="font-medium text-gray-900">฿{acc.lineCost.toLocaleString()}</span>
                      </div>
                    </div>
                  ))}
                  <div className="flex justify-between font-semibold text-blue-600 mt-2 pt-2 border-t border-gray-50">
                    <span>ค่าอุปกรณ์เสริม</span>
                    <span>฿{summary.accessoryCost.toLocaleString(undefined, {minimumFractionDigits:2})}</span>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Right Column: Pricing Summary */}
        <div className="lg:col-span-4 space-y-6 print:w-full print:break-inside-avoid">
          <div className="bg-gray-900 rounded-2xl shadow-xl overflow-hidden text-white relative print:bg-white print:text-black print:shadow-none print:border print:border-gray-300 sticky top-8">
            <div className="absolute inset-0 bg-gradient-to-br from-blue-600/20 to-transparent pointer-events-none print:hidden" />
            <div className="p-6 relative">
              <h2 className="text-xl font-bold text-white mb-6 print:text-black flex items-center gap-2">
                <Calculator className="w-5 h-5 text-blue-400 print:text-blue-600" /> สรุปการประเมินราคา
              </h2>
              
              <div className="space-y-3 text-sm font-medium text-gray-300 print:text-gray-700">
                <div className="flex justify-between items-center">
                  <span>วัสดุอลูมิเนียม ({result.cuttingResults.reduce((sum, c) => sum + c.barsRequired, 0)} เส้น)</span>
                  <span>฿{summary.materialCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>
                {summary.glassCost > 0 && (
                  <div className="flex justify-between items-center">
                    <span>ค่ากระจก</span>
                    <span>฿{summary.glassCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                  </div>
                )}
                {summary.accessoryCost > 0 && (
                  <div className="flex justify-between items-center">
                    <span>อุปกรณ์เสริม</span>
                    <span>฿{summary.accessoryCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                  </div>
                )}
                
                <div className="h-px bg-gray-700 my-4 print:bg-gray-200" />
                
                <div className="flex justify-between items-center text-white print:text-black font-semibold">
                  <span>รวมเป็นเงิน</span>
                  <span>฿{summary.subtotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>

                <div className="flex justify-between items-center text-blue-300 print:text-blue-700 mt-2">
                  <span>กำไร (+{marginPercent}%)</span>
                  <span>฿{summary.marginAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>
                <div className="flex justify-between items-center text-emerald-300 print:text-emerald-700">
                  <span>ค่าแรงคงที่</span>
                  <span>฿{summary.laborCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>
                {summary.laborSqMCost > 0 && (
                  <div className="flex justify-between items-center text-emerald-300 print:text-emerald-700">
                    <span>ค่าแรงต่อ ตร.ม.</span>
                    <span>฿{summary.laborSqMCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                  </div>
                )}
                
                {summary.discountAmount > 0 && (
                  <>
                    <div className="h-px bg-gray-700 my-4 print:bg-gray-200" />
                    <div className="flex justify-between items-center text-red-400 print:text-red-600">
                      <span>ส่วนลด (-{discountPercent}%)</span>
                      <span>-฿{summary.discountAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                    </div>
                  </>
                )}

                <div className="flex justify-between items-end pt-4 mt-4 border-t border-gray-700 print:border-gray-300">
                  <span className="text-base text-gray-400 print:text-gray-600 mb-1">ราคาสุทธิ</span>
                  <span className="text-3xl font-extrabold text-white print:text-black leading-none">
                    ฿{summary.finalPrice.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </span>
                </div>
              </div>

              <div className="mt-8 space-y-3 print:hidden">
                <button
                  onClick={() => window.print()}
                  className="w-full py-3.5 rounded-xl font-bold text-white bg-blue-600 hover:bg-blue-500 shadow-lg shadow-blue-900/50 flex items-center justify-center gap-2 transition-all active:scale-[0.98]"
                >
                  <Printer className="w-5 h-5" /> พิมพ์ใบเสนอราคา / ส่งออก PDF
                </button>
                <button
                  onClick={() => { setResult(null); setCurrentStep(1); }}
                  className="w-full py-3.5 rounded-xl font-semibold text-blue-100 bg-white/10 hover:bg-white/20 flex items-center justify-center gap-2 transition-all"
                >
                   ประเมินราคาใหม่
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // --- RENDER: Wizard View ──────────────────────────────────────────────────────
  return (
    <div className="max-w-4xl mx-auto p-4 md:p-8">
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
                     <Ruler className="w-5 h-5 text-gray-500" /> Parametric Dimensions (mm)
                   </h3>
                 </div>
                 
                 <div>
                    <label className="block text-sm font-bold text-gray-700 mb-2">Width (W)</label>
                    <div className="relative">
                      <input 
                        type="number" min="100" max="10000"
                        value={widthMm} onChange={(e) => setWidthMm(Number(e.target.value))}
                        className="w-full pl-4 pr-12 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-lg font-semibold text-gray-900"
                      />
                      <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 font-medium">mm</span>
                    </div>
                 </div>
                 <div>
                    <label className="block text-sm font-bold text-gray-700 mb-2">Height (H)</label>
                    <div className="relative">
                      <input 
                        type="number" min="100" max="10000"
                        value={heightMm} onChange={(e) => setHeightMm(Number(e.target.value))}
                        className="w-full pl-4 pr-12 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-lg font-semibold text-gray-900"
                      />
                      <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 font-medium">mm</span>
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
                    <label className="block text-sm font-bold text-gray-700 mb-2">ค่าแรงคงที่ (฿)</label>
                    <input 
                      type="number" min="0" step="100"
                      value={laborCost} onChange={(e) => setLaborCost(Number(e.target.value))}
                      className="w-full px-4 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all text-gray-900 font-semibold"
                    />
                 </div>

                 <div>
                    <label className="block text-sm font-bold text-gray-700 mb-2">ค่าแรงต่อ ตร.ม. (฿/m²)</label>
                    <p className="text-xs text-gray-500 mb-2">คูณกับพื้นที่ช่องเปิด ({((widthMm * heightMm) / 1_000_000).toFixed(4)} m²)</p>
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

