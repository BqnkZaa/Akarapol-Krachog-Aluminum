/**
 * src/lib/prisma.ts
 * ─────────────────────────────────────────────────────────────
 * Singleton Prisma v7 client with better-sqlite3 driver adapter.
 *
 * Prisma v7 no longer bundles a query engine — we must provide
 * an explicit driver adapter. For SQLite we use @prisma/adapter-
 * better-sqlite3.
 *
 * The singleton pattern (globalThis.__prisma) is required in
 * Next.js development mode where hot-reloading would otherwise
 * create a new PrismaClient on every module evaluation, quickly
 * exhausting the connection pool.
 * ─────────────────────────────────────────────────────────────
 */

import { PrismaClient } from "@/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const createPrismaClient = () => {
  const adapter = new PrismaBetterSqlite3({
    url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
  });
  return new PrismaClient({ adapter });
};

// In development: attach to globalThis to survive hot-reloads.
// In production: always create a fresh module-scoped singleton.
const globalForPrisma = globalThis as unknown as {
  prisma: ReturnType<typeof createPrismaClient> | undefined;
};

const prisma = globalForPrisma.prisma ?? createPrismaClient();

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}

export default prisma;
