// Tiny classnames helper (avoids pulling in clsx for now). Filters falsy values.
export function cn(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(' ');
}
