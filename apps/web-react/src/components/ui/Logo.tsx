import { contrastRatio, VETTEMPO_BRAND } from '@/lib/brand';
import { cn } from '@/lib/cn';

/* VetTempo mark geometry (measured from the brand icon, viewBox 0 0 100 100):
   open "C" ring (gap on the right, where the pulse line exits) + ECG pulse.
   Colors are FIXED VetTempo brand colors — never --primary (the clinic brand
   must not recolor the VetTempo mark). */
const RING_D = 'M79.3 68.8 A40 40 0 1 1 77.9 28.8';
const PULSE_D = 'M13 50 H26 L34.9 38.4 L45.7 62.9 L56.2 46.1 L61.3 50 H90';

interface VetTempoMarkProps {
  /** `light` = for light backgrounds (ink ring, teal pulse). `dark` = for dark surfaces. */
  tone?: 'light' | 'dark';
  className?: string;
}

/** VetTempo mark only (C-ring + pulse). Size with a height class (e.g. `h-4`). */
export function VetTempoMark({ tone = 'light', className }: VetTempoMarkProps) {
  const ring = tone === 'light' ? 'hsl(var(--vt-ink))' : '#FFFFFF';
  const pulse = tone === 'light' ? 'hsl(var(--vt-teal))' : 'hsl(var(--vt-teal-light))';
  // Default h-[1em] (font-size sizing) yields to any caller-supplied height class.
  const hasHeight = (className ?? '')
    .split(/\s+/)
    .some((cls) => /(^|:)(min-h-|max-h-|!h-|h-)/.test(cls));
  return (
    <svg
      viewBox="0 0 100 100"
      fill="none"
      aria-hidden
      className={cn('block w-auto select-none', !hasHeight && 'h-[1em]', className)}
    >
      <path d={RING_D} stroke={ring} strokeWidth={7.6} strokeLinecap="round" />
      <path
        d={PULSE_D}
        stroke={pulse}
        strokeWidth={7.6}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

interface VetTempoLogoProps {
  variant?: 'wide' | 'mark';
  tone?: 'light' | 'dark';
  /** Sized by font-size — use a text-* class (e.g. `text-3xl`). */
  className?: string;
}

/** VetTempo logo: mark + "VETtempo" wordmark (Sora 700 + 300, no space). */
export function VetTempoLogo({ variant = 'wide', tone = 'light', className }: VetTempoLogoProps) {
  if (variant === 'mark') {
    return <VetTempoMark tone={tone} className={cn('text-[1em]', className)} />;
  }
  const vet = tone === 'light' ? 'text-vt-ink' : 'text-white';
  const tempo = tone === 'light' ? 'text-vt-teal' : 'text-vt-teal-light';
  return (
    <span role="img" aria-label="VetTempo" className={cn('inline-flex items-center gap-[0.3em]', className)}>
      <VetTempoMark tone={tone} />
      <span className="tracking-tight">
        <span className={cn('font-bold', vet)}>VET</span>
        <span className={cn('font-light', tempo)}>tempo</span>
      </span>
    </span>
  );
}

interface ClinicLogoProps {
  /** Wide logo URL; falsy falls back to the clinic name as text. */
  src?: string | null;
  /** Clinic name, used as the alt text and the no-logo fallback. */
  name: string;
  className?: string;
}

/** Clinic logo inside the signed-in app. Size with a height class (e.g. `h-7`). */
export function ClinicLogo({ src, name, className }: ClinicLogoProps) {
  if (!src) {
    return (
      <span className={cn('truncate font-semibold text-foreground', className)}>{name}</span>
    );
  }
  return (
    <img
      src={src}
      alt={name}
      className={cn('block w-auto max-w-full select-none', className)}
      draggable={false}
    />
  );
}

/* ---------------------------- Clinic mark ---------------------------- */

/** First letters of the first two words ("Clínica Teste" → "CT"). */
function clinicInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return (parts[0]?.charAt(0) ?? '') + (parts[1]?.charAt(0) ?? parts[0]?.charAt(1) ?? '');
}

export interface ClinicMarkProps {
  /** Clinic brand (logoMarkUrl preferred; monogram on brand.primary otherwise). */
  brand?: { primary: string; logoMarkUrl?: string | null } | null;
  name: string;
  /** Square edge in px (default 28). */
  size?: number;
  className?: string;
}

/**
 * Small square clinic mark used in pickers: the clinic's own logoMarkUrl, or a
 * monogram on its own brand.primary (each clinic keeps its identity regardless
 * of the active theme). Text is white or ink by the same ≥3 contrast rule as
 * brandVars.
 */
export function ClinicMark({ brand, name, size = 28, className }: ClinicMarkProps) {
  const style: React.CSSProperties = {
    width: size,
    height: size,
    boxShadow: 'inset 0 0 0 1px rgb(0 0 0 / 0.06)',
  };
  const cls = cn('grid shrink-0 place-items-center overflow-hidden rounded-(--radius-sm)', className);
  if (brand?.logoMarkUrl) {
    return (
      <span style={style} className={cls}>
        <img
          src={brand.logoMarkUrl}
          alt=""
          draggable={false}
          className="h-full w-full object-contain p-0.5"
        />
      </span>
    );
  }
  const bg = brand?.primary || VETTEMPO_BRAND.primary;
  let fg = '#FFFFFF';
  try {
    fg = contrastRatio('#FFFFFF', bg) >= 3 ? '#FFFFFF' : 'hsl(195 55% 13%)';
  } catch {
    /* keep white */
  }
  return (
    <span
      style={{ ...style, backgroundColor: bg, color: fg, fontSize: size * 0.38 }}
      aria-hidden
      className={cn(cls, 'font-semibold tracking-wide uppercase select-none')}
    >
      {clinicInitials(name)}
    </span>
  );
}
