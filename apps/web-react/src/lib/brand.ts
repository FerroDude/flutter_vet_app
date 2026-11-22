import { useLayoutEffect } from 'react';
import logoWide from '@/assets/logo-wide.png';
import logoMark from '@/assets/logo-mark.png';

/**
 * Runtime clinic branding. VetTempo owns the shell and all neutrals; a clinic
 * brand may only recolor --primary/--ring/--primary-light/--primary-foreground
 * and --accent. Next phase replaces YOSHI_CLINIC with the clinic Firestore doc.
 */
export interface Brand {
  /** '#RRGGBB' */
  primary: string;
  accent?: string | null;
}

export const VETTEMPO_BRAND: Brand = { primary: '#0E7C72', accent: '#4FD1C1' };

/** Temporary until clinics live in Firestore (next phase). */
export const YOSHI_CLINIC = {
  name: 'Yoshi Vet Care',
  brand: { primary: '#FA5119', accent: '#EA9374' } as Brand,
  logoWide,
  logoMark,
};

const BRAND_VARS = ['--primary', '--ring', '--primary-light', '--primary-foreground', '--accent'];

const DEFAULT_THEME_COLOR = '#0E7C72';
const INK = '#0F2A33';
const WHITE = '#FFFFFF';

function hexToRgb(hex: string): [number, number, number] {
  const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex.trim());
  if (!m || m[1] === undefined || m[2] === undefined || m[3] === undefined) {
    throw new Error(`Invalid hex color: ${hex}`);
  }
  return [parseInt(m[1], 16) / 255, parseInt(m[2], 16) / 255, parseInt(m[3], 16) / 255];
}

/** '#0E7C72' -> '175 80% 27%' — the H S% L% channel format used by the CSS vars. */
export function hexToHslTriple(hex: string): string {
  const [r, g, b] = hexToRgb(hex);
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  const d = max - min;
  let h = 0;
  let s = 0;
  if (d > 0) {
    s = d / (1 - Math.abs(2 * l - 1));
    switch (max) {
      case r: h = 60 * (((g - b) / d) % 6); break;
      case g: h = 60 * ((b - r) / d + 2); break;
      default: h = 60 * ((r - g) / d + 4);
    }
    if (h < 0) h += 360;
  }
  return `${Math.round(h)} ${Math.round(s * 100)}% ${Math.round(l * 100)}%`;
}

function linearize(c: number): number {
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function luminance(hex: string): number {
  const [r, g, b] = hexToRgb(hex).map(linearize) as [number, number, number];
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG 2.x contrast ratio between two '#RRGGBB' colors (1..21). */
export function contrastRatio(a: string, b: string): number {
  const la = luminance(a);
  const lb = luminance(b);
  const [hi, lo] = la >= lb ? [la, lb] : [lb, la];
  return (hi + 0.05) / (lo + 0.05);
}

/** CSS var name -> HSL triple for the overridable clinic-brand tokens. */
export function brandVars(brand: Brand): Record<string, string> {
  const [h, s, l] = hexToHslTriple(brand.primary).split(' ');
  const primary = `${h} ${s} ${l}`;
  const vars: Record<string, string> = {
    '--primary': primary,
    '--ring': primary,
    '--primary-light': `${h} ${s} 95%`,
    '--primary-foreground': hexToHslTriple(
      contrastRatio(WHITE, brand.primary) >= 3 ? WHITE : INK,
    ),
  };
  if (brand.accent) vars['--accent'] = hexToHslTriple(brand.accent);
  return vars;
}

/** Applies clinic brand vars on <html> + theme-color. null resets to VetTempo. */
export function applyBrand(brand: Brand | null): void {
  const style = document.documentElement.style;
  const meta = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]');
  if (brand) {
    for (const [name, value] of Object.entries(brandVars(brand))) {
      style.setProperty(name, value);
    }
    meta?.setAttribute('content', brand.primary);
  } else {
    for (const name of BRAND_VARS) style.removeProperty(name);
    meta?.setAttribute('content', DEFAULT_THEME_COLOR);
  }
}

/** Applies the brand while mounted; cleans up on unmount/change.
 *  Layout effect so the clinic brand is set before first paint (no teal flash). */
export function useBrand(brand: Brand | null): void {
  useLayoutEffect(() => {
    applyBrand(brand);
    return () => applyBrand(null);
  }, [brand]);
}
