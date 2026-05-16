"use client";

import { useTransition } from "react";
import { Trash2 } from "lucide-react";
import { deleteMaterial } from "@/actions/admin";

export default function MaterialActions({ materialId }: { materialId: string }) {
  const [isPending, startTransition] = useTransition();

  const handleDelete = () => {
    if (!confirm("Mark this material as inactive? It will no longer appear in the quotation wizard.")) return;
    startTransition(async () => {
      await deleteMaterial(materialId);
    });
  };

  return (
    <button
      onClick={handleDelete}
      disabled={isPending}
      title="Deactivate material"
      className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 px-2.5 py-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
    >
      <Trash2 className="w-3.5 h-3.5" />
      {isPending ? "Removing..." : "Deactivate"}
    </button>
  );
}
