import { normalizeText } from './format';

/** Case- and accent-insensitive "contains" for people-name searches. */
export function matchesQuery(query: string, text: string): boolean {
  const q = normalizeText(query.trim());
  return !q || normalizeText(text).includes(q);
}
