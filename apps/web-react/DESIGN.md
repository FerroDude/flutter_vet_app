# Vet+ Web — Design System (DESIGN.md)

This is the **canonical design spec** for `apps/web-react`. It overrides the
defaults in the `interface-kit` skill. When building any screen or component,
follow these tokens and rules. The visual language is taken from the Vet+ landing
page (`FerroDude/vetPlusLanding`): warm, calm, clinical-but-human — deep teal,
off-white paper, a serif display face, soft rounded surfaces.

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

- **Type pairing with intent.** Fraunces (serif display, optical sizing) +
  DM Sans. Big titles use *restraint* — `.display-title` (weight 500, tight
  tracking), not 700 bold. Section labels use the `.eyebrow` pattern.
- **Editorial rhythm.** Sections lead with an eyebrow → title (`SectionHeader`),
  so the page reads as deliberately composed, not auto-stacked.
- **One confident hero color** (teal), orange accent used sparingly. No gradients.
- **Layered shadows** (multi-offset, low opacity) for real depth; hairlines for
  separation. Crisper radius (lg = 20, md = 12), concentric.
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

**Organic / refined clinical.** Calm, trustworthy, warm. Generous whitespace,
a confident teal as the single hero color, a serif (`Fraunces`) for headings to
add warmth and personality, a clean grotesque (`DM Sans`) for everything else.
Soft layered shadows over hard borders. Pill-shaped primary actions.

Commit to this. Do **not** introduce purple/blue gradients, neon, glassmorphism,
or generic SaaS hero clichés. One hero color (teal), one warm accent (orange),
used sparingly.

---

## 2. Color tokens

Authoring source (hex, from the landing) and the shadcn-style HSL custom
properties to put in `globals.css`. Reference colors by **semantic token only** —
never hardcode hex in components.

### Source palette (hex)

```
bg            #f8faf9   warm off-white (app background)
surface       #ffffff   cards, sheets, inputs
text          #0f1a17   near-black green (primary text)
text-muted    #4a5f58   secondary text
primary       #0d7a6b   deep teal  ← hero
primary-dark  #095c51   hover/pressed primary
primary-light #e6f5f2   teal tint (selected/active backgrounds)
accent        #f4a261   warm orange (use sparingly: highlights, never as default CTA)
accent-dark   #d4894a
border        #dce8e4   hairline dividers, input borders
success       #10b981
warning       #f59e0b
error / destructive #ef4444
info          #3b82f6
```

Event/category colors (parity with mobile semantics):
```
appointment   #3b82f6 (info blue)
medication     #0d7a6b (teal/primary)
symptom        #f59e0b (warning amber)
```

### Light theme — CSS variables (HSL, shadcn convention)

```css
:root {
  --background:           160 16% 97%;   /* #f8faf9 */
  --foreground:           160 28% 8%;    /* #0f1a17 */
  --card:                 0 0% 100%;
  --card-foreground:      160 28% 8%;
  --popover:              0 0% 100%;
  --popover-foreground:   160 28% 8%;
  --primary:              171 81% 26%;   /* #0d7a6b */
  --primary-foreground:   0 0% 100%;
  --primary-light:        168 52% 93%;   /* #e6f5f2 */
  --secondary:            160 16% 94%;
  --secondary-foreground: 160 28% 8%;
  --muted:                160 16% 94%;
  --muted-foreground:     162 14% 33%;   /* #4a5f58 */
  --accent:               27 87% 67%;    /* #f4a261 */
  --accent-foreground:    160 28% 8%;
  --destructive:          0 84% 60%;     /* #ef4444 */
  --destructive-foreground: 0 0% 100%;
  --success:              160 84% 39%;
  --warning:              38 92% 50%;
  --info:                 217 91% 60%;
  --border:               156 24% 89%;   /* #dce8e4 */
  --input:                156 24% 89%;
  --ring:                 171 81% 26%;   /* teal focus ring */
  --radius: 0.875rem;                    /* 14px base (md) */
}
```

### Dark theme — desaturated tonal variants (NOT inverted)

Backgrounds deep green-charcoal, not pure black. Text off-white, not pure white.
Primary lifts slightly for contrast on dark. Test contrast separately.

```css
.dark {
  --background:           165 24% 7%;    /* deep green-charcoal */
  --foreground:           160 16% 93%;
  --card:                 165 22% 10%;
  --card-foreground:      160 16% 93%;
  --popover:              165 22% 10%;
  --popover-foreground:   160 16% 93%;
  --primary:              168 60% 45%;   /* lifted teal */
  --primary-foreground:   165 30% 6%;
  --primary-light:        168 40% 16%;
  --secondary:            165 18% 14%;
  --secondary-foreground: 160 16% 93%;
  --muted:                165 18% 14%;
  --muted-foreground:     160 12% 65%;
  --accent:               27 70% 60%;
  --accent-foreground:    165 30% 6%;
  --destructive:          0 72% 55%;
  --destructive-foreground: 0 0% 100%;
  --border:               165 14% 20%;
  --input:                165 14% 20%;
  --ring:                 168 60% 45%;
}
```

Rules: WCAG AA — 4.5:1 normal text, 3:1 large. Never use color alone to convey
state (pair with icon/label). Use `--accent` (orange) sparingly; default CTAs are
teal `--primary`.

---

## 3. Typography

```css
--font-display: "Fraunces", Georgia, "Times New Roman", serif;  /* headings */
--font-sans:    "DM Sans", system-ui, -apple-system, sans-serif; /* body/UI */
--font-mono:    "JetBrains Mono", "Fira Code", monospace;        /* code/ids */
```

Load via Google Fonts (or self-host): Fraunces (weights 400/600/700, opsz),
DM Sans (400/500/600/700).

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

Weights: display headings 600–700; body 400; UI labels 500; section labels 600.

Section label pattern (from landing): uppercase, `letter-spacing: 0.06em`,
`font-size: 0.8125rem`, color `--primary`.

---

## 4. Spacing, radius, shadows

Spacing scale (4/8 base), Tailwind-aligned:
`4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 96`.

Radius (kept deliberately crisp — not the generic ≥24px "comfort" blob):
```
--radius-sm: 8px;   /* inputs, small chips, inner elements */
--radius-md: 12px;  /* cards, popovers (base) */
--radius-lg: 20px;  /* large feature cards, modals, sheets */
--radius-pill: 999px; /* primary/secondary buttons, tags */
```
**Concentric radius**: inner = outer − padding. e.g. card `lg(20)` with `8px`
padding → inner `12px`. Never repeat the same radius on parent and child.

Shadows — **layered** (multiple offsets at low opacity), never a single diffuse
blur (the generic "soft glow" default):
```css
--shadow-sm: 0 1px 1px rgba(15,26,23,.04), 0 2px 4px rgba(15,26,23,.04);
--shadow-md: 0 1px 2px rgba(15,26,23,.04), 0 5px 14px rgba(15,26,23,.05),
             0 12px 28px rgba(15,26,23,.05);
--shadow-lg: 0 2px 4px rgba(15,26,23,.05), 0 12px 30px rgba(15,26,23,.07),
             0 28px 58px rgba(15,26,23,.10);
```

Hit areas: min **44×44px** for all interactive elements; extend small icons with
invisible padding. Min 8px between adjacent targets.

Z-index scale:
```
--z-base:0; --z-dropdown:10; --z-sticky:20; --z-overlay:40; --z-modal:100; --z-toast:1000;
```

---

## 5. Motion

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
`:active { transform: scale(0.97); }` on buttons (matches landing `scale(0.98)`).
Enter from `scale(0.95)`+opacity, never `scale(0)`. Exits faster than enters.
Stagger list enters ~50–80ms. Use CSS transitions (interruptible) for interactive
states. Gate hover effects behind `@media (hover:hover) and (pointer:fine)`.
Always honor `prefers-reduced-motion: reduce`.

---

## 6. Component specs

Built on **shadcn/ui (Radix + Tailwind + CVA)**, themed to the tokens above.

**Button**
- Variants: `primary` (teal fill, white text, pill, `--shadow` teal glow),
  `secondary` (surface bg, border, pill; hover → teal border+text),
  `accent` (orange — rare), `ghost`, `destructive`, `outline`.
- Sizes: sm `h-9 px-4`, md `h-11 px-6`, lg `h-12 px-7`.
- Pill radius. Press scale 0.97. Visible focus ring (`--ring`). Loading state =
  spinner replacing label, dimensions preserved. Disabled = `opacity:.5;
  pointer-events:none`.

**Card** — `surface` bg, `--radius-lg`, `--shadow-md`, concentric inner radius.
Hover (interactive cards only): `translateY(-2px)` + shadow step up.

**Input / form** — `surface` bg, `--radius-sm`, `1px solid --input`, focus → teal
ring. **Always visible labels** (never placeholder-only). Errors near field with
`aria-live="polite"`. React Hook Form + Zod. 16px input font (avoids iOS zoom).

**Dialog / Modal** — Radix Dialog. Focus trap, ESC + overlay click to close,
`transform-origin:center`, fade+scale enter. `role="dialog"`, `aria-modal`,
`aria-labelledby`. Sheets/drawers slide with `--ease-spring`.

**Navigation** — desktop: left sidebar (role-aware items) + top bar. Mobile:
bottom tab bar or hamburger drawer. Active item uses `--primary-light` bg + teal
text/icon.

**Badges / chips** — pill, `--primary-light` for neutral/teal, semantic tints for
status (pending/confirmed/denied, med status). Unread count badge uses
`tabular-nums`.

**Chat** — message bubbles: own messages teal-tinted right-aligned, others
surface left-aligned; rounded with a single squared corner toward sender;
read/delivered ticks; typing indicator (3-dot) driven by RTDB; virtualized list.

**Status color mapping**
```
pending   warning (amber)   confirmed success (green)   denied/cancelled muted/destructive
med active success   paused warning   completed muted   discontinued destructive
```

---

## 7. Accessibility (non-negotiable)

- Semantic HTML first (`button`, `nav`, `main`, `header`, `section`) before ARIA.
- Full keyboard nav: Tab/Shift+Tab, Enter/Space, arrows in lists/menus/tabs,
  Esc to close, Home/End in lists.
- Visible focus rings always (`:focus-visible` → 2px `--ring`, offset 2px). Never
  `outline:none` without replacement. Restore focus on modal close.
- Contrast AA in both themes. Don't signal by color alone.
- Alt text for meaningful images (pet photos: `alt="<pet name>"`); `alt=""` for
  decorative.
- One `<h1>` per page; sequential heading order.
- `aria-live` for toasts, form errors, new chat messages.
- Skip-to-content link. Test: axe-core in CI, Lighthouse a11y ≥ 90, keyboard-only
  pass, screen reader (NVDA) on key flows.

---

## 8. Implementation mapping

- Put the CSS variables in `src/index.css` / `globals.css`; mirror them in
  `tailwind.config.ts` (`theme.extend.colors` → `hsl(var(--token))`,
  `borderRadius`, `boxShadow`, `fontFamily`).
- shadcn components consume the semantic tokens directly.
- Event/status colors live as named tokens (`--event-appointment`, etc.) so the
  calendar and dashboards match mobile semantics.
- Keep this file the single source of truth; when in doubt, follow `interface-kit`
  for the *how*, this file for the *what*.
