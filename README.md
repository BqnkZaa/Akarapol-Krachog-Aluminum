# ⬡ SmartQuote Aluminum

**A professional Parametric Cost Estimation & CPQ (Configure, Price, Quote) web application for aluminum door and window contractors.**

SmartQuote has evolved from a manual Bill of Materials (BOM) builder into a fully automated **Parametric Estimator**. Sales operators can simply select a product template (e.g., "iConiq Sliding Door 2-Panel"), select a color, input the Width (W) and Height (H), and let the sophisticated backend engine instantly calculate exact cut lengths, run bin-packing optimizations to determine how many raw aluminum bars to purchase, and generate a final quotation — all in seconds.

---

## ✨ Core Features & Architecture

### 1. Parametric Formula Engine (Zero `eval()`)
- **Template-Driven:** Products are defined as templates containing multiple `TemplateComponent`s.
- **Dynamic Math Parser:** Each component specifies a cut formula (e.g., `W / 2 - 10` or `H - 90`). 
- **Security First:** The formula engine uses a custom-built **Recursive-Descent Parser** with strict whitelisting. It completely avoids the use of `eval()`, protecting the server against code injection vulnerabilities while reliably parsing variables like `W`, `H`, numbers, and operators `+ - * / ( )`.

### 2. 1D Bin Packing Optimization (FFD)
- **First Fit Decreasing Algorithm:** Once the formula engine outputs the required cuts, the cutting optimizer groups them by material and runs an FFD algorithm to place cuts into standard aluminum bar lengths (e.g., 6000mm).
- **Kerf Accounting:** The algorithm perfectly models reality on the shop floor. Every cut accounts for the saw blade thickness (`kerfMm`), ensuring that the estimated number of full bars required is 100% physically realistic. 

### 3. Visual Cut Sheet & Quotation Wizard
- **4-Step Wizard:** A beautiful, intuitive frontend UI guides the user through selecting a Template, Color, Parametric Dimensions (W×H), and Pricing Modifiers (Margin, Labor, Discount).
- **Visual 1D Cut Sheet:** The final result view renders the bin-packing output proportionally! Each required aluminum bar is drawn visually, showing colored segments for the cuts and striped regions for the physical waste, alongside glass area calculations and accessories.
- **Server-Side Price Verification:** All material base costs (`unitCost`) are securely fetched server-side from the active `MaterialVariant` catalog based on the selected color.
- **Immutable Snapshots:** Upon saving, the final calculated costs are snapshotted onto the `EstimationProject`. Future changes to the material catalog pricing will never corrupt historical quotes.

### 4. Admin Dashboard & Master Data Management
- **Dashboard** — Live overview of catalog statistics (Series, Materials, Templates, Quotations) and quick-action shortcuts.
- **Materials Catalog** — Full table view of all aluminum profiles, grouped by series, with per-color pricing chips.
- **Series (Category) CRUD** — `/admin/categories` — Create, edit, and delete brand/series groupings. Deletion is **blocked** at the server if any materials or templates still reference the series, preventing orphaned records.
- **Soft-Delete** — Deactivating a material sets `isActive = false`, preserving the integrity of all historical quotations that reference it.

### 5. Parametric Template Builder (Admin)

The crown jewel of the admin system — a fully dynamic, enterprise-grade form at `/admin/templates` for creating and editing `ProductTemplate` work types without touching the database directly.

**Dynamic Profile Components**
- Admins click **"Add Profile"** to append a new row containing: Material dropdown (grouped by series via `<optgroup>`), Label, Formula string, Quantity, and an optional per-component Bar Length override.
- Rows can be reordered with ↑/↓ buttons and individually removed.
- **Live formula validation:** Every formula field runs through the `validateFormula()` engine on each keystroke. A red ⚠ error or green ✓ confirmation appears inline, giving immediate feedback before any network call is made.

**Glass Specification (Toggleable)**
- A toggle switch reveals the glass section for templates that include glazing. Width and height formulas for the glass pane are also live-validated.

**Fixed Accessories**
- A separate dynamic array for handles, rollers, locks, and other fixed-cost items (name, quantity, unit cost, unit label).

**Atomic `$transaction` with Delete-and-Recreate Strategy**
- `updateTemplate` uses a deliberate **delete-all-children → re-create** approach inside a single Prisma `$transaction`. This is the correct and safest pattern for complex nested form arrays where rows may have been arbitrarily added, removed, or reordered — it avoids complex diff logic while guaranteeing the database never holds a partially updated state.
- `deleteTemplate` **blocks** deletion if any `EstimationProject` references the template, preserving quotation integrity.

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | [Next.js 16](https://nextjs.org/) — App Router, Server Components, Server Actions |
| **Language** | TypeScript 5 |
| **ORM** | [Prisma v7](https://www.prisma.io/) with driver adapter architecture |
| **Database** | PostgreSQL (Supabase) via `@prisma/adapter-pg` |
| **Styling** | [Tailwind CSS v4](https://tailwindcss.com/) |
| **Icons** | [Lucide React](https://lucide.dev/) |
| **Runtime** | Node.js 22+ |

---

## 📁 Project Structure

```
aluminum/
├── prisma/
│   ├── schema.prisma        # Database schema — ProductTemplate, CuttingResult, etc.
│   └── seed.ts              # Seed script: colors, categories, iConiq templates
├── src/
│   ├── actions/
│   │   ├── admin.ts         # createMaterial, deleteMaterial
│   │   ├── category.ts      # createCategory, updateCategory, deleteCategory (Phase 4)
│   │   ├── template.ts      # createTemplate, updateTemplate, deleteTemplate (Phase 4)
│   │   ├── estimation.ts    # runParametricEstimation pipeline, DB persistence
│   │   └── material.ts      # getCategoriesWithMaterials, getColors
│   ├── app/
│   │   ├── page.tsx              # / — Parametric Quotation Wizard
│   │   ├── dashboard/            # /dashboard — Stats & quick actions
│   │   ├── materials/            # /materials — Material catalog
│   │   └── admin/
│   │       ├── categories/       # /admin/categories — Series CRUD
│   │       └── templates/        # /admin/templates — Template Builder
│   ├── components/
│   │   ├── QuotationBuilder.tsx      # 4-step wizard UI & Visual Cut Sheet
│   │   ├── CategoryForm.tsx          # Create/edit series form
│   │   ├── CategoryActions.tsx       # Series row action buttons
│   │   ├── TemplateForm.tsx          # Template Builder orchestrator
│   │   ├── TemplateFormSections.tsx  # ComponentsSection, GlassSection, AccessoriesSection
│   │   ├── TemplateFormTypes.ts      # Shared row types & factory helpers
│   │   ├── TemplateActions.tsx       # Template row action buttons
│   │   └── Sidebar.tsx              # Navigation sidebar (grouped sections)
│   ├── lib/
│   │   ├── formulaParser.ts    # Custom Recursive-Descent Parser + validateFormula()
│   │   ├── cuttingOptimizer.ts # 1D FFD Bin Packing logic
│   │   └── prisma.ts           # Singleton PrismaClient (adapter-pg)
└── .env
```

---

## 🗄 Data Architecture

The schema represents a true Parametric Estimator flow. Legacy `EstimationItem` manual entry rows have been completely removed.

```
ProductTemplate (e.g. iConiq Sliding Door 2-Panel)
  ├── TemplateComponent (Profile + Formula string + bar override)
  ├── GlassSpecification (Area formulas + price/m²)
  └── TemplateAccessory (Fixed items)

EstimationProject (Quotation record with user inputs W, H, margin, labor)
  └── CuttingResult (JSON snapshot of bin-packing outcome per material)
```

**Pipeline Execution Order:**
1. Fetch template & color
2. Run `formulaParser` for each component to generate raw lengths
3. Run `cuttingOptimizer` (FFD + Kerf) on raw lengths to determine Bars
4. Calculate Glass (W×H formula) and Accessories
5. Multiply Bars × Color Variant Unit Cost
6. Apply Margins, Labor, and Discounts
7. Persist atomic snapshot to Database

---

## 🚀 Getting Started

### Prerequisites
- Node.js **v22** or later
- npm v10 or later
- PostgreSQL Database

### 1. Clone & Install

```bash
git clone <your-repo-url>
cd aluminum
npm install
```

### 2. Configure Environment

Create a `.env` file at the project root:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/smartquote"
```

### 3. Run Database Migrations

```bash
npx prisma migrate dev
```

### 4. Seed the Database

```bash
npx prisma db seed
```
This populates the database with:
- 3 colors: ขาว (White), ดำ (Black), ลายไม้ (Wood Grain)
- The fully parametric **iConiq Sliding Door 2-Panel** template, including dynamic formulas for tracks and frames, glass specs, and accessories.

### 5. Start the Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## 📄 License

This project was built as a custom solution for an aluminum contractor client. All rights reserved.

---

*Built with ❤️ using Next.js 16, Prisma v7, and Tailwind CSS v4. — Phase 4 (Parametric Template Builder) complete.*
