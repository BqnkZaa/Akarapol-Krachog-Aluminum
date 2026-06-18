import Link from "next/link";
import { PlusCircle, Layers, FileText, FolderOpen, FileBox } from "lucide-react";
import prisma from "@/lib/prisma";

export const dynamic = "force-dynamic";

export const metadata = {
  title: "หน้าหลัก — SmartQuote",
};

export default async function DashboardPage() {
  const [materialCount, projectCount, categoryCount, templateCount] = await Promise.all([
    prisma.material.count({ where: { isActive: true } }),
    prisma.estimationProject.count(),
    prisma.category.count({ where: { isActive: true } }),
    prisma.productTemplate.count({ where: { isActive: true } }),
  ]);

  const stats = [
    { label: "ซีรีส์", value: categoryCount, color: "bg-purple-100 text-purple-700" },
    { label: "เส้นอลูมิเนียม", value: materialCount, color: "bg-blue-100 text-blue-700" },
    { label: "รูปแบบงาน", value: templateCount, color: "bg-indigo-100 text-indigo-700" },
    { label: "ประเมินราคา", value: projectCount, color: "bg-green-100 text-green-700" },
  ];

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-5xl mx-auto px-6 py-6">
          <h1 className="text-2xl font-extrabold text-gray-900 tracking-tight">หน้าหลัก</h1>
          <p className="text-sm text-gray-500 mt-0.5">ภาพรวมระบบ SmartQuote ของคุณ</p>
        </div>
      </div>

      <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8 space-y-8">
        {/* Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {stats.map((s) => (
            <div key={s.label} className="bg-white rounded-2xl border border-gray-200 shadow-sm p-6 text-center">
              <p className="text-4xl font-extrabold text-gray-900">{s.value}</p>
              <span className={`mt-2 inline-block text-xs font-semibold px-2 sm:px-3 py-1 rounded-full ${s.color}`}>
                {s.label}
              </span>
            </div>
          ))}
        </div>

        {/* Quick Actions */}
        <div>
          <h2 className="text-sm font-bold text-gray-500 uppercase tracking-wider mb-4">เมนูด่วน</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <Link href="/" className="bg-white hover:shadow-md rounded-2xl border border-gray-200 p-5 flex items-center gap-4 transition-shadow group">
              <div className="w-10 h-10 bg-blue-100 rounded-xl flex items-center justify-center shrink-0 group-hover:bg-blue-600 transition-colors">
                <FileText className="w-5 h-5 text-blue-600 group-hover:text-white transition-colors" />
              </div>
              <div>
                <p className="font-semibold text-gray-900">ประเมินราคาใหม่</p>
                <p className="text-xs text-gray-400 mt-0.5">สร้างใบเสนอราคาใหม่</p>
              </div>
            </Link>
            <Link href="/materials" className="bg-white hover:shadow-md rounded-2xl border border-gray-200 p-5 flex items-center gap-4 transition-shadow group">
              <div className="w-10 h-10 bg-purple-100 rounded-xl flex items-center justify-center shrink-0 group-hover:bg-purple-600 transition-colors">
                <Layers className="w-5 h-5 text-purple-600 group-hover:text-white transition-colors" />
              </div>
              <div>
                <p className="font-semibold text-gray-900">ดูข้อมูลเส้นอลูมิเนียม</p>
                <p className="text-xs text-gray-400 mt-0.5">เรียกดูแคตตาล็อก</p>
              </div>
            </Link>
            <Link href="/admin/categories" className="bg-white hover:shadow-md rounded-2xl border border-gray-200 p-5 flex items-center gap-4 transition-shadow group">
              <div className="w-10 h-10 bg-amber-100 rounded-xl flex items-center justify-center shrink-0 group-hover:bg-amber-600 transition-colors">
                <FolderOpen className="w-5 h-5 text-amber-600 group-hover:text-white transition-colors" />
              </div>
              <div>
                <p className="font-semibold text-gray-900">จัดการซีรีส์</p>
                <p className="text-xs text-gray-400 mt-0.5">เพิ่มหรือแก้ไขซีรีส์</p>
              </div>
            </Link>
            <Link href="/materials/new" className="bg-white hover:shadow-md rounded-2xl border border-gray-200 p-5 flex items-center gap-4 transition-shadow group">
              <div className="w-10 h-10 bg-green-100 rounded-xl flex items-center justify-center shrink-0 group-hover:bg-green-600 transition-colors">
                <PlusCircle className="w-5 h-5 text-green-600 group-hover:text-white transition-colors" />
              </div>
              <div>
                <p className="font-semibold text-gray-900">เพิ่มเส้นอลูมิเนียมใหม่</p>
                <p className="text-xs text-gray-400 mt-0.5">เพิ่มโปรไฟล์อลูมิเนียมใหม่</p>
              </div>
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
