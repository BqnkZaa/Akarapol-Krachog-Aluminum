"use client";

import { useState, useTransition } from "react";
import { Trash2, Edit2, ArrowRightLeft } from "lucide-react";
import { deleteAccessory } from "@/actions/admin";
import EditAccessoryModal from "./EditAccessoryModal";
import MoveAccessoryModal from "./MoveAccessoryModal";

interface Variant {
  id: string;
  colorName: string;
  unitCost: number;
}

interface AccessoryActionsProps {
  accessory: {
    id: string;
    code: string;
    name: string;
    series: string;
    variants: Variant[];
  };
}

export default function AccessoryActions({ accessory }: AccessoryActionsProps) {
  const [isPending, startTransition] = useTransition();
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [isMoveModalOpen, setIsMoveModalOpen] = useState(false);

  const handleDelete = () => {
    if (!confirm("Are you sure you want to delete this accessory? If it is used in a template, it will be marked as inactive instead.")) return;
    startTransition(async () => {
      const result = await deleteAccessory(accessory.id);
      if (!result.success && result.error) {
        alert(result.error);
      }
    });
  };

  return (
    <>
      <div className="inline-flex items-center gap-1">
        <button
          onClick={() => setIsMoveModalOpen(true)}
          disabled={isPending}
          title="ย้ายไปเส้นอลูมิเนียม"
          className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-amber-600 hover:bg-amber-50 px-2.5 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <ArrowRightLeft className="w-3.5 h-3.5" />
          ย้าย
        </button>
        <button
          onClick={() => setIsEditModalOpen(true)}
          disabled={isPending}
          title="Edit accessory"
          className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-blue-600 hover:bg-blue-50 px-2.5 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <Edit2 className="w-3.5 h-3.5" />
          Edit
        </button>
        <button
          onClick={handleDelete}
          disabled={isPending}
          title="Delete accessory"
          className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 px-2.5 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <Trash2 className="w-3.5 h-3.5" />
          {isPending ? "Deleting..." : "Delete"}
        </button>
      </div>

      {isEditModalOpen && (
        <EditAccessoryModal
          accessory={accessory}
          onClose={() => setIsEditModalOpen(false)}
        />
      )}

      {isMoveModalOpen && (
        <MoveAccessoryModal
          accessory={accessory}
          onClose={() => setIsMoveModalOpen(false)}
        />
      )}
    </>
  );
}

