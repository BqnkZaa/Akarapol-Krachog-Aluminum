"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Layers,
  PlusCircle,
  FileText,
  FolderOpen,
  FileBox,
} from "lucide-react";

type NavItem = {
  href: string;
  label: string;
  icon: React.ElementType;
  exact?: boolean;
};

type NavSection = {
  title: string;
  items: NavItem[];
};

const navSections: NavSection[] = [
  {
    title: "ประเมินราคา",
    items: [
      { href: "/dashboard", label: "หน้าหลัก", icon: LayoutDashboard, exact: true },
      { href: "/", label: "ประเมินราคาใหม่", icon: FileText, exact: true },
    ],
  },
  {
    title: "จัดการข้อมูลหลัก",
    items: [
      { href: "/admin/categories", label: "ซีรีส์", icon: FolderOpen, exact: false },
      { href: "/admin/templates", label: "รูปแบบงาน", icon: FileBox, exact: false },
      { href: "/materials", label: "วัสดุ", icon: Layers, exact: false },
      { href: "/materials/new", label: "เพิ่มวัสดุใหม่", icon: PlusCircle, exact: true },
    ],
  },
];

export default function Sidebar() {
  const pathname = usePathname();

  const isActive = (item: NavItem) =>
    item.exact ? pathname === item.href : pathname.startsWith(item.href);

  return (
    <aside className="hidden md:flex w-64 shrink-0 bg-gray-900 min-h-screen flex-col print:hidden">
      {/* Logo */}
      <div className="h-16 flex items-center gap-3 px-6 border-b border-gray-800">
        <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center shrink-0">
          <span className="text-white font-bold text-xl leading-none">&Delta;</span>
        </div>
        <div>
          <p className="text-white font-bold text-sm leading-tight">SmartQuote</p>
          <p className="text-gray-400 text-xs leading-tight">Aluminum</p>
        </div>
      </div>

      {/* Nav Sections */}
      <nav className="flex-1 py-4 px-3 space-y-6 overflow-y-auto">
        {navSections.map((section) => (
          <div key={section.title}>
            <p className="px-3 mb-2 text-[10px] font-bold uppercase tracking-widest text-gray-500">
              {section.title}
            </p>
            <div className="space-y-1">
              {section.items.map((item) => {
                const active = isActive(item);
                const Icon = item.icon;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all ${
                      active
                        ? "bg-blue-600 text-white shadow-lg shadow-blue-900/40"
                        : "text-gray-400 hover:text-white hover:bg-gray-800"
                    }`}
                  >
                    <Icon className="w-4 h-4 shrink-0" />
                    {item.label}
                  </Link>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      {/* Footer hint */}
      <div className="p-4 border-t border-gray-800">
        <p className="text-xs text-gray-600 text-center">Phase 4 — Admin Panel</p>
      </div>
    </aside>
  );
}
