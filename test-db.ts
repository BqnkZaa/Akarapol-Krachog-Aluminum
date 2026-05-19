import { PrismaClient } from './src/generated/prisma/client/index.js';

const prisma = new PrismaClient();

async function run() {
  const comps = await prisma.templateComponent.findMany({
    where: { label: { contains: 'เฟรมบน' } },
    include: { template: true }
  });
  console.log('Components with เฟรมบน:', JSON.stringify(comps, null, 2));

  const templates = await prisma.productTemplate.findMany({
    where: { standardBarLengthMm: 1 }
  });
  console.log('Templates with standardBarLengthMm 1:', JSON.stringify(templates, null, 2));
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
