import { pt, type TKey } from './pt';
import { en } from './en';

export type Lang = 'pt' | 'en';
export type { TKey };

const KEY = 'yoshi.lang';

function readLang(): Lang {
  try {
    return localStorage.getItem(KEY) === 'en' ? 'en' : 'pt';
  } catch {
    return 'pt';
  }
}

export const lang: Lang = readLang();
export const locale = lang === 'en' ? 'en-GB' : 'pt-PT';

const dicts: Record<Lang, Record<TKey, string>> = { pt, en };

export function setLang(l: Lang) {
  try {
    localStorage.setItem(KEY, l);
  } catch {
    /* ignore */
  }
  location.reload();
}

export function t(key: TKey, vars?: Record<string, string | number>): string {
  let s: string = dicts[lang][key] ?? pt[key] ?? key;
  if (vars) {
    for (const [k, v] of Object.entries(vars)) {
      s = s.replaceAll(`{${k}}`, String(v));
    }
  }
  return s;
}
