export const dynamic = 'force-dynamic';
import prisma from "@/lib/prisma";
import { NextResponse } from "next/server";

export async function GET() {
  const templates = await prisma.productTemplate.findMany({
    select: { id: true, name: true, standardBarLengthMm: true }
  });
  const allComps = await prisma.templateComponent.findMany({
    select: { id: true, label: true, barLengthMm: true }
  });
  return NextResponse.json({ templates, allComps });
}
