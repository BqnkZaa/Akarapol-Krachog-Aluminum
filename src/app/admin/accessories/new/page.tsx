import { getColors } from "@/actions/material";
import NewAccessoryForm from "@/components/NewAccessoryForm";

export const metadata = {
  title: "Add Accessory — SmartQuote",
};

export default async function NewAccessoryPage() {
  const colors = await getColors();

  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-6 py-6">
          <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">Add New Accessory</h1>
          <p className="text-sm text-gray-500 mt-1">
            Create a new hardware or accessory item and define its color-specific pricing.
          </p>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-6 py-8">
        <NewAccessoryForm colors={colors} />
      </div>
    </div>
  );
}
