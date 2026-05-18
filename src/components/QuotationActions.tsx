"use client";

import { useState, useTransition } from "react";
import { Trash2, Loader2 } from "lucide-react";
import { deleteQuotation } from "@/actions/quotation";

interface QuotationActionsProps {
  quotationId: string;
}

export default function QuotationActions({ quotationId }: QuotationActionsProps) {
  const [isPending, startTransition] = useTransition();
  const [isDeleting, setIsDeleting] = useState(false);

  const handleDelete = () => {
    if (window.confirm("Are you sure you want to delete this quotation? This action cannot be undone.")) {
      setIsDeleting(true);
      startTransition(async () => {
        try {
          const result = await deleteQuotation(quotationId);
          if (!result.success) {
            alert(result.error || "Failed to delete quotation");
          }
        } finally {
          setIsDeleting(false);
        }
      });
    }
  };

  const loading = isPending || isDeleting;

  return (
    <div className="flex items-center justify-end gap-2">
      <button
        onClick={handleDelete}
        disabled={loading}
        className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50"
        title="Delete Quotation"
      >
        {loading ? (
          <Loader2 className="w-4 h-4 animate-spin text-red-600" />
        ) : (
          <Trash2 className="w-4 h-4" />
        )}
      </button>
    </div>
  );
}
