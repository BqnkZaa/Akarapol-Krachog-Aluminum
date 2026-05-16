/**
 * src/lib/prisma.ts
 * ─────────────────────────────────────────────────────────────
 * Singleton Prisma v7 client with @prisma/adapter-pg for
 * PostgreSQL (Supabase) in production and Next.js/Vercel.
 *
 * Prisma v7 requires an explicit driver adapter.
 * For PostgreSQL we use @prisma/adapter-pg.
 *
 * The globalThis singleton guard is critical in Next.js:
 * hot-reloads in dev would otherwise create a new PrismaClient
 * on every file change, eventually exhausting the connection pool.
 * ─────────────────────────────────────────────────────────────
 */

import { PrismaClient } from "@/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const createPrismaClient = () => {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error("DATABASE_URL environment variable is not set.");
  }
  const adapter = new PrismaPg({ connectionString });
  return new PrismaClient({ adapter });
};

const globalForPrisma = globalThis as unknown as {
  prisma: ReturnType<typeof createPrismaClient> | undefined;
};

const prisma = globalForPrisma.prisma ?? createPrismaClient();

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}

export default prisma;
