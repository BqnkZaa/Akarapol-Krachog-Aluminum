"use server";

import prisma from "@/lib/prisma";
import { revalidatePath } from "next/cache";

const PAGE_SIZE = 20;

export interface QuotationListItem {
  id: string;
  projectName: string;
  customerName: string | null;
  templateName: string;
  createdAt: Date;
  finalPrice: number;
  status: string;
}

export async function getQuotations(page: number = 1) {
  const skip = (page - 1) * PAGE_SIZE;

  const [projects, total] = await Promise.all([
    prisma.estimationProject.findMany({
      skip,
      take: PAGE_SIZE,
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        projectName: true,
        customerName: true,
        createdAt: true,
        status: true,
        glassCost: true,
        accessoryCost: true,
        materialCost: true,
        profitMarginPercent: true,
        laborCost: true,
        additionalCost: true,
        discountPercent: true,
        template: {
          select: {
            name: true,
          },
        },
      },
    }),
    prisma.estimationProject.count(),
  ]);

  const items: QuotationListItem[] = projects.map((p) => {
    // Recompute total price dynamically
    const subtotal = p.materialCost + p.glassCost + p.accessoryCost;
    const marginAmount = subtotal * (p.profitMarginPercent / 100);
    const beforeDiscount = subtotal + marginAmount + p.laborCost + p.additionalCost;
    const discountAmount = beforeDiscount * (p.discountPercent / 100);
    const finalPrice = beforeDiscount - discountAmount;

    return {
      id: p.id,
      projectName: p.projectName,
      customerName: p.customerName,
      templateName: p.template.name,
      createdAt: p.createdAt,
      finalPrice: Math.round(finalPrice * 100) / 100,
      status: p.status,
    };
  });

  return { items, total, totalPages: Math.ceil(total / PAGE_SIZE) };
}

export async function deleteQuotation(id: string) {
  try {
    await prisma.estimationProject.delete({
      where: { id },
    });
    revalidatePath("/quotations");
    return { success: true };
  } catch (error) {
    console.error("[deleteQuotation] Error deleting quotation:", error);
    return { success: false, error: "Failed to delete quotation" };
  }
}
