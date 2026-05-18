"use client";

import { useState, useTransition } from "react";
import { Trash2, Edit2 } from "lucide-react";
import { deleteMaterial } from "@/actions/admin";
import EditMaterialModal from "./EditMaterialModal";

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
    if (!confirm("Mark this material as inactive? It will no longer appear in the quotation wizard.")) return;
    startTransition(async () => {
      await deleteMaterial(material.id);
    });
  };

  return (
    <>
      <div className="inline-flex items-center gap-1">
        <button
          onClick={() => setIsEditModalOpen(true)}
          disabled={isPending}
          title="Edit material"
          className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-blue-600 hover:bg-blue-50 px-2.5 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <Edit2 className="w-3.5 h-3.5" />
          Edit
        </button>
        <button
          onClick={handleDelete}
          disabled={isPending}
          title="Deactivate material"
          className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 px-2.5 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <Trash2 className="w-3.5 h-3.5" />
          {isPending ? "Removing..." : "Deactivate"}
        </button>
      </div>

      {isEditModalOpen && (
        <EditMaterialModal
          material={material}
          onClose={() => setIsEditModalOpen(false)}
        />
      )}
    </>
  );
}
