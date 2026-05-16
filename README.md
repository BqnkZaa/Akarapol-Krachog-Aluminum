# ⬡ SmartQuote Aluminum

**A professional Cost Estimation & CPQ (Configure, Price, Quote) web application for aluminum door and window contractors.**

SmartQuote replaces error-prone manual spreadsheets with a structured, real-time quoting workflow. Sales operators can configure a Bill of Materials (BOM) from a live catalog of aluminum profiles, apply profit margins and labor costs, instantly preview the final selling price, and export a clean PDF quotation for the customer — all in a few taps.

---

## ✨ Core Features

### Phase 1 — Quotation Engine
- **Step-by-Step Quotation Wizard** — A guided 4-step flow (Category → Material → Color → Quantity) that builds a BOM without overwhelming the user.
- **Dynamic Color-Variant Pricing** — Each aluminum profile has independent unit costs per color (White / Black / Wood Grain), matching real manufacturer pricing structures.
- **Real-Time Price Preview** — Subtotal, profit margin, labor cost, and discount are calculated client-side instantly as items are added or adjusted.
- **Server-Side Price Verification** — When a quotation is saved, the server re-fetches all prices directly from the database, making client-side price tampering impossible.
- **Print / Export to PDF** — A dedicated `window.print()` action with Tailwind `print:` media classes that strips all UI chrome and renders a clean, professional customer-facing document.
- **Quotation Persistence** — Projects are saved with a full price snapshot (`unitCost` and `materialCost` per item), ensuring historical records are never affected by future price changes.

### Phase 2 — Admin Dashboard & Master Data Management
- **Dashboard** — Live overview of catalog statistics (categories, materials, saved quotations) with quick-action shortcuts.
- **Materials Catalog** — A full table view of all aluminum profiles, grouped by brand/series, with color swatch pricing chips.
- **Add Material Form** — A structured form to register new profiles with multi-color pricing in a single atomic database transaction.
- **Soft-Delete** — Deactivating a material sets `isActive = false` instead of deleting the record, preserving the integrity of all historical quotations that reference it.

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | [Next.js 16](https://nextjs.org/) — App Router, Server Components, Server Actions |
| **Language** | TypeScript 5 |
| **ORM** | [Prisma v7](https://www.prisma.io/) with driver adapter architecture |
| **Database** | SQLite (dev) via `better-sqlite3` — drop-in swap to PostgreSQL for production |
| **Styling** | [Tailwind CSS v4](https://tailwindcss.com/) |
| **Icons** | [Lucide React](https://lucide.dev/) |
| **Runtime** | Node.js 22+ |

---

## 📁 Project Structure

```
aluminum/
├── prisma/
│   ├── schema.prisma        # Database schema — all models defined here
│   └── seed.ts              # Seed script: colors, categories, iConiq profiles
├── src/
│   ├── actions/
│   │   ├── admin.ts         # Server actions: createMaterial, deleteMaterial
│   │   ├── estimation.ts    # Server actions: save/fetch estimation projects
│   │   └── material.ts      # Server actions: getColors, getCategoriesWithMaterials
│   ├── app/
│   │   ├── layout.tsx       # Root layout with global Sidebar
│   │   ├── page.tsx         # / — New Quotation page
│   │   ├── dashboard/
│   │   │   └── page.tsx     # /dashboard — Stats & quick actions
│   │   └── materials/
│   │       ├── page.tsx     # /materials — Materials catalog table
│   │       └── new/
│   │           └── page.tsx # /materials/new — Add material form
│   ├── components/
│   │   ├── MaterialActions.tsx  # Deactivate button (client)
│   │   ├── NewMaterialForm.tsx  # Add material form (client)
│   │   ├── QuotationBuilder.tsx # Full quotation wizard + BOM (client)
│   │   └── Sidebar.tsx          # Navigation sidebar (client)
│   ├── generated/
│   │   └── prisma/          # Auto-generated Prisma v7 client (do not edit)
│   └── lib/
│       └── prisma.ts        # Singleton PrismaClient with SQLite adapter
├── .env                     # Environment variables (DATABASE_URL)
├── prisma.config.ts         # Prisma v7 config (schema path, seed command)
└── package.json
```

---

## 🗄 Data Architecture

The schema is built around a **raw material BOM** philosophy — materials are individual aluminum profiles priced per piece or length, not finished product types.

```
Category (Brand/Series)
  └── Material (Raw Profile — e.g. "iS-0101 Top/Bottom Sliding Frame")
        └── MaterialVariant (Color × Price — e.g. White: ฿185, Black: ฿210)

EstimationProject (Quotation header — customer info, margin, labor)
  └── EstimationItem (BOM line — material + variant + qty + snapshotted price)
```

**Cost formula (per item):**
```
materialCost = quantity × unitCost   ← unitCost sourced from DB, not client
```

**Final price formula (per project):**
```
subtotal       = Σ materialCost per item
marginAmount   = subtotal × (profitMarginPercent / 100)
beforeDiscount = subtotal + marginAmount + laborCost + additionalCost
discountAmount = beforeDiscount × (discountPercent / 100)
finalPrice     = beforeDiscount − discountAmount
```

---

## 🚀 Getting Started

### Prerequisites

- Node.js **v22** or later
- npm v10 or later

### 1. Clone & Install

```bash
git clone <your-repo-url>
cd aluminum
npm install
```

### 2. Configure Environment

Create a `.env` file at the project root:

```env
DATABASE_URL="file:./prisma/dev.db"
```

> **Switching to PostgreSQL:** Update `DATABASE_URL` to a PostgreSQL connection string and change the `provider` in `prisma/schema.prisma` from `"sqlite"` to `"postgresql"`. Then re-run migrations.

### 3. Run Database Migrations

```bash
npx prisma migrate dev --name init
```

This creates the SQLite database file and applies the full schema.

### 4. Seed the Database

```bash
npx prisma db seed
```

This populates the database with:
- 3 colors: ขาว (White), ดำ (Black), ลายไม้ (Wood Grain)
- 2 categories: iConiq Sliding Series, Alumet Euro Casement Series
- 4 iConiq sliding door profiles (iS-0101 to iS-0104) with color pricing
- 1 sample quotation project to verify the cost engine

### 5. Start the Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

| Route | Description |
|---|---|
| `/` | Quotation Builder Wizard |
| `/dashboard` | Stats overview & quick actions |
| `/materials` | Full material catalog |
| `/materials/new` | Add a new material profile |

---

## 🔑 Key Implementation Notes

### Prisma v7 — Driver Adapter Required

Prisma v7 no longer bundles a query engine binary. An explicit **driver adapter** is required. This project uses `@prisma/adapter-better-sqlite3` for SQLite:

```typescript
// src/lib/prisma.ts
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });
```

The singleton is guarded with `globalThis` to prevent connection exhaustion during Next.js hot-reloads in development.

### Security — Server-Side Price Verification

The quotation form submits only `materialVariantId` and `quantity`. **No price data ever comes from the client.** The `saveEstimationProject` server action fetches all unit costs from the database before calculation:

```typescript
// src/actions/estimation.ts
const dbVariants = await prisma.materialVariant.findMany({
  where: { id: { in: variantIds } },
  select: { id: true, unitCost: true },
});
// unitCost is always sourced from the DB map — never from the request payload
```

### Soft-Delete Pattern

Materials are never hard-deleted. `deleteMaterial` sets `isActive = false`, which:
- Hides the material from the quotation wizard and catalog
- Preserves all `EstimationItem` records that reference the material
- Maintains full historical quotation accuracy

---

## 📦 Production Deployment

### Build

```bash
npm run build
npm run start
```

### Recommended Production Database

Migrate from SQLite to **PostgreSQL** for multi-user production use:

1. Update `DATABASE_URL` in your production environment variables.
2. Change `provider = "postgresql"` in `prisma/schema.prisma`.
3. Install the PostgreSQL adapter: `npm install @prisma/adapter-pg pg`
4. Update `src/lib/prisma.ts` to use `PrismaPg` from `@prisma/adapter-pg`.
5. Run `npx prisma migrate deploy` in production.

---

## 📄 License

This project was built as a custom solution for an aluminum contractor client. All rights reserved.

---

*Built with ❤️ using Next.js 16, Prisma v7, and Tailwind CSS v4.*
