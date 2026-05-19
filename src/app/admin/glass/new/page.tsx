import NewGlassForm from "@/components/NewGlassForm";

export const metadata = {
  title: "เพิ่มกระจกใหม่ — SmartQuote",
};

export default function NewGlassPage() {
  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-6 py-6">
          <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">
            เพิ่มกระจกใหม่
          </h1>
          <p className="text-sm text-gray-500 mt-1">
            เพิ่มชนิดกระจกและกำหนดราคาต่อตารางเมตรสำหรับใช้ในการประเมินราคา
          </p>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-6 py-8">
        <NewGlassForm />
      </div>
    </div>
  );
}
