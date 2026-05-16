"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Layers,
  PlusCircle,
  FileText,
} from "lucide-react";

type NavItem = {
  href: string;
  label: string;
  icon: React.ElementType;
  exact?: boolean;
};

const navItems: NavItem[] = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard, exact: true },
  { href: "/", label: "New Quotation", icon: FileText, exact: true },
  { href: "/materials", label: "Materials", icon: Layers, exact: false },
  { href: "/materials/new", label: "Add Material", icon: PlusCircle, exact: true },
];

export default function Sidebar() {
  const pathname = usePathname();

  const isActive = (item: NavItem) =>
    item.exact ? pathname === item.href : pathname.startsWith(item.href);

  return (
    <aside className="w-64 shrink-0 bg-gray-900 min-h-screen flex flex-col print:hidden">
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

      {/* Nav */}
      <nav className="flex-1 py-6 px-3 space-y-1">
        {navItems.map((item) => {
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
      </nav>

      {/* Footer hint */}
      <div className="p-4 border-t border-gray-800">
        <p className="text-xs text-gray-600 text-center">Phase 2 — Admin Panel</p>
      </div>
    </aside>
  );
}
