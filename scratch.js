const { PrismaClient } = require('./src/generated/prisma/client');
const prisma = new PrismaClient();

async function run() {
  const comps = await prisma.templateComponent.findMany({
    where: { label: { contains: 'เฟรมบน' } },
    include: { template: true }
  });
  console.log(JSON.stringify(comps, null, 2));

  const templates = await prisma.productTemplate.findMany();
  console.log(JSON.stringify(templates, null, 2));
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
