// The app is light only. Clears a leftover dark/system choice from older builds.

const KEY = 'vetplus-theme';

export function initTheme(): void {
  document.documentElement.classList.remove('dark');
  document.documentElement.style.colorScheme = 'light';
  try {
    localStorage.removeItem(KEY);
  } catch {
    /* private mode */
  }
}
