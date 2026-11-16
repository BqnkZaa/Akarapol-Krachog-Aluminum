import { readFile } from "node:fs/promises";
import path from "node:path";
import type { Metadata } from "next";
import {
  Download,
  Smartphone,
  ShieldCheck,
  WifiOff,
  Ruler,
  FileSpreadsheet,
  CheckCircle2,
  FolderKanban,
} from "lucide-react";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "ดาวน์โหลดแอป อัครพลกระจกอลูมิเนียม (.apk)",
  description:
    "ดาวน์โหลดแอปพลิเคชันคำนวณสูตรตัดประกอบ ถอดของ จัดเส้น ทำราคา และออกใบเสนอราคา สำหรับมือถือระบบ Android",
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
      sizeMb: "-",
      sha256: "-",
      updatedAt: "-",
    };
  }
}

export default async function DownloadApkPage() {
  const meta = await loadApkMeta();

  const features = [
    {
      icon: Ruler,
      title: "คำนวณระยะตัดและถอดของครบทุกหมวดหมู่",
      desc: "รองรับชุดตลาด ชุดพัฒนา ชุดยูโรโปรไฟล์ และระบบบานเฟี้ยมครบ 136 รูปแบบผังบาน",
    },
    {
      icon: FolderKanban,
      title: "จัดเส้นอัตโนมัติ (1D Bin-Packing) & แฟ้มโปรเจกต์",
      desc: "คำนวณจำนวนเส้นสั่งซื้อ หักหัวท้าย 100 มม. เผื่อใบเลื่อย 4 มม. และจัดท่อนรวมข้ามรายการทั้งโครงการ",
    },
    {
      icon: FileSpreadsheet,
      title: "ทำราคาเส้น ORM 1,139 รายการ & ออกใบเสนอราคา PDF",
      desc: "รองรับการตั้งราคาเส้นเอง บันทึกข้อมูลร้านพร้อมโลโก้ และส่งออก PDF ทั้งใบสั่งตัด เอกสารโครงการ และใบเสนอราคา",
    },
    {
      icon: WifiOff,
      title: "ทำงาน Offline 100% พร้อมสิทธิ์ VIP ทันที",
      desc: "ติดตั้งใช้งานบนมือถือหรือแท็บเล็ต Android ได้ทันทีหน้างานโดยไม่ต้องเชื่อมต่ออินเทอร์เน็ต",
    },
  ];

  const installSteps = [
    "กดปุ่ม “ดาวน์โหลดไฟล์ติดตั้ง (.apk)” ด้านบนเพื่อบันทึกไฟล์ akkaraphon-toolkit.apk ลงในมือถือ Android",
    "เมื่อดาวน์โหลดเสร็จสิ้น ให้แตะเปิดไฟล์จากแถบแจ้งเตือน หรือจากแอป “ไฟล์ / Downloads” ในเครื่อง",
    "หากระบบถามสิทธิ์ครั้งแรก ให้กด “การตั้งค่า (Settings)” แล้วเปิดอนุญาต “ติดตั้งแอปที่ไม่รู้จักจากเบราว์เซอร์นี้”",
    "กดปุ่ม “ติดตั้ง (Install)” เมื่อเสร็จแล้วกด “เปิด (Open)” เพื่อเข้าใช้งานแอป อัครพลกระจกอลูมิเนียม ได้ทันที",
  ];

  return (
    <main className="min-h-screen bg-slate-50 py-10 px-4 sm:px-8">
      <div className="max-w-4xl mx-auto space-y-8">
        {/* Hero Download Card */}
        <section className="bg-gradient-to-br from-blue-700 via-blue-800 to-slate-900 rounded-3xl p-8 sm:p-10 text-white shadow-xl">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/15 text-blue-100 text-xs font-semibold mb-5">
            <Smartphone className="w-4 h-4" />
            <span>Android Application (.apk) · สิทธิ์ VIP พร้อมใช้งาน Offline 100%</span>
          </div>

          <h1 className="text-2xl sm:text-4xl font-bold tracking-tight">
            {meta.appName}
          </h1>
          <p className="mt-3 text-blue-100 text-sm sm:text-base max-w-2xl leading-relaxed">
            แอปพลิเคชันเครื่องมือช่างกระจกและอลูมิเนียม คำนวณสูตรตัดประกอบ ถอดรายการวัสดุ
            บริหารการจัดเส้น ทำราคาต้นทุน และออกใบเสนอราคา PDF สำหรับ บริษัท อัครพลกระจก อลูมิเนียม จำกัด
          </p>

          <div className="mt-7 flex flex-col sm:flex-row sm:items-center gap-4">
            <a
              href="/downloads/akkaraphon-toolkit.apk"
              download="akkaraphon-toolkit.apk"
              className="inline-flex items-center justify-center gap-3 px-7 py-4 rounded-2xl bg-white text-blue-800 font-bold text-base shadow-lg hover:bg-blue-50 transition-colors"
            >
              <Download className="w-5 h-5" />
              <span>ดาวน์โหลดไฟล์ติดตั้ง (.apk)</span>
            </a>

            <a
              href="https://github.com/BqnkZaa/Akarapol-Krachog-Aluminum/releases/download/v0.1.7/akkaraphon-toolkit.apk"
              className="inline-flex items-center justify-center gap-2 px-5 py-4 rounded-2xl bg-blue-950/60 border border-white/20 text-white font-semibold text-sm hover:bg-blue-950/80 transition-colors"
            >
              <Download className="w-4 h-4" />
              <span>ลิงก์สำรองความเร็วสูง (GitHub CDN)</span>
            </a>

            <div className="text-xs sm:text-sm text-blue-100 space-y-0.5">
              <p className="font-semibold text-white">
                เวอร์ชัน {meta.version} · ขนาดไฟล์ {meta.sizeMb} MB
              </p>
              <p className="text-blue-200">
                รองรับ Android 7.0 ขึ้นไป · ติดตั้งคู่กับแอปอื่นได้ทันที ({meta.packageId})
              </p>
            </div>
          </div>

          <div className="mt-6 pt-5 border-t border-white/15 grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs text-blue-200">
            <div>
              <span className="text-blue-300 block">ชื่อไฟล์</span>
              <span className="font-mono text-white">{meta.fileName}</span>
            </div>
            <div>
              <span className="text-blue-300 block">อัปเดตล่าสุด</span>
              <span className="text-white">{meta.updatedAt}</span>
            </div>
            <div className="sm:col-span-1">
              <span className="text-blue-300 flex items-center gap-1">
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-300" />
                SHA-256 (ย่อ)
              </span>
              <span className="font-mono text-white break-all">
                {meta.sha256 !== "-" ? `${meta.sha256.slice(0, 20)}...` : "-"}
              </span>
            </div>
          </div>
        </section>

        {/* Feature Grid */}
        <section className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {features.map((f) => {
            const Icon = f.icon;
            return (
              <div
                key={f.title}
                className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm flex items-start gap-4"
              >
                <div className="w-11 h-11 rounded-xl bg-blue-50 text-blue-700 flex items-center justify-center shrink-0">
                  <Icon className="w-5 h-5" />
                </div>
                <div>
                  <h2 className="font-bold text-slate-900 text-sm sm:text-base">
                    {f.title}
                  </h2>
                  <p className="mt-1 text-xs sm:text-sm text-slate-600 leading-relaxed">
                    {f.desc}
                  </p>
                </div>
              </div>
            );
          })}
        </section>

        {/* Step-by-Step Android Installation Guide */}
        <section className="bg-white rounded-2xl p-6 sm:p-8 border border-slate-200 shadow-sm">
          <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 text-emerald-600" />
            ขั้นตอนการติดตั้งแอป (.apk) บนมือถือ Android
          </h2>
          <ol className="mt-5 space-y-4">
            {installSteps.map((step, idx) => (
              <li key={idx} className="flex items-start gap-3.5">
                <span className="w-7 h-7 rounded-full bg-blue-600 text-white text-xs font-bold flex items-center justify-center shrink-0 mt-0.5">
                  {idx + 1}
                </span>
                <p className="text-sm text-slate-700 leading-relaxed">{step}</p>
              </li>
            ))}
          </ol>
        </section>
      </div>
    </main>
  );
}
