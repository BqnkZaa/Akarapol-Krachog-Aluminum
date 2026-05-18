import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function test() {
  const materials = await prisma.material.findMany({ take: 1 });
  if (materials.length > 0) {
    console.log("Found material:", materials[0]);
    try {
      const updated = await prisma.material.update({
        where: { id: materials[0].id },
        data: { isActive: false },
      });
      console.log("Successfully set isActive: false", updated);
      
      const reverted = await prisma.material.update({
        where: { id: materials[0].id },
        data: { isActive: true },
      });
      console.log("Successfully reverted", reverted);
    } catch (e) {
      console.error("Error soft deleting:", e);
    }
  } else {
    console.log("No materials found.");
  }
}

test().finally(() => prisma.$disconnect());
