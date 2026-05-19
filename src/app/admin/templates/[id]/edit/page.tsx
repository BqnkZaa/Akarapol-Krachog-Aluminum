import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { notFound } from "next/navigation";
import {
  getTemplateById,
  getCategoriesForDropdown,
  getMaterialsForDropdown,
  getAccessoriesForDropdown,
  getGlassesForDropdown,
} from "@/actions/template";
import TemplateForm from "@/components/TemplateForm";

export const dynamic = "force-dynamic";

export const metadata = {
  title: "Edit Template — SmartQuote",
};

export default async function EditTemplatePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const [template, categories, materials, accessories, glasses] = await Promise.all([
    getTemplateById(id),
    getCategoriesForDropdown(),
    getMaterialsForDropdown(),
    getAccessoriesForDropdown(),
    getGlassesForDropdown(),
  ]);

  if (!template) notFound();

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
            <span className="text-gray-600 font-medium">Edit</span>
          </div>
          <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">
            Edit Template
          </h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Editing &ldquo;{template.name}&rdquo;
            {template.projectCount > 0 && (
              <span className="ml-2 text-amber-600 font-medium">
                · {template.projectCount} quotation(s) reference this template
              </span>
            )}
          </p>
        </div>
      </div>

      <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8">
        <TemplateForm
          mode="edit"
          initialData={template}
          categories={categories}
          materials={materials}
          accessories={accessories}
          glasses={glasses}
        />
      </div>
    </div>
  );
}
