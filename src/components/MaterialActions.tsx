"use client";

import { useState, useTransition } from "react";
import { Trash2, Edit2, ArrowRightLeft } from "lucide-react";
import { deleteMaterial } from "@/actions/admin";
import EditMaterialModal from "./EditMaterialModal";
import MoveMaterialModal from "./MoveMaterialModal";

interface Variant {
  id: string;
  colorName: string;
  unitCost: number;
}

interface MaterialActionsProps {
  material: {
    id: string;
    code: string;
    name: string;
    variants: Variant[];
  };
}

export default function MaterialActions({ material }: MaterialActionsProps) {
  const [isPending, startTransition] = useTransition();
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);

  const handleDelete = () => {
    if (!confirm("Are you sure you want to delete this material? If it is used in a template, it will be marked as inactive instead.")) return;
    startTransition(async () => {
      const result = await deleteMaterial(material.id);
      if (!result.success && result.error) {
        alert(result.error);
      }
    });
  };

  const [isMoveModalOpen, setIsMoveModalOpen] = useState(false);

  return (
    <>
      <div className="inline-flex items-center gap-1">
        <button
          onClick={() => setIsMoveModalOpen(true)}
          disabled={isPending}
          title="ย้ายรายการนี้ไปอุปกรณ์เสริม"
          className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-amber-600 hover:bg-amber-50 px-2.5 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <ArrowRightLeft className="w-3.5 h-3.5" />
          ย้าย
        </button>
        <button
          onClick={() => setIsEditModalOpen(true)}
          disabled={isPending}
          title="แก้ไขข้อมูลเส้นอลูมิเนียม"
          className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-blue-600 hover:bg-blue-50 px-2.5 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <Edit2 className="w-3.5 h-3.5" />
          แก้ไข
        </button>
        <button
          onClick={handleDelete}
          disabled={isPending}
          title="ลบข้อมูลเส้นอลูมิเนียม"
          className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 px-2.5 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <Trash2 className="w-3.5 h-3.5" />
          {isPending ? "กำลังลบ..." : "ลบ"}
        </button>
      </div>

      {isEditModalOpen && (
        <EditMaterialModal
          material={material}
          onClose={() => setIsEditModalOpen(false)}
        />
      )}

      {isMoveModalOpen && (
        <MoveMaterialModal
          material={material}
          onClose={() => setIsMoveModalOpen(false)}
        />
      )}
    </>
  );
}
