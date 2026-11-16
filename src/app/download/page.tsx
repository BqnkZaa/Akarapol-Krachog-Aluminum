import { readFile } from "node:fs/promises";
import path from "node:path";
import type { Metadata } from "next";
import Image from "next/image";
import QRCode from "qrcode";
import {
  Download,
  Ruler,
  Layers,
  Calculator,
  FileText,
  ShieldCheck,
  Smartphone,
  ExternalLink,
} from "lucide-react";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "อัครพลกระจกอลูมิเนียม — ดาวน์โหลดแอปพลิเคชันสำหรับ Android (.apk)",
  description:
    "ระบบคำนวณระยะตัดประกอบ ถอดรายการวัสดุ จัดเส้นอลูมิเนียม ประเมินต้นทุน และออกใบเสนอราคา PDF สำหรับ บริษัท อัครพลกระจก อลูมิเนียม จำกัด",
};

type ApkMeta = {
  appName: string;
  packageId: string;
  version: string;
  fileName: string;
  sizeMb: string;
  sha256: string;
  updatedAt: string;
};

const DIRECT_APK_URL =
  "https://akarapol-krachog-aluminum.vercel.app/downloads/akkaraphon-toolkit.apk";
const MIRROR_APK_URL =
  "https://github.com/BqnkZaa/Akarapol-Krachog-Aluminum/releases/download/v0.1.7/akkaraphon-toolkit.apk";

async function loadApkMeta(): Promise<ApkMeta> {
  const metaPath = path.join(
    process.cwd(),
    "public",
    "downloads",
    "apk-meta.json"
  );
  try {
    const raw = await readFile(metaPath, "utf8");
    return JSON.parse(raw) as ApkMeta;
  } catch {
    return {
      appName: "อัครพลกระจกอลูมิเนียม",
      packageId: "com.akkaraphon.toolkit",
      version: "0.1.7 (VIP Offline)",
      fileName: "akkaraphon-toolkit.apk",
      sizeMb: "37.48",
      sha256: "-",
      updatedAt: "-",
    };
  }
}

export default async function DownloadLandingPage() {
  const meta = await loadApkMeta();
  const qrSvg = await QRCode.toString(DIRECT_APK_URL, {
    type: "svg",
    margin: 1,
    width: 112,
    color: {
      dark: "#0F172A",
      light: "#FFFFFF",
    },
  });

  const capabilities = [
    {
      icon: Ruler,
      title: "คำนวณระยะตัดและถอดรายการวัสดุครบ 5 หมวดระบบ",
      desc: "ครอบคลุมชุดตลาด ชุดพัฒนา ชุดยูโรโปรไฟล์ และระบบบานเฟี้ยมครบ 136 ผังการจัดบาน พร้อมคำนวณขนาดสั่งตัดกระจกและรายการอุปกรณ์ประกอบอัตโนมัติ",
    },
    {
      icon: Layers,
      title: "บริหารการจัดท่อนอลูมิเนียม (1D Bin-Packing)",
      desc: "คำนวณจำนวนเส้นโรงงานที่ต้องสั่งซื้อตามความยาวใช้งานจริง หักระยะหัวท้าย 100 มม. และเผื่อใบเลื่อย 4 มม. รองรับการจัดท่อนรวมข้ามรายการทั้งโครงการ",
    },
    {
      icon: Calculator,
      title: "ประเมินต้นทุนเส้นจากฐานข้อมูล 1,139 รายการ",
      desc: "จับคู่ราคาตามความหนาและสีผิวโปรไฟล์อัตโนมัติ เลือกคิดต้นทุนได้ทั้งตามระยะใช้จริงและซื้อเต็มเส้น พร้อมระบบบันทึกและแก้ไขราคาเส้นเฉพาะของทางร้าน",
    },
    {
      icon: FileText,
      title: "จัดการแฟ้มโครงการและออกเอกสาร PDF มาตรฐาน A4",
      desc: "บันทึกงานแยกตามโครงการ ออกใบสั่งตัดเดี่ยว เอกสารสรุปโครงการพร้อมผังจัดเส้นแนวนอน และใบเสนอราคาทั้งแบบแยกรายการและเหมาทั้งโครงการ",
    },
  ];

  const installSteps = [
    {
      title: "ดาวน์โหลดไฟล์ติดตั้งลงในอุปกรณ์",
      desc: "กดปุ่มดาวน์โหลดไฟล์ติดตั้ง (.apk) ด้านบน หรือใช้กล้องมือถือสแกนคิวอาร์โค้ดเพื่อบันทึกไฟล์ akkaraphon-toolkit.apk ลงในเครื่อง",
    },
    {
      title: "เปิดไฟล์จากแถบแจ้งเตือนหรือโฟลเดอร์ดาวน์โหลด",
      desc: "เมื่อดาวน์โหลดครบแล้ว แตะที่ชื่อไฟล์จากแถบแจ้งเตือนด้านบนของหน้าจอ หรือเปิดผ่านแอปจัดการไฟล์ในหมวด Downloads",
    },
    {
      title: "อนุญาตการติดตั้งจากแหล่งที่มาของเบราว์เซอร์",
      desc: "หากเป็นการติดตั้งครั้งแรก ระบบ Android จะแสดงหน้าต่างความปลอดภัย ให้เลือก การตั้งค่า (Settings) แล้วเปิดอนุญาตการติดตั้งจากเบราว์เซอร์ที่ใช้",
    },
    {
      title: "กดยืนยันการติดตั้งและเข้าใช้งานได้ทันที",
      desc: "กดปุ่ม ติดตั้ง (Install) รอระบบประมวลผลสักครู่ จากนั้นกด เปิด (Open) เพื่อเข้าใช้งานระบบพร้อมสิทธิ์ VIP แบบไม่ต้องเชื่อมต่ออินเทอร์เน็ต",
    },
  ];

  return (
    <div className="min-h-screen bg-[#F8FAFC] text-slate-900 selection:bg-[#0F2557] selection:text-white">
      {/* Top Corporate Header */}
      <header className="sticky top-0 z-30 bg-white/95 backdrop-blur border-b border-slate-200">
        <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Image
              src="/downloads/app-logo-3d.png"
              alt="โลโก้แอปพลิเคชัน อัครพลกระจกอลูมิเนียม"
              width={36}
              height={36}
              className="rounded-lg border border-slate-200/80 shadow-xs"
              priority
            />
            <div>
              <p className="text-sm font-semibold text-slate-900 leading-tight">
                บริษัท อัครพลกระจก อลูมิเนียม จำกัด
              </p>
              <p className="text-xs text-slate-500 leading-tight">
                ศูนย์ดาวน์โหลดซอฟต์แวร์คำนวณงานกระจกและอลูมิเนียม
              </p>
            </div>
          </div>

          <nav className="hidden md:flex items-center gap-8 text-sm text-slate-600">
            <a
              href="#capabilities"
              className="hover:text-slate-900 transition-colors duration-200"
            >
              ขอบเขตระบบ
            </a>
            <a
              href="#specifications"
              className="hover:text-slate-900 transition-colors duration-200"
            >
              ข้อมูลจำเพาะ
            </a>
            <a
              href="#installation"
              className="hover:text-slate-900 transition-colors duration-200"
            >
              วิธีติดตั้ง
            </a>
          </nav>

          <a
            href="/downloads/akkaraphon-toolkit.apk"
            download="akkaraphon-toolkit.apk"
            className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-[#0F2557] text-white text-xs sm:text-sm font-medium hover:bg-[#17357A] transition-colors duration-200 cursor-pointer"
          >
            <Download className="w-4 h-4 stroke-[1.75]" />
            <span>ดาวน์โหลด .apk</span>
          </a>
        </div>
      </header>

      {/* Main Content */}
      <main>
        {/* Hero Section — Asymmetric Split */}
        <section className="border-b border-slate-200 bg-white">
          <div className="max-w-6xl mx-auto px-6 py-14 lg:py-20">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-10 items-center">
              {/* Left Column: Brand Emblem, Copy & Actions */}
              <div className="lg:col-span-7 space-y-6">
                <div className="inline-flex items-center gap-2 text-xs font-medium text-slate-600 bg-slate-100 border border-slate-200/80 rounded-md px-3 py-1.5">
                  <span className="w-2 h-2 rounded-full bg-emerald-600" />
                  <span>
                    สำหรับระบบปฏิบัติการ Android · เวอร์ชัน {meta.version}
                  </span>
                </div>

                <div className="flex items-center gap-5">
                  <Image
                    src="/downloads/app-logo-3d.png"
                    alt="ไอคอน 3 มิติ อัครพลกระจกอลูมิเนียม"
                    width={84}
                    height={84}
                    className="rounded-2xl shadow-md border border-slate-200 shrink-0"
                    priority
                  />
                  <div>
                    <p className="text-xs font-medium text-[#0F2557]">
                      แอปพลิเคชันอย่างเป็นทางการ
                    </p>
                    <h1 className="text-2xl sm:text-3xl font-semibold text-slate-900 tracking-tight mt-0.5">
                      {meta.appName}
                    </h1>
                    <p className="text-xs sm:text-sm text-slate-500 mt-1 font-mono tabular-nums">
                      {meta.packageId}
                    </p>
                  </div>
                </div>

                <p className="text-base sm:text-lg text-slate-700 leading-relaxed max-w-2xl">
                  เครื่องมือคำนวณสูตรตัดประกอบ ถอดรายการวัสดุ จัดเส้นสั่งซื้อ
                  ประเมินต้นทุนโปรไฟล์ และออกเอกสารใบเสนอราคา PDF มาตรฐาน A4
                  ออกแบบมาเพื่อการทำงานหน้างานและสำนักงานโดยไม่ต้องเชื่อมต่ออินเทอร์เน็ต
                </p>

                {/* Primary & Secondary Actions */}
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 pt-1">
                  <a
                    href="/downloads/akkaraphon-toolkit.apk"
                    download="akkaraphon-toolkit.apk"
                    className="inline-flex items-center justify-center gap-2.5 px-6 py-3.5 rounded-xl bg-[#0F2557] text-white text-sm sm:text-base font-medium hover:bg-[#17357A] transition-colors duration-200 shadow-xs cursor-pointer"
                  >
                    <Download className="w-4 h-4 stroke-[1.75]" />
                    <span>ดาวน์โหลดไฟล์ติดตั้ง ({meta.sizeMb} MB)</span>
                  </a>

                  <a
                    href={MIRROR_APK_URL}
                    className="inline-flex items-center justify-center gap-2 px-5 py-3.5 rounded-xl bg-white border border-slate-300 text-slate-700 text-sm font-medium hover:bg-slate-50 hover:border-slate-400 transition-colors duration-200 cursor-pointer"
                  >
                    <ExternalLink className="w-4 h-4 stroke-[1.75] text-slate-500" />
                    <span>ลิงก์ดาวน์โหลดสำรอง (CDN)</span>
                  </a>
                </div>

                {/* Tabular Key Figures */}
                <div className="pt-6 border-t border-slate-200 grid grid-cols-2 sm:grid-cols-4 gap-6">
                  <div>
                    <p className="text-xl font-semibold text-slate-900 tabular-nums">
                      182
                    </p>
                    <p className="text-xs text-slate-500 mt-0.5">
                      ตารางสูตรคำนวณมาตรฐาน
                    </p>
                  </div>
                  <div>
                    <p className="text-xl font-semibold text-slate-900 tabular-nums">
                      136
                    </p>
                    <p className="text-xs text-slate-500 mt-0.5">
                      ผังระบบบานเฟี้ยม
                    </p>
                  </div>
                  <div>
                    <p className="text-xl font-semibold text-slate-900 tabular-nums">
                      1,139
                    </p>
                    <p className="text-xs text-slate-500 mt-0.5">
                      ฐานข้อมูลราคาเส้นโรงงาน
                    </p>
                  </div>
                  <div>
                    <p className="text-xl font-semibold text-slate-900 tabular-nums">
                      100%
                    </p>
                    <p className="text-xs text-slate-500 mt-0.5">
                      ทำงานแบบ Offline ในเครื่อง
                    </p>
                  </div>
                </div>
              </div>

              {/* Right Column: Real Product Interface Preview + QR Scan Card */}
              <div className="lg:col-span-5">
                <div className="bg-[#F8FAFC] border border-slate-200 rounded-2xl p-5 space-y-4">
                  {/* Simulated App Screen Card */}
                  <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-xs">
                    {/* App Top Bar */}
                    <div className="px-4 py-3 border-b border-slate-100 flex items-center justify-between">
                      <div className="flex items-center gap-2.5">
                        <Image
                          src="/downloads/app-logo-3d.png"
                          alt="App Logo"
                          width={28}
                          height={28}
                          className="rounded-md"
                        />
                        <div>
                          <div className="flex items-center gap-1.5">
                            <span className="text-xs font-semibold text-slate-900">
                              Toolkit
                            </span>
                            <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-amber-50 text-amber-800 border border-amber-200">
                              VIP
                            </span>
                          </div>
                          <p className="text-[11px] text-slate-500">
                            ORM (Asian Trop) · บานเลื่อนสลับ 2 บาน
                          </p>
                        </div>
                      </div>
                      <span className="text-[11px] text-slate-500 tabular-nums">
                        2,000 × 2,050 มม.
                      </span>
                    </div>

                    {/* App Cut List Preview */}
                    <div className="p-4 space-y-3 text-xs">
                      <div className="flex items-center justify-between text-[11px] font-medium text-[#0F2557] bg-slate-50 px-2.5 py-1.5 rounded">
                        <span>ตัวอย่างรายการตัดและจัดเส้น</span>
                        <span className="tabular-nums">จำนวน 2 ชุด</span>
                      </div>

                      <div className="divide-y divide-slate-100">
                        <div className="py-2 flex items-center justify-between">
                          <div>
                            <p className="font-medium text-slate-900">
                              801-03 · เฟรมบน
                            </p>
                            <p className="text-[11px] text-slate-500">
                              เส้นโรงงาน 6,400 มม. · มุมตัด 90° / 90°
                            </p>
                          </div>
                          <div className="text-right tabular-nums">
                            <p className="font-semibold text-slate-900">
                              ตัด 1,960 มม.
                            </p>
                            <p className="text-[11px] text-slate-500">2 ชิ้น</p>
                          </div>
                        </div>

                        <div className="py-2 flex items-center justify-between">
                          <div>
                            <p className="font-medium text-slate-900">
                              801-06 · เสากุญแจ/เกี่ยว 53 มม.
                            </p>
                            <p className="text-[11px] text-slate-500">
                              เส้นโรงงาน 6,400 มม. · มุมตัด 90° / 90°
                            </p>
                          </div>
                          <div className="text-right tabular-nums">
                            <p className="font-semibold text-slate-900">
                              ตัด 2,020 มม.
                            </p>
                            <p className="text-[11px] text-slate-500">8 ชิ้น</p>
                          </div>
                        </div>
                      </div>

                      {/* Proportional 1D Bin-Packing Bar Visual */}
                      <div className="pt-1 space-y-1.5">
                        <div className="flex items-center justify-between text-[11px] text-slate-600">
                          <span>ผังจัดท่อน 801-06 (ช่วงใช้งาน 6,300 มม.)</span>
                          <span className="tabular-nums font-medium text-slate-900">
                            รวม 3 เส้น
                          </span>
                        </div>
                        <div className="h-5 w-full rounded bg-slate-200 overflow-hidden flex border border-slate-300/80 text-[10px] text-white font-medium tabular-nums">
                          <div className="w-[32%] bg-[#0F2557] flex items-center justify-center border-r border-white">
                            2020
                          </div>
                          <div className="w-[32%] bg-[#0F2557] flex items-center justify-center border-r border-white">
                            2020
                          </div>
                          <div className="w-[32%] bg-[#0F2557] flex items-center justify-center border-r border-white">
                            2020
                          </div>
                        </div>
                        <p className="text-[11px] text-slate-500 tabular-nums">
                          เส้นที่ #1: ใช้ 6,068 มม. · เหลือ 232 มม. · ใบเลื่อย 4 มม.
                        </p>
                      </div>
                    </div>
                  </div>

                  {/* QR Code Direct Scan Card */}
                  <div className="bg-white border border-slate-200 rounded-xl p-4 flex items-center gap-4">
                    <div
                      className="w-24 h-24 shrink-0 border border-slate-200 rounded-lg p-1.5 flex items-center justify-center bg-white"
                      dangerouslySetInnerHTML={{ __html: qrSvg }}
                    />
                    <div className="space-y-1">
                      <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-900">
                        <Smartphone className="w-4 h-4 stroke-[1.75] text-slate-600" />
                        <span>สแกนเพื่อดาวน์โหลดลงมือถือ</span>
                      </div>
                      <p className="text-xs text-slate-600 leading-relaxed">
                        เปิดกล้องถ่ายรูปหรือแอปอ่านคิวอาร์โค้ดบนโทรศัพท์ Android
                        เพื่อดาวน์โหลดไฟล์ติดตั้งได้โดยตรง
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Capabilities Section */}
        <section id="capabilities" className="py-16 border-b border-slate-200">
          <div className="max-w-6xl mx-auto px-6 space-y-10">
            <div className="max-w-2xl space-y-2">
              <h2 className="text-xl sm:text-2xl font-semibold text-slate-900">
                ขอบเขตการทำงานของแอปพลิเคชัน
              </h2>
              <p className="text-sm sm:text-base text-slate-600">
                รวมขั้นตอนตั้งแต่การถอดสูตรระยะตัดหน้างาน การสั่งซื้อเส้นอลูมิเนียม
                ไปจนถึงการออกเอกสารเสนอราคาลูกค้าไว้ในแอปเดียว
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {capabilities.map((item) => {
                const Icon = item.icon;
                return (
                  <div
                    key={item.title}
                    className="bg-white border border-slate-200 rounded-xl p-6 space-y-3"
                  >
                    <div className="w-9 h-9 rounded-lg bg-slate-100 border border-slate-200/80 flex items-center justify-center text-slate-700">
                      <Icon className="w-[18px] h-[18px] stroke-[1.75]" />
                    </div>
                    <h3 className="text-base font-semibold text-slate-900">
                      {item.title}
                    </h3>
                    <p className="text-sm text-slate-600 leading-relaxed">
                      {item.desc}
                    </p>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        {/* Technical Specifications & Installation Steps (5:7 Split) */}
        <section id="specifications" className="py-16 bg-white">
          <div className="max-w-6xl mx-auto px-6">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
              {/* Left 5 Cols: Technical Specs */}
              <div className="lg:col-span-5 bg-[#F8FAFC] border border-slate-200 rounded-xl p-6 space-y-4">
                <h2 className="text-lg font-semibold text-slate-900">
                  ข้อมูลจำเพาะของไฟล์ติดตั้ง
                </h2>

                <dl className="divide-y divide-slate-200 text-sm">
                  <div className="py-2.5 flex justify-between gap-4">
                    <dt className="text-slate-600">ชื่อแอปพลิเคชัน</dt>
                    <dd className="font-medium text-slate-900 text-right">
                      {meta.appName}
                    </dd>
                  </div>
                  <div className="py-2.5 flex justify-between gap-4">
                    <dt className="text-slate-600">รหัสแพ็กเกจ</dt>
                    <dd className="font-mono text-xs text-slate-900 text-right tabular-nums">
                      {meta.packageId}
                    </dd>
                  </div>
                  <div className="py-2.5 flex justify-between gap-4">
                    <dt className="text-slate-600">เวอร์ชันและสิทธิ์</dt>
                    <dd className="font-medium text-slate-900 text-right tabular-nums">
                      {meta.version}
                    </dd>
                  </div>
                  <div className="py-2.5 flex justify-between gap-4">
                    <dt className="text-slate-600">ระบบที่รองรับ</dt>
                    <dd className="font-medium text-slate-900 text-right">
                      Android 7.0 ขึ้นไป (ARM64 / ARMv7)
                    </dd>
                  </div>
                  <div className="py-2.5 flex justify-between gap-4">
                    <dt className="text-slate-600">ขนาดไฟล์</dt>
                    <dd className="font-medium text-slate-900 text-right tabular-nums">
                      {meta.sizeMb} MB
                    </dd>
                  </div>
                  <div className="py-2.5 flex justify-between gap-4">
                    <dt className="text-slate-600">วันที่อัปเดต</dt>
                    <dd className="font-medium text-slate-900 text-right tabular-nums">
                      {meta.updatedAt}
                    </dd>
                  </div>
                  <div className="pt-3 space-y-1">
                    <dt className="text-xs text-slate-600 flex items-center gap-1.5">
                      <ShieldCheck className="w-4 h-4 stroke-[1.75] text-emerald-700" />
                      <span>รหัสตรวจสอบความถูกต้องของไฟล์ (SHA-256)</span>
                    </dt>
                    <dd className="font-mono text-[11px] text-slate-700 break-all bg-white border border-slate-200 rounded p-2 tabular-nums">
                      {meta.sha256}
                    </dd>
                  </div>
                </dl>
              </div>

              {/* Right 7 Cols: Installation Guide */}
              <div id="installation" className="lg:col-span-7 space-y-6">
                <div className="space-y-1.5">
                  <h2 className="text-lg sm:text-xl font-semibold text-slate-900">
                    ขั้นตอนการติดตั้งบนโทรศัพท์และแท็บเล็ต Android
                  </h2>
                  <p className="text-sm text-slate-600">
                    สามารถติดตั้งคู่กับแอปพลิเคชันอื่นบนเครื่องเดียวกันได้ทันทีโดยไม่กระทบข้อมูลเดิม
                  </p>
                </div>

                <ol className="space-y-4">
                  {installSteps.map((step, idx) => (
                    <li
                      key={step.title}
                      className="bg-white border border-slate-200 rounded-xl p-5 flex items-start gap-4"
                    >
                      <span className="w-7 h-7 rounded-md bg-[#0F2557] text-white text-xs font-semibold flex items-center justify-center shrink-0 tabular-nums mt-0.5">
                        {idx + 1}
                      </span>
                      <div className="space-y-1">
                        <h3 className="text-sm sm:text-base font-semibold text-slate-900">
                          {step.title}
                        </h3>
                        <p className="text-sm text-slate-600 leading-relaxed">
                          {step.desc}
                        </p>
                      </div>
                    </li>
                  ))}
                </ol>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* Quiet Corporate Footer */}
      <footer className="border-t border-slate-200 bg-[#F8FAFC]">
        <div className="max-w-6xl mx-auto px-6 py-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
          <p>© 2026 บริษัท อัครพลกระจก อลูมิเนียม จำกัด สงวนลิขสิทธิ์</p>
          <p>ซอฟต์แวร์คำนวณระยะตัด จัดเส้น และบริหารโครงการสำหรับอุปกรณ์ Android</p>
        </div>
      </footer>
    </div>
  );
}
