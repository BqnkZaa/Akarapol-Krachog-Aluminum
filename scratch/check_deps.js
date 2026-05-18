import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function check() {
  const cats = await prisma.category.findMany({ where: { name: { contains: 'iConiq' } } });
  for (const cat of cats) {
    console.log(`Checking category: ${cat.name} (${cat.id})`);
    
    const materials = await prisma.material.findMany({ where: { categoryId: cat.id } });
    console.log(`  Materials: ${materials.length}`);
    for (const mat of materials) {
      const tcCount = await prisma.templateComponent.count({ where: { materialId: mat.id } });
      const crCount = await prisma.cuttingResult.count({ where: { materialId: mat.id } });
      if (tcCount > 0 || crCount > 0) {
        console.log(`  Material ${mat.code} (${mat.id}) is used in ${tcCount} TemplateComponents and ${crCount} CuttingResults.`);
      }
    }
    
    const templates = await prisma.productTemplate.findMany({ where: { categoryId: cat.id } });
    console.log(`  Templates: ${templates.length}`);
    for (const t of templates) {
      const projCount = await prisma.estimationProject.count({ where: { templateId: t.id } });
      if (projCount > 0) {
        console.log(`  Template ${t.name} (${t.id}) is used in ${projCount} EstimationProjects.`);
      }
    }
  }
}

check().catch(console.error).finally(() => prisma.$disconnect());
