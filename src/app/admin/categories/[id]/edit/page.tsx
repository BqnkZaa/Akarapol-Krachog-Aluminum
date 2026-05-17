import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { notFound } from "next/navigation";
import { getCategoryById } from "@/actions/category";
import CategoryForm from "@/components/CategoryForm";

export const dynamic = "force-dynamic";

export const metadata = {
  title: "Edit Series — SmartQuote",
};

export default async function EditCategoryPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const category = await getCategoryById(id);

  if (!category) {
    notFound();
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Page Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-3xl mx-auto px-6 py-6">
          <div className="flex items-center gap-2 text-sm text-gray-400 mb-3">
            <Link
              href="/admin/categories"
              className="hover:text-gray-600 transition-colors inline-flex items-center gap-1"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              Series
            </Link>
            <span>/</span>
            <span className="text-gray-600 font-medium">Edit</span>
          </div>
          <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">
            Edit Series
          </h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Editing &ldquo;{category.name}&rdquo;
          </p>
        </div>
      </div>

      {/* Form */}
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
        <CategoryForm mode="edit" initialData={category} />
      </div>
    </div>
  );
}
