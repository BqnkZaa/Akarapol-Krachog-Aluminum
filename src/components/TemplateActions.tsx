"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2 } from "lucide-react";
import { deleteTemplate } from "@/actions/template";

type Props = {
  templateId: string;
  templateName: string;
  projectCount: number;
};

export default function TemplateActions({ templateId, templateName, projectCount }: Props) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  const handleDelete = () => {
    if (projectCount > 0) {
      alert(
        `ไม่สามารถลบ "${templateName}" ได้ — ถูกอ้างอิงในใบเสนอราคา ${projectCount} รายการ โปรดลบหรือย้ายข้อมูลก่อน`
      );
      return;
    }
    if (!confirm(`คุณแน่ใจหรือไม่ว่าต้องการลบ "${templateName}"? การกระทำนี้ไม่สามารถย้อนกลับได้`)) return;

    startTransition(async () => {
      const result = await deleteTemplate(templateId);
      if (!result.success) alert(result.error);
    });
  };

  return (
    <div className="flex items-center justify-end gap-1">
      <button
        onClick={() => router.push(`/admin/templates/${templateId}/edit`)}
        disabled={isPending}
        id={`edit-template-${templateId}`}
        title="แก้ไขรูปแบบงาน"
        className="inline-flex items-center gap-1 text-xs font-medium text-gray-500 hover:text-blue-600 hover:bg-blue-50 px-2 py-1.5 rounded-lg transition-colors disabled:opacity-40"
      >
        <Pencil className="w-3.5 h-3.5" />
        แก้ไข
      </button>
      <button
        onClick={handleDelete}
        disabled={isPending}
        id={`delete-template-${templateId}`}
        title="ลบรูปแบบงาน"
        className="inline-flex items-center gap-1 text-xs font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 px-2 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
      >
        <Trash2 className="w-3.5 h-3.5" />
        {isPending ? "กำลังลบ…" : "ลบ"}
      </button>
    </div>
  );
}
