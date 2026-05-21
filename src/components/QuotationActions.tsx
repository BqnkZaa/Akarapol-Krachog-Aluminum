"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Trash2, Loader2, Eye, Edit } from "lucide-react";
import { deleteQuotation } from "@/actions/quotation";
import ViewQuotationModal from "./ViewQuotationModal";

interface QuotationActionsProps {
  quotationId: string;
}

export default function QuotationActions({ quotationId }: QuotationActionsProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [isDeleting, setIsDeleting] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const handleDelete = () => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบใบเสนอราคานี้?")) {
      setIsDeleting(true);
      startTransition(async () => {
        try {
          const result = await deleteQuotation(quotationId);
          if (!result.success) {
            alert(result.error || "ลบใบเสนอราคาไม่สำเร็จ");
          }
        } finally {
          setIsDeleting(false);
        }
      });
    }
  };

  const loading = isPending || isDeleting;

  return (
    <>
      <div className="flex items-center justify-end gap-1 sm:gap-2">
        {/* ดูรายละเอียด (View) */}
        <button
          onClick={() => setIsModalOpen(true)}
          className="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
          title="ดูรายละเอียด"
        >
          <Eye className="w-4.5 h-4.5" />
        </button>

        {/* แก้ไข (Edit) */}
        <button
          onClick={() => router.push(`/?edit=${quotationId}`)}
          className="p-2 text-gray-400 hover:text-amber-600 hover:bg-amber-50 rounded-lg transition-colors"
          title="แก้ไข"
        >
          <Edit className="w-4.5 h-4.5" />
        </button>

        {/* ลบ (Delete) */}
        <button
          onClick={handleDelete}
          disabled={loading}
          className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50"
          title="ลบ"
        >
          {loading ? (
            <Loader2 className="w-4.5 h-4.5 animate-spin text-red-600" />
          ) : (
            <Trash2 className="w-4.5 h-4.5" />
          )}
        </button>
      </div>

      {/* Read-only details modal */}
      <ViewQuotationModal 
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        quotationId={quotationId}
      />
    </>
  );
}
