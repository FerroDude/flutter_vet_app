# VetTempo Web — Design System (DESIGN.md)

This is the **canonical design spec** for `apps/web-react`. It overrides the
defaults in the `interface-kit` skill. When building any screen or component,
follow these tokens and rules.

**Brand model.** VetTempo is the platform shell: it owns the login screen, the
error/"no access" screens, the public QR pet page, the favicon, the fonts and
every neutral. Inside the signed-in apps (`VetApp`/`ClientApp`) the *clinic*
brand applies — clinic logo plus clinic primary colour. The override surface is
deliberately small (see §2); neutrals always stay VetTempo. For now there is a
single hardcoded clinic (`YOSHI_CLINIC` in `src/lib/brand.ts`) until clinics
exist in Firestore.

---

## 0. Design intent — don't look AI-generated

The single goal of the visual layer: feel **cleanly designed, simple, professional,
and healthcare-credible** — like a tool a vet clinic would trust with patient data.
The fastest way to fail that is to drift toward the "generated UI" mean. Visitors
form a trust verdict in ~50ms, and a page that pattern-matches to default AI output
loses trust before the content is read.

### The tell cluster — actively avoid (no single one is fatal; the *stack* is)

- Inter / Roboto / system-sans as the only typeface, no display pairing, no tracking.
- Blue→purple (or pastel) gradients on white; neon; glassmorphism; faux-3D glow.
- Oversized **bold** headings doing all the hierarchy work.
- A flat stack of identical sections — every title same size/weight, same spacing.
- `grid-cols-3` of three equal cards for everything; centered SaaS hero.
- `transition-all duration-300 ease-in-out` on everything; one uniform soft shadow.
- Vague microcopy ("Welcome back", "Manage your stuff", "build the future"),
  superlatives, em-dash soup.
- Oversized rounded corners (≥24px) on every surface for generic "comfort".

### What we do instead (our point of view)

- **Type with intent.** Sora everywhere, in distinct weights — big titles use
  *restraint* — `.display-title` (weight 500, tight tracking), not 700 bold.
  Section labels use the `.eyebrow` pattern.
- **Editorial rhythm.** Sections lead with an eyebrow → title (`SectionHeader`),
  so the page reads as deliberately composed, not auto-stacked.
- **One confident hero color** (the VetTempo teal on the shell; the clinic
  primary inside the apps). No gradients.
- **Layered shadows** (multi-offset, low opacity) for real depth; hairlines for
  separation. Crisper radius, concentric.
- **Specific microcopy.** Time-aware greeting + real date; say exactly what a
  thing is. No filler, no hype.
- **Number-heavy = tabular-nums everywhere** numbers change.

### Anchored references (the *reason* is what matters, not the name)

- **Linear** — the quiet confidence of its spacing rhythm and restraint; nothing
  shouts.
- **Stripe** — information density that never feels crowded; calm hierarchy.
- **One Medical / Maven** — clinical warmth: soft neutrals, generous whitespace,
  trustworthy not sterile.

### The "last 5%" — where slop hides (fill these, don't let the model average them)

Every interactive element needs *every* state defined: hover, **press**, **focus-visible**,
disabled, loading. Plus: the neutral ramp, the exact radius delta between a chip and
its card, the tracking on display type at 32px, `::selection`, hover gating on touch,
`prefers-reduced-motion`. These seams are 95% of "feels designed vs feels generated".

---

## 1. Aesthetic direction

**Refined clinical.** Calm, trustworthy. Generous whitespace, a confident teal
as the VetTempo hero color, Sora across the board (weight contrast instead of a
serif pairing). Soft layered shadows over hard borders. Pill-shaped primary
actions.

Commit to this. Do **not** introduce purple/blue gradients, neon, glassmorphism,
or generic SaaS hero clichés. One hero color per context (VetTempo teal on the
shell, clinic primary inside the apps), used confidently.

---

## 2. Color tokens

Reference colors by **semantic token only** — never hardcode hex in components.

### VetTempo source palette (hex)

```
vt-ink        #0F2A33   azul-petróleo escuro — text / dark surfaces
vt-teal       #0E7C72   verde-azulado — VetTempo primary
vt-teal-light #4FD1C1   light teal — decor on dark surfaces only (too light for text on light bg)
surface       #FFFFFF   cards, sheets, popovers
text-muted    #3D5560   cinzento-azulado — secondary text
border        #C9D8DC   cinzento muito claro — hairlines, input borders
muted         #E3ECEE   quase branco — secondary fills
bg            #F6FAF9   fundo claro — app background
```

Event/category colors (parity with mobile semantics):
```
appointment   #3b82f6 (info blue)
medication    violet (262 52% 55%) — was teal, moved so it can't clash with brand primaries
symptom       #e23670 (magenta pink)
```

### Light theme — CSS variables (HSL, shadcn convention)

```css
:root {
  --background:           165 29% 97%;   /* #F6FAF9 */
  --foreground:           195 55% 13%;   /* #0F2A33 */
  --card:                 0 0% 100%;
  --card-foreground:      195 55% 13%;
  --popover:              0 0% 100%;
  --popover-foreground:   195 55% 13%;
  --primary:              175 80% 27%;   /* #0E7C72 — clinic-overridable */
  --primary-foreground:   0 0% 100%;
  --primary-light:        175 80% 95%;   /* primary H/S, L 95% */
  --secondary:            191 24% 91%;   /* #E3ECEE */
  --secondary-foreground: 195 55% 13%;
  --muted:                191 24% 91%;
  --muted-foreground:     199 22% 31%;   /* #3D5560 */
  --accent:               173 59% 56%;   /* #4FD1C1 — clinic-overridable */
  --accent-foreground:    195 55% 13%;
  --destructive:          0 84% 60%;
  --destructive-foreground: 0 0% 100%;
  --success:              152 60% 36%;
  --warning:              38 92% 50%;
  --info:                 217 91% 60%;
  --border:               193 21% 83%;   /* #C9D8DC */
  --input:                193 21% 83%;
  --ring:                 175 80% 27%;   /* = --primary */

  /* Fixed VetTempo brand — clinic branding must NEVER override these. */
  --vt-ink:               195 55% 13%;
  --vt-teal:              175 80% 27%;
  --vt-teal-light:        173 59% 56%;

  --radius: 0.875rem;                    /* 14px base (md) */
}
```

The app is light-only — there is no dark theme.

### Clinic brand overrides (`src/lib/brand.ts`)

Only these tokens are overridable by a clinic brand, applied as inline styles on
`document.documentElement` by `applyBrand(brand)` / `useBrand(brand)`:

- `--primary` and `--ring` = clinic primary (hex → HSL triple)
- `--primary-light` = primary H/S with L 95%
- `--primary-foreground` = white when `contrastRatio('#FFFFFF', primary) >= 3`,
  else VetTempo ink `#0F2A33`
- `--accent` = clinic accent, only when provided (`--accent-foreground` unchanged)

Everything else — neutrals, `--vt-*`, shadows, event colors — stays VetTempo.
`applyBrand(null)` removes exactly those inline properties and resets
`<meta name="theme-color">` to `#0E7C72`.

Rules: WCAG AA — 4.5:1 normal text, 3:1 large. Never use color alone to convey
state (pair with icon/label). Default CTAs use `--primary`; `--accent` is for
tint fills and decorative touches (the light teal is never text on light
backgrounds). Shell surfaces (auth, gates, public tag page) always show VetTempo
brand; signed-in surfaces show the clinic brand.

---

## 3. Typography

```css
--font-sans:    "Sora", system-ui, -apple-system, sans-serif; /* body/UI + headings */
--font-display: "Sora", system-ui, -apple-system, sans-serif; /* same face, kept for font-display classes */
--font-mono:    "JetBrains Mono", "Fira Code", monospace;     /* code/ids */
```

Load via Google Fonts: Sora weights 300/400/500/600/700 (`display=swap`).

**Wordmark rule**: "VET" Sora 700 + "tempo" Sora 300, no space — only ever set
via `VetTempoLogo` (or the generated brand PNGs), never retyped.

Root setup:
```css
html { -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale;
       text-rendering: optimizeLegibility; }
h1,h2,h3,h4,h5,h6 { font-family: var(--font-display); text-wrap: balance;
                    letter-spacing: -0.02em; line-height: 1.15; }
p,li,dd,blockquote { text-wrap: pretty; }
.tabular, [data-numeric] { font-variant-numeric: tabular-nums; }
```

**Use `tabular-nums` everywhere numbers update**: dose counts, adherence %,
unread badges, dates, stats. This app is number-heavy.

Type scale (px): `12 / 14 / 16 / 18 / 24 / 32 / 48`. Body base **16px** (never
below 14). Body line-height 1.5–1.6; headings 1.1–1.2. Max body line length
`65ch`.

Weights: display headings 500 (`.display-title`); body 400; UI labels 500;
section labels 600; wordmark "VET" 700 / "tempo" 300.

Section label pattern: uppercase, `letter-spacing: 0.12em`,
`font-size: 0.6875rem`, weight 600, color `--primary`.

---

## 4. Logo usage

All logos live in `src/components/ui/Logo.tsx`:

- `VetTempoMark({ tone })` — the C-ring + pulse mark only, inline SVG, sized by
  font-size/height. Uses fixed `--vt-*` colors: light tone = ink ring + teal
  pulse; dark tone = white ring + light-teal pulse. Never recolors with clinic
  brand. `aria-hidden`.
- `VetTempoLogo({ variant = 'wide' | 'mark', tone = 'light' | 'dark' })` —
  wide = mark + "VETtempo" wordmark, sized by a `text-*` class.
  `role="img" aria-label="VetTempo"`. Use on all VetTempo-shell surfaces.
- `ClinicLogo({ src, name })` — the signed-in clinic's raster logo inside
  `AppLayout` (sidebar + mobile top bar); `alt` = clinic name.

Raster brand assets in `public/brand/`: `vettempo-logo.png` (light-bg wide),
`vettempo-logo-white.png` (dark-bg wide), `vettempo-icon-512.png` (teal tile).

---

## 5. Spacing, radius, shadows

Spacing scale (4/8 base), Tailwind-aligned:
`4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 96`.

Radius (kept deliberately crisp — not the generic ≥24px "comfort" blob):
```
--radius-sm: 10px;  /* inputs, small chips, inner elements */
--radius-md: 14px;  /* cards, popovers (base) */
--radius-lg: 24px;  /* large feature cards, modals, sheets */
--radius-pill: 999px; /* primary/secondary buttons, tags */
```
**Concentric radius**: inner = outer − padding. Never repeat the same radius on
parent and child.

Shadows — **layered** (multiple offsets at low opacity), never a single diffuse
blur (the generic "soft glow" default). Tinted with the petrol ink:
```css
--shadow-sm: 0 1px 1px rgba(15,42,51,.04), 0 2px 4px rgba(15,42,51,.04);
--shadow-md: 0 1px 2px rgba(15,42,51,.04), 0 5px 14px rgba(15,42,51,.05),
             0 12px 28px rgba(15,42,51,.05);
--shadow-lg: 0 2px 4px rgba(15,42,51,.05), 0 12px 30px rgba(15,42,51,.07),
             0 28px 58px rgba(15,42,51,.10);
```

Hit areas: min **44×44px** for all interactive elements; extend small icons with
invisible padding. Min 8px between adjacent targets.

Z-index scale:
```
--z-base:0; --z-dropdown:10; --z-sticky:20; --z-overlay:40; --z-modal:100; --z-toast:1000;
```

---

## 6. Motion

Frequency-based budget:
- High-frequency (tab switch, list nav, keyboard): **instant**, no animation.
- Hover/toggles: 50–120ms.
- Modals/drawers/toasts/page transitions: 150–300ms.
- First-time/empty/celebration: up to 300–500ms.

Easing:
```css
--ease-out: cubic-bezier(0.23, 1, 0.32, 1);
--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
```

Rules: never `transition: all` (name properties). Press feedback
`:active { transform: scale(0.97); }` on buttons. Enter from `scale(0.95)`+opacity,
never `scale(0)`. Exits faster than enters. Stagger list enters ~50–80ms. Use CSS
transitions (interruptible) for interactive states. Gate hover effects behind
`@media (hover:hover) and (pointer:fine)`. Always honor
`prefers-reduced-motion: reduce`.

---

## 7. Component specs

Built on **shadcn/ui (Radix + Tailwind + CVA)**, themed to the tokens above.

**Button**
- Variants: `primary` (primary fill, primary-foreground text, pill),
  `secondary` (surface bg, border, pill; hover → primary border+text),
  `accent` (rare), `ghost`, `destructive`, `outline`.
- Sizes: sm `h-9 px-4`, md `h-11 px-6`, lg `h-12 px-7`.
- Pill radius. Press scale 0.97. Visible focus ring (`--ring`). Loading state =
  spinner replacing label, dimensions preserved. Disabled = `opacity:.5;
  pointer-events:none`.

**Card** — `surface` bg, `--radius-lg`, `--shadow-md`, concentric inner radius.
Hover (interactive cards only): `translateY(-2px)` + shadow step up.

**Input / form** — `surface` bg, `--radius-sm`, `1px solid --input`, focus → brand
ring. **Always visible labels** (never placeholder-only). Errors near field with
`aria-live="polite"`. React Hook Form + Zod. 16px input font (avoids iOS zoom).

**Dialog / Modal** — Radix Dialog. Focus trap, ESC + overlay click to close,
`transform-origin:center`, fade+scale enter. `role="dialog"`, `aria-modal`,
`aria-labelledby`. Sheets/drawers slide with `--ease-spring`.

**Navigation** — desktop: left sidebar (role-aware items) + top bar. Mobile:
bottom tab bar or hamburger drawer. Active item uses `--primary-light` bg + primary
text/icon. The sidebar carries the clinic logo (`ClinicLogo`) plus a muted
"powered by VetTempo" line (mark + wordmark text, `text-xs`).

**Badges / chips** — pill, `--primary-light` for neutral/primary, semantic tints for
status (pending/confirmed/denied, med status). Unread count badge uses
`tabular-nums`.

**Chat** — message bubbles: own messages primary-tinted right-aligned, others
surface left-aligned; rounded with a single squared corner toward sender;
read/delivered ticks; typing indicator (3-dot) driven by RTDB; virtualized list.

**Status color mapping**
```
pending   warning (amber)   confirmed success (green)   denied/cancelled muted/destructive
med active success   paused warning   completed muted   discontinued destructive
```

---

## 8. Accessibility (non-negotiable)

- Semantic HTML first (`button`, `nav`, `main`, `header`, `section`) before ARIA.
- Full keyboard nav: Tab/Shift+Tab, Enter/Space, arrows in lists/menus/tabs,
  Esc to close, Home/End in lists.
- Visible focus rings always (`:focus-visible` → 2px `--ring`, offset 2px). Never
  `outline:none` without replacement. Restore focus on modal close.
- Contrast AA. Don't signal by color alone.
- Alt text for meaningful images (pet photos: `alt="<pet name>"`; `ClinicLogo`
  `alt` = clinic name); `alt=""`/`aria-hidden` for decorative (e.g. `VetTempoMark`).
- One `<h1>` per page; sequential heading order.
- `aria-live` for toasts, form errors, new chat messages.
- Skip-to-content link. Test: axe-core in CI, Lighthouse a11y ≥ 90, keyboard-only
  pass, screen reader (NVDA) on key flows.

---

## 9. Implementation mapping

- Put the CSS variables in `src/index.css`; mirror them in `@theme inline`
  (`--color-*` → `hsl(var(--token))`, plus `vt-ink`/`vt-teal`/`vt-teal-light`
  so `bg-vt-ink` etc. work).
- shadcn components consume the semantic tokens directly.
- Clinic branding goes through `src/lib/brand.ts` only — components never set
  CSS vars themselves, and nothing outside `brand.ts` touches the overridable
  tokens at runtime.
- Event/status colors live as named tokens (`--event-appointment`, etc.) so the
  calendar and dashboards match mobile semantics.
- Keep this file the single source of truth; when in doubt, follow `interface-kit`
  for the *how*, this file for the *what*.
