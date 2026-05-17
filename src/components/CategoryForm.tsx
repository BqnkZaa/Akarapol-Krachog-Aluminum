"use client";

import { useState, useTransition, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  Save,
  Loader2,
  AlertCircle,
  CheckCircle2,
  FolderOpen,
} from "lucide-react";
import { createCategory, updateCategory } from "@/actions/category";
import type { CategoryDTO } from "@/actions/category";

type Props =
  | { mode: "create"; initialData?: undefined }
  | { mode: "edit"; initialData: CategoryDTO };

export default function CategoryForm({ mode, initialData }: Props) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  // ─── Form state ─────────────────────────────────────────────
  const [name, setName] = useState(initialData?.name ?? "");
  const [slug, setSlug] = useState(initialData?.slug ?? "");
  const [description, setDescription] = useState(
    initialData?.description ?? ""
  );
  const [imageUrl, setImageUrl] = useState(initialData?.imageUrl ?? "");
  const [sortOrder, setSortOrder] = useState(initialData?.sortOrder ?? 0);
  const [isActive, setIsActive] = useState(initialData?.isActive ?? true);

  // ─── Auto-generate slug from name (create mode only) ────────
  const [slugTouched, setSlugTouched] = useState(mode === "edit");

  useEffect(() => {
    if (!slugTouched && mode === "create") {
      const generated = name
        .toLowerCase()
        .trim()
        .replace(/[^\w\s-]/g, "")
        .replace(/[\s_]+/g, "-")
        .replace(/-+/g, "-")
        .replace(/^-+|-+$/g, "");
      setSlug(generated);
    }
  }, [name, slugTouched, mode]);

  // ─── Feedback ───────────────────────────────────────────────
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // ─── Submit ─────────────────────────────────────────────────
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    startTransition(async () => {
      const payload = {
        name,
        slug,
        description: description || undefined,
        imageUrl: imageUrl || undefined,
        sortOrder,
        isActive,
      };

      const result =
        mode === "edit" && initialData
          ? await updateCategory(initialData.id, payload)
          : await createCategory(payload);

      if (!result.success) {
        setError(result.error);
        return;
      }

      setSuccess(
        mode === "edit"
          ? "อัปเดตซีรีส์สำเร็จ!"
          : "สร้างซีรีส์สำเร็จ!"
      );

      // Redirect after a short delay so the success message is visible
      setTimeout(() => {
        router.push("/admin/categories");
      }, 800);
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6" id="category-form">
      {/* ── Card wrapper ─────────────────────────────────────── */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        {/* Card accent */}
        <div className="h-1 bg-gradient-to-r from-blue-500 to-indigo-500" />

        <div className="p-6 sm:p-8 space-y-6">
          {/* Header icon */}
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 bg-blue-100 rounded-xl flex items-center justify-center">
              <FolderOpen className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-gray-900">
                {mode === "edit" ? "แก้ไขข้อมูลซีรีส์" : "ข้อมูลซีรีส์"}
              </h2>
              <p className="text-xs text-gray-400">
                {mode === "edit"
                  ? "อัปเดตข้อมูลซีรีส์ด้านล่าง"
                  : "กรอกข้อมูลสำหรับซีรีส์ใหม่ของคุณ"}
              </p>
            </div>
          </div>

          {/* ── Name ──────────────────────────────────────── */}
          <div>
            <label
              htmlFor="cat-name"
              className="block text-sm font-semibold text-gray-700 mb-1.5"
            >
              ชื่อซีรีส์ <span className="text-red-500">*</span>
            </label>
            <input
              id="cat-name"
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder='เช่น "iConiq Sliding Series"'
              className="w-full px-4 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-shadow"
            />
          </div>

          {/* ── Slug ──────────────────────────────────────── */}
          <div>
            <label
              htmlFor="cat-slug"
              className="block text-sm font-semibold text-gray-700 mb-1.5"
            >
              Slug <span className="text-red-500">*</span>
            </label>
            <div className="flex items-center gap-2">
              <span className="text-sm text-gray-400 shrink-0">/</span>
              <input
                id="cat-slug"
                type="text"
                required
                value={slug}
                onChange={(e) => {
                  setSlugTouched(true);
                  setSlug(e.target.value);
                }}
                placeholder="iconiq-sliding-series"
                className="flex-1 px-4 py-2.5 border border-gray-300 rounded-xl text-sm font-mono focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-shadow"
              />
            </div>
            <p className="text-xs text-gray-400 mt-1">
              URL ที่ปลอดภัย สร้างอัตโนมัติจากชื่อซีรีส์หากไม่มีการเปลี่ยนแปลง
            </p>
          </div>

          {/* ── Description ───────────────────────────────── */}
          <div>
            <label
              htmlFor="cat-description"
              className="block text-sm font-semibold text-gray-700 mb-1.5"
            >
              คำอธิบาย
            </label>
            <textarea
              id="cat-description"
              rows={3}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="คำอธิบายโดยย่อเกี่ยวกับซีรีส์นี้ (ไม่บังคับ)"
              className="w-full px-4 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-shadow resize-none"
            />
          </div>

          {/* ── Image URL ─────────────────────────────────── */}
          <div>
            <label
              htmlFor="cat-imageUrl"
              className="block text-sm font-semibold text-gray-700 mb-1.5"
            >
              URL รูปภาพ
            </label>
            <input
              id="cat-imageUrl"
              type="url"
              value={imageUrl}
              onChange={(e) => setImageUrl(e.target.value)}
              placeholder="https://example.com/logo.png (ไม่บังคับ)"
              className="w-full px-4 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-shadow"
            />
          </div>

          {/* ── Sort Order & Active toggle ─────────────────── */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label
                htmlFor="cat-sortOrder"
                className="block text-sm font-semibold text-gray-700 mb-1.5"
              >
                ลำดับการแสดงผล
              </label>
              <input
                id="cat-sortOrder"
                type="number"
                min={0}
                value={sortOrder}
                onChange={(e) => setSortOrder(parseInt(e.target.value) || 0)}
                className="w-full px-4 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-shadow"
              />
              <p className="text-xs text-gray-400 mt-1">
                ตัวเลขน้อย = แสดงผลก่อน
              </p>
            </div>

            <div className="flex items-center gap-3 sm:pt-7">
              <button
                type="button"
                role="switch"
                aria-checked={isActive}
                id="cat-isActive"
                onClick={() => setIsActive(!isActive)}
                className={`relative w-11 h-6 rounded-full transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 ${
                  isActive ? "bg-blue-600" : "bg-gray-300"
                }`}
              >
                <span
                  className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transform transition-transform duration-200 ${
                    isActive ? "translate-x-5" : "translate-x-0"
                  }`}
                />
              </button>
              <span className="text-sm font-medium text-gray-700">
                {isActive ? "เปิดใช้งาน" : "ปิดใช้งาน"}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Error message ──────────────────────────────────── */}
      {error && (
        <div className="flex items-start gap-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl px-4 py-3">
          <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
          <p>{error}</p>
        </div>
      )}

      {/* ── Success message ────────────────────────────────── */}
      {success && (
        <div className="flex items-start gap-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-xl px-4 py-3">
          <CheckCircle2 className="w-4 h-4 mt-0.5 shrink-0" />
          <p>{success}</p>
        </div>
      )}

      {/* ── Submit button ──────────────────────────────────── */}
      <div className="flex items-center justify-end gap-3">
        <button
          type="button"
          onClick={() => router.push("/admin/categories")}
          className="px-5 py-2.5 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-xl hover:bg-gray-50 transition-colors"
        >
          ยกเลิก
        </button>
        <button
          type="submit"
          disabled={isPending}
          id="submit-category-btn"
          className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold px-6 py-2.5 rounded-xl shadow-sm transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isPending ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              {mode === "edit" ? "กำลังบันทึก…" : "กำลังสร้าง…"}
            </>
          ) : (
            <>
              <Save className="w-4 h-4" />
              {mode === "edit" ? "บันทึก" : "สร้างซีรีส์"}
            </>
          )}
        </button>
      </div>
    </form>
  );
}
