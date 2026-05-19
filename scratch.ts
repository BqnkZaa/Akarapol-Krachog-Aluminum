import prisma from "./src/lib/prisma";

async function main() {
  const material = await prisma.material.findFirst({
    where: { code: { contains: "is-0101", mode: "insensitive" } },
    include: { category: true }
  });
  console.log(material);
}

main();
