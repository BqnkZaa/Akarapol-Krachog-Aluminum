import QuotationBuilder from "@/components/QuotationBuilder";
import { getCategoriesWithMaterials } from "@/actions/material";

export const dynamic = "force-dynamic";

export const metadata = {
  title: "New Quotation — SmartQuote",
};

export default async function NewQuotationPage() {
  const categories = await getCategoriesWithMaterials();

  return (
    <main className="min-h-screen bg-gray-50 pb-24 print:bg-white print:pb-0">
      {/* Page header */}
      <div className="max-w-7xl mx-auto px-4 md:px-8 py-8 md:py-10 print:hidden">
        <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight">New Quotation</h1>
        <p className="mt-1 text-base text-gray-500">
          Select materials, set pricing, and generate an instant cost estimate.
        </p>
      </div>

      {/* Print-only header */}
      <div className="hidden print:block px-8 py-6 border-b border-gray-200 mb-6">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
            <span className="text-white font-bold text-xl leading-none">&Delta;</span>
          </div>
          <div>
            <p className="font-bold text-gray-900 text-lg leading-tight">SmartQuote Aluminum</p>
            <p className="text-gray-500 text-xs">Cost Estimation Report</p>
          </div>
        </div>
      </div>

      <QuotationBuilder initialCategories={categories} />
    </main>
  );
}
