import { CATEGORY_BY_KEY } from "@/lib/categories";
import type { CategoryKey } from "@/lib/types";

export function CategoryIcon({
  cat,
  className,
}: {
  cat: CategoryKey;
  className?: string;
}) {
  const meta = CATEGORY_BY_KEY[cat];
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      dangerouslySetInnerHTML={{ __html: meta.icon }}
    />
  );
}
