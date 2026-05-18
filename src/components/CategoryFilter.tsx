"use client";

import { useRouter } from "next/navigation";

interface CategoryFilterProps {
  categories: { id: string; name: string }[];
  currentQuery: string;
  currentCategoryId: string;
}

export default function CategoryFilter({
  categories,
  currentQuery,
  currentCategoryId,
}: CategoryFilterProps) {
  const router = useRouter();

  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const newCat = e.target.value;
    const params = new URLSearchParams();
    if (currentQuery) params.set("q", currentQuery);
    if (newCat) params.set("cat", newCat);
    
    // Reset to page 1 on filter change
    params.set("page", "1");

    router.push(`/materials?${params.toString()}`);
  };

  return (
    <select
      value={currentCategoryId}
      onChange={handleChange}
      className="text-sm border border-gray-200 rounded-xl px-3 py-2 bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 min-w-[160px]"
    >
      <option value="">All categories</option>
      {categories.map((cat) => (
        <option key={cat.id} value={cat.id}>
          {cat.name}
        </option>
      ))}
    </select>
  );
}
