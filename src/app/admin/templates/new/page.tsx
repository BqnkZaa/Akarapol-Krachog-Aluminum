import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import {
  getCategoriesForDropdown,
  getMaterialsForDropdown,
} from "@/actions/template";
import TemplateForm from "@/components/TemplateForm";

export const dynamic = "force-dynamic";

export const metadata = {
  title: "Add Template — SmartQuote",
};

export default async function NewTemplatePage() {
  const [categories, materials] = await Promise.all([
    getCategoriesForDropdown(),
    getMaterialsForDropdown(),
  ]);

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-5xl mx-auto px-6 py-6">
          <div className="flex items-center gap-2 text-sm text-gray-400 mb-3">
            <Link
              href="/admin/templates"
              className="hover:text-gray-600 transition-colors inline-flex items-center gap-1"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              Templates
            </Link>
            <span>/</span>
            <span className="text-gray-600 font-medium">Add New</span>
          </div>
          <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">
            Add New Template
          </h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Define a new work type with profile components, glass specification, and accessories.
          </p>
        </div>
      </div>

      <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8">
        <TemplateForm
          mode="create"
          categories={categories}
          materials={materials}
        />
      </div>
    </div>
  );
}
