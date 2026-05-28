"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2 } from "lucide-react";
import { deleteCategory } from "@/actions/category";

type Props = {
  categoryId: string;
  categoryName: string;
  materialCount: number;
  templateCount: number;
};

export default function CategoryActions({
  categoryId,
  categoryName,
  materialCount,
  templateCount,
}: Props) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  const handleDelete = () => {
    if (materialCount > 0 || templateCount > 0) {
      alert(
        `ไม่สามารถลบ "${categoryName}" ได้ — มีเส้นอลูมิเนียม ${materialCount} รายการ และรูปแบบงาน ${templateCount} รายการ โปรดลบหรือย้ายข้อมูลก่อน`
      );
      return;
    }

    if (
      !confirm(
        `คุณแน่ใจหรือไม่ว่าต้องการลบ "${categoryName}"? การกระทำนี้ไม่สามารถย้อนกลับได้`
      )
    )
      return;

    startTransition(async () => {
      const result = await deleteCategory(categoryId);
      if (!result.success) {
        alert(result.error);
      }
    });
  };

  return (
    <div className="flex items-center gap-1">
      <button
        onClick={() =>
          router.push(`/admin/categories/${categoryId}/edit`)
        }
        disabled={isPending}
        title="แก้ไขซีรีส์"
        id={`edit-category-${categoryId}`}
        className="inline-flex items-center gap-1 text-xs font-medium text-gray-500 hover:text-blue-600 hover:bg-blue-50 px-2 py-1.5 rounded-lg transition-colors disabled:opacity-40"
      >
        <Pencil className="w-3.5 h-3.5" />
        แก้ไข
      </button>
      <button
        onClick={handleDelete}
        disabled={isPending}
        title="ลบซีรีส์"
        id={`delete-category-${categoryId}`}
        className="inline-flex items-center gap-1 text-xs font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 px-2 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
      >
        <Trash2 className="w-3.5 h-3.5" />
        {isPending ? "กำลังลบ…" : "ลบ"}
      </button>
    </div>
  );
}
