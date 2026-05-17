import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import CategoryForm from "@/components/CategoryForm";

export const metadata = {
  title: "Add Series — SmartQuote",
};

export default function NewCategoryPage() {
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
            <span className="text-gray-600 font-medium">Add New</span>
          </div>
          <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">
            Add New Series
          </h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Create a new aluminum series to group materials and templates.
          </p>
        </div>
      </div>

      {/* Form */}
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
        <CategoryForm mode="create" />
      </div>
    </div>
  );
}
