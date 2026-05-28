"use client";

import { useState, useEffect, Suspense } from "react";
import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";
import {
  LayoutDashboard,
  Layers,
  PlusCircle,
  FileText,
  FolderOpen,
  FileBox,
  History,
  Wrench,
  FlaskConical,
  Menu,
  X,
  ChevronDown,
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
      { href: "/quotations", label: "ประวัติใบเสนอราคา", icon: History, exact: true },
    ],
  },
  {
    title: "จัดการข้อมูลหลัก",
    items: [
      { href: "/admin/categories", label: "ซีรีส์", icon: FolderOpen, exact: false },
      { href: "/admin/templates", label: "รูปแบบงาน", icon: FileBox, exact: false },
      { href: "/materials", label: "เส้นอลูมิเนียม", icon: Layers, exact: false },
      { href: "/materials/new", label: "เพิ่มเส้นอลูมิเนียมใหม่", icon: PlusCircle, exact: true },
      { href: "/admin/accessories", label: "อุปกรณ์เสริม", icon: Wrench, exact: false },
      { href: "/admin/glass", label: "กระจก", icon: FlaskConical, exact: false },
    ],
  },
];

function SidebarNavigation({ closeSidebar }: { closeSidebar: () => void }) {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const currentSeries = searchParams.get("series");
  const currentCategory = searchParams.get("category");

  const [isAccessoriesOpen, setIsAccessoriesOpen] = useState(false);
  const [isGlassOpen, setIsGlassOpen] = useState(false);

  // Automatically expand the sub-menus when on their respective pages
  useEffect(() => {
    if (pathname.startsWith("/admin/accessories")) {
      setIsAccessoriesOpen(true);
    }
    if (pathname.startsWith("/admin/glass")) {
      setIsGlassOpen(true);
    }
  }, [pathname]);

  const isActive = (item: NavItem) =>
    item.exact ? pathname === item.href : pathname.startsWith(item.href);

  const isSubActive = (subHref: string) => {
    if (subHref === "/admin/accessories") {
      return pathname === "/admin/accessories" && !currentSeries;
    }
    const url = new URL(subHref, "http://localhost");
    const subSeries = url.searchParams.get("series");
    return pathname === "/admin/accessories" && currentSeries === subSeries;
  };

  const isGlassSubActive = (subHref: string) => {
    if (subHref === "/admin/glass") {
      return pathname === "/admin/glass" && !currentCategory;
    }
    const url = new URL(subHref, "http://localhost");
    const subCategory = url.searchParams.get("category");
    return pathname === "/admin/glass" && currentCategory === subCategory;
  };

  return (
    <nav className="flex-1 py-4 px-3 space-y-6 overflow-y-auto">
      {navSections.map((section) => (
        <div key={section.title}>
          <p className="px-3 mb-2 text-[10px] font-bold uppercase tracking-widest text-gray-500">
            {section.title}
          </p>
          <div className="space-y-1">
            {section.items.map((item) => {
              if (item.href === "/admin/accessories") {
                const active = pathname.startsWith("/admin/accessories");
                const Icon = item.icon;
                return (
                  <div key="accessories-collapsible" className="space-y-1">
                    <button
                      type="button"
                      onClick={() => setIsAccessoriesOpen(!isAccessoriesOpen)}
                      className={`w-full flex items-center justify-between gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all ${
                        active
                          ? "bg-gray-800 text-white"
                          : "text-gray-400 hover:text-white hover:bg-gray-800"
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <Icon className="w-4 h-4 shrink-0" />
                        <span>{item.label}</span>
                      </div>
                      <ChevronDown
                        className={`w-4 h-4 shrink-0 transition-transform duration-200 ${
                          isAccessoriesOpen ? "transform rotate-180 text-white" : "text-gray-500"
                        }`}
                      />
                    </button>
                    <div
                      className={`pl-8 space-y-1 overflow-hidden transition-all duration-300 ease-in-out ${
                        isAccessoriesOpen ? "max-h-[300px] opacity-100 mt-1" : "max-h-0 opacity-0"
                      }`}
                    >
                      {[
                        { href: "/admin/accessories", label: "อุปกรณ์ทั้งหมด" },
                        { href: "/admin/accessories?series=ชุดบานเลื่อน", label: "อุปกรณ์บานเลื่อน" },
                        { href: "/admin/accessories?series=ชุดบานเปิด, บานกระทุ้ง", label: "อุปกรณ์บานเปิด" },
                        { href: "/admin/accessories?series=ชุดบานเฟี้ยม", label: "อุปกรณ์บานเฟี้ยม" },
                        { href: "/admin/accessories?series=ชุดท้องตลาด", label: "อุปกรณ์ชุดท้องตลาด" },
                        { href: "/admin/accessories?series=ชุดบานเปลือย", label: "อุปกรณ์บานเปลือย" },
                      ].map((subItem) => {
                        const subActive = isSubActive(subItem.href);
                        return (
                          <Link
                            key={subItem.href}
                            href={subItem.href}
                            onClick={closeSidebar}
                            className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                              subActive
                                ? "bg-blue-600 text-white shadow-sm"
                                : "text-gray-400 hover:text-white hover:bg-gray-800"
                            }`}
                          >
                            <span className="w-1.5 h-1.5 rounded-full bg-current shrink-0" />
                            {subItem.label}
                          </Link>
                        );
                      })}
                    </div>
                  </div>
                );
              }

              if (item.href === "/admin/glass") {
                const active = pathname.startsWith("/admin/glass");
                const Icon = item.icon;
                return (
                  <div key="glass-collapsible" className="space-y-1">
                    <button
                      type="button"
                      onClick={() => setIsGlassOpen(!isGlassOpen)}
                      className={`w-full flex items-center justify-between gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all ${
                        active
                          ? "bg-gray-800 text-white"
                          : "text-gray-400 hover:text-white hover:bg-gray-800"
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <Icon className="w-4 h-4 shrink-0" />
                        <span>{item.label}</span>
                      </div>
                      <ChevronDown
                        className={`w-4 h-4 shrink-0 transition-transform duration-200 ${
                          isGlassOpen ? "transform rotate-180 text-white" : "text-gray-500"
                        }`}
                      />
                    </button>
                    <div
                      className={`pl-8 space-y-1 overflow-hidden transition-all duration-300 ease-in-out ${
                        isGlassOpen ? "max-h-[300px] opacity-100 mt-1" : "max-h-0 opacity-0"
                      }`}
                    >
                      {[
                        { href: "/admin/glass", label: "กระจกทั้งหมด" },
                        { href: "/admin/glass?category=กระจกธรรมดา", label: "กระจกธรรมดา" },
                        { href: "/admin/glass?category=กระจกเทมเปอร์", label: "กระจกเทมเปอร์" },
                        { href: "/admin/glass?category=กระจกลามิเนต", label: "กระจกลามิเนต" },
                        { href: "/admin/glass?category=กระจกเทมเปอร์ลามิเนต", label: "กระจกเทมเปอร์ลามิเนต" },
                        { href: "/admin/glass?category=กระจกอินซูเลท", label: "กระจกอินซูเลท" },
                        { href: "/admin/glass?category=กระจกเทมเปอร์อินซูเลท", label: "กระจกเทมเปอร์อินซูเลท" },
                      ].map((subItem) => {
                        const subActive = isGlassSubActive(subItem.href);
                        return (
                          <Link
                            key={subItem.href}
                            href={subItem.href}
                            onClick={closeSidebar}
                            className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                              subActive
                                ? "bg-blue-600 text-white shadow-sm"
                                : "text-gray-400 hover:text-white hover:bg-gray-800"
                            }`}
                          >
                            <span className="w-1.5 h-1.5 rounded-full bg-current shrink-0" />
                            {subItem.label}
                          </Link>
                        );
                      })}
                    </div>
                  </div>
                );
              }

              const active = isActive(item);
              const Icon = item.icon;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={closeSidebar}
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
  );
}

export default function Sidebar() {
  const [isOpen, setIsOpen] = useState(false);

  const closeSidebar = () => setIsOpen(false);

  const SidebarContent = (
    <>
      {/* Logo */}
      <div className="h-16 flex items-center justify-between gap-3 px-6 border-b border-gray-800 shrink-0">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center shrink-0">
            <span className="text-white font-bold text-xl leading-none">&Delta;</span>
          </div>
          <div>
            <p className="text-white font-bold text-sm leading-tight">SmartQuote</p>
            <p className="text-gray-400 text-xs leading-tight">Aluminum</p>
          </div>
        </div>
        <button className="md:hidden text-gray-400 hover:text-white" onClick={closeSidebar}>
          <X className="w-6 h-6" />
        </button>
      </div>

      {/* Nav Sections wrapped in Suspense for static build optimization */}
      <Suspense fallback={<div className="flex-1 py-4 px-3 space-y-6" />}>
        <SidebarNavigation closeSidebar={closeSidebar} />
      </Suspense>

      {/* Footer hint */}
      <div className="p-4 border-t border-gray-800 shrink-0">
        <p className="text-xs text-gray-600 text-center">Phase 4 — Admin Panel</p>
      </div>
    </>
  );

  return (
    <>
      {/* Mobile Top Bar */}
      <div className="md:hidden flex items-center justify-between h-14 bg-gray-900 px-4 shrink-0 print:hidden sticky top-0 z-40">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 bg-blue-600 rounded flex items-center justify-center shrink-0">
            <span className="text-white font-bold text-lg leading-none">&Delta;</span>
          </div>
          <p className="text-white font-bold text-sm leading-tight">SmartQuote</p>
        </div>
        <button
          onClick={() => setIsOpen(true)}
          className="text-gray-400 hover:text-white focus:outline-none"
        >
          <Menu className="w-6 h-6" />
        </button>
      </div>

      {/* Mobile Overlay */}
      {isOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 md:hidden print:hidden"
          onClick={closeSidebar}
        />
      )}

      {/* Sidebar Container */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 w-64 bg-gray-900 flex flex-col transform transition-transform duration-300 ease-in-out md:relative md:translate-x-0 print:hidden ${
          isOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        {SidebarContent}
      </aside>
    </>
  );
}

