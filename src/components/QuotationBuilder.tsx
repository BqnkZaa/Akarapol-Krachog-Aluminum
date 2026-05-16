"use client";

import React, { useState, useMemo } from "react";
import { Plus, Trash2, ArrowRight, Save, CheckCircle2, CircleDashed, Printer } from "lucide-react";
import type { CategoryWithMaterialsDTO, MaterialDTO, MaterialVariantDTO } from "@/actions/material";
import { saveEstimationProject, type EstimationItemInput } from "@/actions/estimation";

type QuotationBuilderProps = {
  initialCategories: CategoryWithMaterialsDTO[];
};

type AddedItem = {
  tempId: string;
  category: CategoryWithMaterialsDTO;
  material: MaterialDTO;
  variant: MaterialVariantDTO;
  quantity: number;
};

export default function QuotationBuilder({ initialCategories }: QuotationBuilderProps) {
  // --- Project Details State ---
  const [projectName, setProjectName] = useState("");
  const [customerName, setCustomerName] = useState("");
  const [marginPercent, setMarginPercent] = useState<number>(20);
  const [laborCost, setLaborCost] = useState<number>(500);
  const [discountPercent, setDiscountPercent] = useState<number>(0);

  // --- Added Items State ---
  const [addedItems, setAddedItems] = useState<AddedItem[]>([]);

  // --- Wizard State ---
  // Steps: 1: Category, 2: Material, 3: Color, 4: Quantity
  const [currentStep, setCurrentStep] = useState<number>(1);
  const [selectedCategory, setSelectedCategory] = useState<CategoryWithMaterialsDTO | null>(null);
  const [selectedMaterial, setSelectedMaterial] = useState<MaterialDTO | null>(null);
  const [selectedVariant, setSelectedVariant] = useState<MaterialVariantDTO | null>(null);
  const [quantity, setQuantity] = useState<number>(1);

  // --- Form Status ---
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null);

  // --- Real-time Calculations ---
  const totals = useMemo(() => {
    const subtotal = addedItems.reduce((sum, item) => sum + (item.variant.unitCost * item.quantity), 0);
    const marginAmount = subtotal * (marginPercent / 100);
    const beforeDiscount = subtotal + marginAmount + laborCost;
    const discountAmount = beforeDiscount * (discountPercent / 100);
    const finalPrice = beforeDiscount - discountAmount;

    return { subtotal, marginAmount, beforeDiscount, discountAmount, finalPrice };
  }, [addedItems, marginPercent, laborCost, discountPercent]);

  // --- Wizard Actions ---
  const handleSelectCategory = (cat: CategoryWithMaterialsDTO) => {
    setSelectedCategory(cat);
    setSelectedMaterial(null);
    setSelectedVariant(null);
    setCurrentStep(2);
  };

  const handleSelectMaterial = (mat: MaterialDTO) => {
    setSelectedMaterial(mat);
    setSelectedVariant(null);
    setCurrentStep(3);
  };

  const handleSelectVariant = (variant: MaterialVariantDTO) => {
    setSelectedVariant(variant);
    setCurrentStep(4);
  };

  const handleAddItem = () => {
    if (selectedCategory && selectedMaterial && selectedVariant && quantity > 0) {
      setAddedItems(prev => [
        ...prev,
        {
          tempId: Math.random().toString(36).substring(7),
          category: selectedCategory,
          material: selectedMaterial,
          variant: selectedVariant,
          quantity: quantity
        }
      ]);
      // Reset wizard
      setCurrentStep(1);
      setSelectedCategory(null);
      setSelectedMaterial(null);
      setSelectedVariant(null);
      setQuantity(1);
    }
  };

  const handleRemoveItem = (tempId: string) => {
    setAddedItems(prev => prev.filter(item => item.tempId !== tempId));
  };

  const handleSaveProject = async () => {
    if (!projectName.trim()) {
      setSaveMessage({ type: 'error', text: 'Project Name is required.' });
      return;
    }
    if (addedItems.length === 0) {
      setSaveMessage({ type: 'error', text: 'Please add at least one material item.' });
      return;
    }

    setIsSaving(true);
    setSaveMessage(null);

    const itemsPayload: EstimationItemInput[] = addedItems.map((item, idx) => ({
      materialId: item.material.id,
      materialVariantId: item.variant.id,
      quantity: item.quantity,
      sortOrder: idx,
      description: `${item.category.name} - ${item.material.name} (${item.variant.colorName})`
    }));

    const result = await saveEstimationProject({
      projectName,
      customerName,
      profitMarginPercent: marginPercent,
      laborCost,
      discountPercent,
      items: itemsPayload
    });

    setIsSaving(false);

    if (result.success) {
      setSaveMessage({ type: 'success', text: `Project saved successfully! ID: ${result.projectId}` });
      // Clear form on success
      setAddedItems([]);
      setProjectName("");
      setCustomerName("");
      setCurrentStep(1);
    } else {
      setSaveMessage({ type: 'error', text: result.error || 'Failed to save project.' });
    }
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 max-w-7xl mx-auto p-4 md:p-8 print:block print:p-0">
      {/* LEFT COLUMN: Wizard & Added Items */}
      <div className="lg:col-span-8 space-y-8 print:w-full print:mb-8">
        
        {/* WIZARD SECTION */}
        <section className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden print:hidden">
          <div className="bg-blue-50/50 p-4 border-b border-gray-100 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-gray-800 flex items-center gap-2">
              <Plus className="w-5 h-5 text-blue-600" /> Add Material Item
            </h2>
            <div className="flex gap-2 text-sm text-gray-500 font-medium">
              <span className={currentStep >= 1 ? "text-blue-600" : ""}>1. Category</span>
              <ArrowRight className="w-4 h-4" />
              <span className={currentStep >= 2 ? "text-blue-600" : ""}>2. Material</span>
              <ArrowRight className="w-4 h-4" />
              <span className={currentStep >= 3 ? "text-blue-600" : ""}>3. Color</span>
              <ArrowRight className="w-4 h-4" />
              <span className={currentStep >= 4 ? "text-blue-600" : ""}>4. Qty</span>
            </div>
          </div>

          <div className="p-6">
            {/* Step 1: Category */}
            {currentStep === 1 && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {initialCategories.map(cat => (
                  <button
                    key={cat.id}
                    onClick={() => handleSelectCategory(cat)}
                    className="flex flex-col text-left p-4 rounded-xl border-2 border-gray-100 hover:border-blue-500 hover:bg-blue-50 transition-colors"
                  >
                    <span className="font-semibold text-gray-800">{cat.name}</span>
                    {cat.description && <span className="text-sm text-gray-500 mt-1">{cat.description}</span>}
                  </button>
                ))}
              </div>
            )}

            {/* Step 2: Material */}
            {currentStep === 2 && selectedCategory && (
              <div className="space-y-4">
                <button onClick={() => setCurrentStep(1)} className="text-sm text-blue-600 font-medium mb-4 block hover:underline">
                  &larr; Back to Categories
                </button>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {selectedCategory.materials.map(mat => (
                    <button
                      key={mat.id}
                      onClick={() => handleSelectMaterial(mat)}
                      className="flex flex-col text-left p-4 rounded-xl border-2 border-gray-100 hover:border-blue-500 hover:bg-blue-50 transition-colors"
                    >
                      <span className="text-xs font-mono text-gray-400 mb-1">{mat.code}</span>
                      <span className="font-semibold text-gray-800">{mat.name}</span>
                      <span className="text-sm text-gray-500 mt-1">Unit: {mat.unit}</span>
                    </button>
                  ))}
                  {selectedCategory.materials.length === 0 && (
                    <p className="text-gray-500">No materials available in this category.</p>
                  )}
                </div>
              </div>
            )}

            {/* Step 3: Color Variant */}
            {currentStep === 3 && selectedMaterial && (
              <div className="space-y-4">
                 <button onClick={() => setCurrentStep(2)} className="text-sm text-blue-600 font-medium mb-4 block hover:underline">
                  &larr; Back to Materials
                </button>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  {selectedMaterial.variants.map(variant => (
                    <button
                      key={variant.id}
                      onClick={() => handleSelectVariant(variant)}
                      className="flex flex-col items-center justify-center p-4 rounded-xl border-2 border-gray-100 hover:border-blue-500 hover:bg-blue-50 transition-colors"
                    >
                      <span className="font-semibold text-gray-800 mb-2">{variant.colorName}</span>
                      <span className="text-sm bg-gray-100 px-3 py-1 rounded-full font-medium text-gray-700">
                        ฿{variant.unitCost.toLocaleString()} / {selectedMaterial.unit}
                      </span>
                    </button>
                  ))}
                  {selectedMaterial.variants.length === 0 && (
                    <p className="text-gray-500 col-span-full">No color variants available.</p>
                  )}
                </div>
              </div>
            )}

            {/* Step 4: Quantity */}
            {currentStep === 4 && selectedMaterial && selectedVariant && (
              <div className="space-y-6 max-w-md mx-auto py-4">
                 <div className="flex justify-between items-start mb-6 border-b border-gray-100 pb-4">
                    <div>
                      <p className="text-sm text-gray-500">{selectedMaterial.code}</p>
                      <h3 className="font-semibold text-gray-800">{selectedMaterial.name}</h3>
                      <p className="text-sm font-medium text-gray-600 mt-1">Color: {selectedVariant.colorName}</p>
                    </div>
                    <div className="text-right">
                       <p className="text-sm text-gray-500">Unit Price</p>
                       <p className="font-semibold text-blue-600">฿{selectedVariant.unitCost.toLocaleString()}</p>
                    </div>
                 </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Quantity ({selectedMaterial.unit})</label>
                  <div className="flex gap-4">
                    <input
                      type="number"
                      min="1"
                      value={quantity}
                      onChange={(e) => setQuantity(Number(e.target.value))}
                      className="w-full px-4 py-3 rounded-xl border border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all text-lg"
                    />
                    <button
                      onClick={handleAddItem}
                      className="whitespace-nowrap px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-xl shadow-sm transition-colors flex items-center gap-2"
                    >
                      <Plus className="w-5 h-5" /> Add
                    </button>
                  </div>
                </div>
                <button onClick={() => setCurrentStep(3)} className="text-sm text-gray-500 hover:text-gray-800 mt-4 block mx-auto underline">
                  Cancel / Back
                </button>
              </div>
            )}
          </div>
        </section>

        {/* ADDED ITEMS LIST */}
        <section className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
           <div className="bg-gray-50 p-4 border-b border-gray-100">
            <h2 className="text-lg font-semibold text-gray-800">Materials Bill of Materials ({addedItems.length})</h2>
          </div>
          <div className="p-0">
            {addedItems.length === 0 ? (
              <div className="p-8 text-center flex flex-col items-center justify-center text-gray-400">
                <CircleDashed className="w-12 h-12 mb-3 text-gray-300" />
                <p>No materials added yet.</p>
                <p className="text-sm">Use the wizard above to start adding items.</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-100">
                {addedItems.map((item, index) => (
                  <div key={item.tempId} className="p-4 sm:p-6 flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between hover:bg-gray-50/50 transition-colors">
                    <div className="flex items-start gap-4 flex-1">
                      <div className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center text-sm font-medium text-gray-500 shrink-0">
                        {index + 1}
                      </div>
                      <div>
                        <h4 className="font-medium text-gray-900">{item.material.name}</h4>
                        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-gray-500 mt-1">
                          <span className="font-mono text-xs">{item.material.code}</span>
                          <span>&bull;</span>
                          <span>Color: <span className="font-medium text-gray-700">{item.variant.colorName}</span></span>
                          <span>&bull;</span>
                          <span>{item.quantity} {item.material.unit}</span>
                          <span>&times; ฿{item.variant.unitCost.toLocaleString()}</span>
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center justify-between sm:justify-end w-full sm:w-auto gap-6 sm:gap-4 pl-12 sm:pl-0 border-t sm:border-0 border-gray-100 pt-4 sm:pt-0">
                       <span className="font-semibold text-gray-800 whitespace-nowrap">
                         ฿{(item.variant.unitCost * item.quantity).toLocaleString()}
                       </span>
                       <button
                        onClick={() => handleRemoveItem(item.tempId)}
                        className="text-gray-400 hover:text-red-500 hover:bg-red-50 p-2 rounded-lg transition-colors print:hidden"
                        title="Remove item"
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </section>

      </div>

      {/* RIGHT COLUMN: Project Details & Summary */}
      <div className="lg:col-span-4 space-y-8 print:w-full print:break-inside-avoid">
        
        {/* PROJECT DETAILS */}
        <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 print:shadow-none print:border-gray-200">
          <h2 className="text-lg font-semibold text-gray-800 mb-5">Project Details</h2>
          
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Project Name *</label>
              <input
                type="text"
                value={projectName}
                onChange={e => setProjectName(e.target.value)}
                placeholder="e.g. สมชาย บ้านพักอาศัย"
                className="w-full px-3 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Customer Name</label>
              <input
                type="text"
                value={customerName}
                onChange={e => setCustomerName(e.target.value)}
                placeholder="Optional"
                className="w-full px-3 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
              />
            </div>
          </div>

          <h3 className="text-sm font-semibold text-gray-800 mt-8 mb-4 border-b border-gray-100 pb-2">Pricing Modifiers</h3>
          
          <div className="space-y-4">
             <div>
              <div className="flex justify-between items-center mb-1">
                <label className="text-sm font-medium text-gray-700">Profit Margin (%)</label>
                <span className="text-sm font-mono text-blue-600 bg-blue-50 px-2 py-0.5 rounded">{marginPercent}%</span>
              </div>
              <input
                type="range"
                min="0"
                max="100"
                step="5"
                value={marginPercent}
                onChange={e => setMarginPercent(Number(e.target.value))}
                className="w-full accent-blue-600"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Labor Cost (THB)</label>
              <input
                type="number"
                min="0"
                value={laborCost}
                onChange={e => setLaborCost(Number(e.target.value))}
                className="w-full px-3 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
              />
            </div>

             <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Discount (%)</label>
              <input
                type="number"
                min="0"
                max="100"
                value={discountPercent}
                onChange={e => setDiscountPercent(Number(e.target.value))}
                className="w-full px-3 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 outline-none transition-all"
              />
            </div>
          </div>
        </section>

        {/* QUOTATION SUMMARY */}
        <section className="bg-gray-900 rounded-2xl shadow-xl overflow-hidden text-white relative print:bg-white print:text-black print:shadow-none print:border print:border-gray-200">
           {/* Decorative bg gradient */}
           <div className="absolute inset-0 bg-gradient-to-br from-blue-600/20 to-transparent pointer-events-none print:hidden" />
           
           <div className="p-6 relative">
              <h2 className="text-lg font-semibold text-white mb-6 print:text-black">Quotation Summary</h2>
              
              <div className="space-y-3 text-sm font-medium text-gray-300 print:text-gray-700">
                <div className="flex justify-between items-center">
                  <span>Material Subtotal</span>
                  <span>฿{totals.subtotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>
                <div className="flex justify-between items-center text-blue-300 print:text-blue-700">
                  <span>Margin (+{marginPercent}%)</span>
                  <span>฿{totals.marginAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>
                <div className="flex justify-between items-center text-green-300 print:text-green-700">
                  <span>Labor Cost</span>
                  <span>฿{laborCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                </div>
                
                <div className="h-px bg-gray-700 my-4 print:bg-gray-200" />
                
                {discountPercent > 0 && (
                   <div className="flex justify-between items-center text-red-400 print:text-red-600">
                    <span>Discount (-{discountPercent}%)</span>
                    <span>-฿{totals.discountAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                  </div>
                )}

                <div className="flex justify-between items-center pt-2">
                  <span className="text-base text-white print:text-black font-semibold">Final Estimated Price</span>
                  <span className="text-2xl font-bold text-white print:text-black">
                    ฿{totals.finalPrice.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </span>
                </div>
              </div>

              {saveMessage && (
                <div className={`mt-6 p-3 rounded-lg text-sm font-medium flex items-start gap-2 print:hidden ${saveMessage.type === 'success' ? 'bg-green-500/20 text-green-200' : 'bg-red-500/20 text-red-200'}`}>
                  {saveMessage.type === 'success' && <CheckCircle2 className="w-5 h-5 shrink-0" />}
                  {saveMessage.text}
                </div>
              )}

              <button
                onClick={handleSaveProject}
                disabled={isSaving || addedItems.length === 0}
                className={`mt-6 w-full py-4 rounded-xl font-bold text-lg flex items-center justify-center gap-2 transition-all print:hidden
                  ${isSaving || addedItems.length === 0 
                    ? 'bg-gray-800 text-gray-500 cursor-not-allowed' 
                    : 'bg-blue-600 hover:bg-blue-500 text-white shadow-lg shadow-blue-900/50 hover:shadow-blue-900/80 active:scale-[0.98]'
                  }
                `}
              >
                {isSaving ? (
                  <span className="animate-pulse">Saving Project...</span>
                ) : (
                  <>
                    <Save className="w-5 h-5" /> Save Quotation
                  </>
                )}
              </button>

              <button
                onClick={() => window.print()}
                className="mt-3 w-full py-3 rounded-xl font-semibold text-blue-100 bg-blue-900/50 hover:bg-blue-800/60 border border-blue-700/50 flex items-center justify-center gap-2 transition-all print:hidden"
              >
                <Printer className="w-5 h-5" /> Print / Export as PDF
              </button>
           </div>
        </section>

      </div>
    </div>
  );
}
