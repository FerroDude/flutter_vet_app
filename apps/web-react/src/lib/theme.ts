// Light/dark theme manager. Toggles the `.dark` class on <html> (see index.css)
// and persists the choice. Mirrors the mobile ThemeManager intent.

import { useEffect, useState } from 'react';

export type ThemeMode = 'light' | 'dark' | 'system';

const KEY = 'vetplus-theme';

export function getStoredTheme(): ThemeMode {
  const v = typeof localStorage !== 'undefined' ? localStorage.getItem(KEY) : null;
  return v === 'light' || v === 'dark' || v === 'system' ? v : 'system';
}

function systemPrefersDark(): boolean {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches;
}

export function applyTheme(mode: ThemeMode): void {
  const dark = mode === 'dark' || (mode === 'system' && systemPrefersDark());
  document.documentElement.classList.toggle('dark', dark);
}

export function setTheme(mode: ThemeMode): void {
  localStorage.setItem(KEY, mode);
  applyTheme(mode);
}

/** Call once at app startup (before first paint ideally). */
export function initTheme(): void {
  applyTheme(getStoredTheme());
  window
    .matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', () => {
      if (getStoredTheme() === 'system') applyTheme('system');
    });
}

export function useTheme() {
  const [mode, setMode] = useState<ThemeMode>(getStoredTheme);
  useEffect(() => {
    applyTheme(mode);
  }, [mode]);
  const update = (m: ThemeMode) => {
    setTheme(m);
    setMode(m);
  };
  return [mode, update] as const;
}
