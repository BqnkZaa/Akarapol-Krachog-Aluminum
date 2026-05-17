import QuotationBuilder from "@/components/QuotationBuilder";
import { getTemplates } from "@/actions/estimation";

export const dynamic = "force-dynamic";

export const metadata = {
  title: "New Parametric Quotation — SmartQuote",
};

export default async function NewQuotationPage() {
  const templates = await getTemplates();

  return (
    <main className="min-h-screen bg-gray-50 pb-24 print:bg-white print:pb-0">
      {/* Page header */}
      <div className="max-w-7xl mx-auto px-4 md:px-8 py-8 md:py-10 print:hidden">
        <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight">Parametric Estimator</h1>
        <p className="mt-1 text-base text-gray-500">
          Select a template and enter dimensions to instantly generate an optimized cutting list and quotation.
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
            <p className="text-gray-500 text-xs">Parametric Cost Estimation Report</p>
          </div>
        </div>
      </div>

      <QuotationBuilder initialTemplates={templates} />
    </main>
  );
}
