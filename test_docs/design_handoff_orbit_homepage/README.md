# Handoff: SapiensCore — ORBIT Public Website (Homepage)

## Overview
ORBIT is a **family entertainment center** brand — a *demo skin* built on top of **SapiensCore**, a white-label loyalty-card platform. This handoff covers the public **homepage**: a warm, welcoming marketing landing page whose primary conversion goals are (1) **Book a visit** (reservation) and (2) **Top up card**, alongside secondary Log in / Join.

SapiensCore is intended to be **skin-based / multi-tenant**: this same site structure should re-theme for other brands (e.g. bowling, trampoline parks). Build with theming in mind — colors, fonts, brand name, and copy should be driven by a theme layer, not hard-coded.

## About the Design Files
The file in this bundle (`SapiensCore Home.dc.html`) is a **design reference created in HTML** — a prototype showing intended look and behavior. It is **not production code to copy directly**. It was authored in a component runtime (`<x-dc>` template + a `Component` logic class); ignore that wrapper.

The task is to **recreate this design in the target codebase's environment** using its established patterns and libraries. If no codebase exists yet, choose an appropriate stack (recommended: **React + a theming layer** such as CSS variables or a `ThemeProvider`, since the product is multi-tenant/skinnable) and implement it there.

## Fidelity
**High-fidelity (hifi).** Colors, typography, spacing, radii, shadows, and interactions below are final for the ORBIT skin. Recreate the UI faithfully, but express the visual values as **theme tokens** so other skins can override them.

---

## Design Tokens

### Colors
| Token | Hex | Usage |
|---|---|---|
| `--ink` | `#2c2733` | Primary text, dark footer/rewards section bg |
| `--paper` | `#f7f1e7` | Page background (warm cream) |
| `--surface` | `#fffdf8` | Cards, nav, dock (warm white) |
| `--surface-2` | `#f2e9da` | Tag chips, subtle fills |
| `--text-muted` | `#5a5265` | Body copy |
| `--text-subtle` | `#8a8194` | Captions, meta |
| `--placeholder-stripe-a` | `#ece0cd` | Image placeholder stripe |
| `--placeholder-stripe-b` | `#e3d5be` | Image placeholder stripe |

**Accent palette (ORBIT skin = "Warm welcome"). These are the four themeable brand colors:**
| Token | Hex | Role |
|---|---|---|
| `--c1` | `#ff7a59` | Primary / coral — main CTAs, brand mark |
| `--c2` | `#ffc247` | Secondary / sunshine — stats band, highlights, "BEST" badge |
| `--c3` | `#3fb984` | Tertiary / leaf green |
| `--c4` | `#4aa8e0` | Quaternary / sky blue |

Two alternate skins were included as theme presets (for testing the skinning layer):
- **Sunset**: `--c1 #ff6f61`, `--c2 #ffab5e`, `--c3 #f2849e`, `--c4 #c66fb0`
- **Meadow**: `--c1 #4fb98a`, `--c2 #ffcf5c`, `--c3 #57bcd9`, `--c4 #f0876d`

### Typography
Google Fonts: **Fredoka** (headings), **Hanken Grotesk** (body/UI), **Space Mono** (eyebrows, numbers, loyalty data).
| Role | Family | Weight | Size | Notes |
|---|---|---|---|---|
| H1 (hero) | Fredoka | 600 | clamp(46px, 6.2vw, 80px) | line-height 1.02, letter-spacing -.02em |
| H2 (section) | Fredoka | 600 | clamp(32–38px … 46–72px) | line-height ~1.02 |
| H3 (card title) | Fredoka | 600 | 22–26px | |
| Body | Hanken Grotesk | 400 | 15–20px | line-height 1.45–1.6 |
| Button label | Hanken Grotesk | 600 | 14–17px | |
| Eyebrow / label | Space Mono | 700 | 11–12px | letter-spacing .12–.16em, uppercase, prefixed `//` |
| Numbers / points / card data | Space Mono | 700 | 13–60px | |

### Spacing / Radius / Shadow
- Content max width: **1240px**, horizontal page padding **40px**.
- Section vertical padding: **56–88px**.
- Radii: buttons/chips **999px** (pill); cards **26px**; inner panels **22px**; small tiles **11–16px**.
- Border (light): `1px` or `1.5px` `rgba(44,39,51,.08–.16)`.
- Shadows (soft, no hard offsets):
  - Card rest: `0 12px 30px rgba(44,39,51,.07)`
  - Card hover: `0 20px 40px rgba(44,39,51,.12)`
  - Primary button (coral): `0 12px 28px rgba(255,122,89,.42)`
  - Floating dock: `0 16px 40px rgba(44,39,51,.20)`

---

## Screens / Views
Single scrolling page, ~7 stacked sections plus a fixed dock. Each section is tagged `data-screen-label` in the source.

### 1. Nav (sticky)
- **Layout**: sticky top, `justify-content:space-between`, 16px×40px padding, `backdrop-filter:blur(14px)`, translucent paper bg, 1px bottom border.
- **Left**: 40px rounded-14px coral tile with a white ring glyph + wordmark "ORBIT" (Fredoka 600, 24px).
- **Center**: text links — Activities, Locations, Plan a visit, Rewards (Hanken 500, 16px).
- **Right**: "Log in" (text button) · "＋ Top up" (outlined pill, hover → coral) · "Book a visit" (coral pill, primary).

### 2. Hero
- **Layout**: 2-col grid `1.02fr .98fr`, 52px gap, 60/76px vertical padding.
- **Left**: pill eyebrow badge ("FAMILY FUN · POWERED BY SAPIENSCORE" with green dot) → H1 "More smiles per visit." → 20px body paragraph → two CTAs ("Book a visit" coral primary, "Get your free card" outlined) → social-proof row (overlapping avatar circles ending in "+50k", plus "4.9★ from 50,000+ happy families").
- **Right**: a composed cluster on a 1500px perspective:
  - **Family photo placeholder** (top-left, 66%×74%, radius 28px) — diagonal-striped bg with mono caption "family photo · bowling". *Replace with a real lifestyle photo.*
  - **Floating "+50 points" chip** (top-right, white, soft shadow, gentle float animation).
  - **Loyalty card** (bottom-right) — see Loyalty Card component below.

### 3. Welcome / trust band (static)
- Full-width warm-white strip, centered row of 4 items with small colored rounded-icon tiles: Birthday parties 🎂, All ages welcome 🧒, Family café ☕, Free parking 🅿️. No motion.

### 4. Reservation highlight (`#reserve`) — PRIORITY
- Large gradient card (radius 32px, soft shadow), 2-col grid.
- **Left**: eyebrow "// PLAN AHEAD" → H2 "Reserve your spot in seconds" → supporting copy.
- **Right (booking widget)** on white inner card:
  - "When are you visiting?" → 4 day chips (Today / Tomorrow / Saturday / Sunday). One is selected (coral fill, white text); others white with light border. Clicking selects (single-select).
  - "How many?" → stepper: `−` button, mono count (default **4**), `＋` button. Min 1.
  - Full-width coral "Check availability →" button.

### 5. Activities grid (`#activities`)
- Centered heading block, then **3-col grid**, 22px gap, of **6 cards** (warm-white, radius 26px, soft shadow).
- Each card: 56px rounded-16px colored icon tile (emoji placeholder) → Fredoka title → 15px description → mono age tag ("AGES 3+", "ALL AGES", etc.).
- Cards cycle accent colors c1/c3/c2/c4/c3/c1.
- **Hover**: `translateY(-5px)` + deeper shadow.
- Content: Trampolines (AGES 3+), Bowling (ALL AGES), Arcade (ALL AGES), Go-Karts (AGES 8+), Climbing (AGES 5+), Laser Tag (AGES 6+).

### 6. How rewards work + Top-up (`#rewards`)
- **Dark section** (`--ink` bg, cream text), 80px padding.
- Centered heading "Your card does the work".
- 3-col grid of numbered step cards (1 Tap in / 2 Top up & play / 3 Cash in rewards), each with a colored numbered tile.
- **Top-up widget** below: gradient panel, left copy "Add credit, keep the fun going", right three amount tiles — €10 (+100 pts), **€25 (+300 pts, "BEST" badge, pre-highlighted in sunshine)**, €50 (+700 pts). Non-selected tiles hover → sunshine fill.

### 7. Locations explorer (`#locations`)
- Heading row + "See all locations →" outlined pill.
- 2-col grid `1fr 1.15fr`:
  - **Left = stylized map** (radius 26px, cream bg, dotted grid overlay, two soft translated bars). Four **teardrop pins** (`border-radius:50% 50% 50% 0; rotate(-45deg)`). First pin active (coral, larger). Caption "▲ TAP A PIN TO EXPLORE".
  - **Right = detail panel** (warm-white card): 150px gradient header with an "OPEN NOW · hours" badge → park name (Fredoka) + area/distance + rating chip → tag chips → "Book this park" (coral) + "Details" (outlined) buttons.
- **Behavior**: clicking a pin swaps the panel content (name, area, hours, rating, header gradient, tags) and moves the active/enlarged state to that pin. Data for 4 parks (Riverside, Northgate, Southside, Skyline) is in the logic class.

### 8. Stats band
- Full-width **sunshine (`--c2`)** bg, 4-col grid, centered. Mono numbers that **count up on mount**: 50k+ happy families, 12 parks, 8M points earned, 3s to check in.

### 9. Join CTA
- Centered: eyebrow "// COME PLAY" → big H2 "Your first 500 points are on us." → copy → "Create free account" (coral) + "Book a visit" (outlined).

### 10. Footer
- `--ink` bg. 4-col grid: brand blurb + 3 link columns (PLAY / MEMBERS / COMPANY). Bottom row: "© 2026 ORBIT Parks" and "POWERED BY SAPIENSCORE".

### Persistent action dock (fixed) — PRIORITY
- `position:fixed`, bottom-center, z-index 60, pill container (warm-white, radius 999px, strong soft shadow), slides up on load (`dockIn` animation).
- Contents: mini balance block (gradient chip + "2,480 pts / Gold family") | "＋ Top up" outlined pill | "Book a visit" coral pill.
- **Always visible** on every scroll position — this is the always-on nudge toward reservation + top-up.

---

## Interactions & Behavior
- **Loyalty card 3D tilt**: on `mousemove` within the hero, the card rotates toward the cursor (`rotateY` ±18° offset from −10° base, `rotateX` from +7° base). Resets to `rotateY(-10deg) rotateX(7deg)` on mouse leave. Container uses `perspective:1500px`; card uses `transform-style:preserve-3d`, transition `.2s ease-out`.
- **Loyalty card flip**: clicking the card flips it 180° on Y (`transition:transform .7s cubic-bezier(.4,.2,.2,1)`). Front = balance; back = QR block + member ID + next reward. Both faces `backface-visibility:hidden`; back pre-rotated 180°.
- **Reservation day chips**: single-select; selected = coral fill + white text.
- **Party stepper**: +/- integer, minimum 1, default 4.
- **Location pins**: click swaps detail panel + active pin styling (see section 7).
- **Stat counters**: animate 0→target over ~1s (interval ~28ms, ~38 steps) on mount.
- **Card/button hovers**: cards lift `translateY(-5px)`; primary buttons lift `translateY(-1 to -2px)` with deeper shadow; outlined buttons shift border to coral/ink.
- **Ambient motion**: two large blurred blobs drift slowly (`blobDrift`, 20s/26s). A "reduce motion" toggle sets `animation-play-state: paused` on all ambient/float animations and disables the tilt handler — respect `prefers-reduced-motion` in the real build.

## State Management
- `flipped: boolean` — loyalty card face.
- `party: number` (default 4, min 1) — reservation party size.
- `selectedDate: string` — reservation day chip.
- `activeLocation: index` (0–3) — locations explorer; drives the detail panel.
- `stat counters` — animated display values (ephemeral, on mount).
- **Theme**: `accent` (enum: Warm welcome / Sunset / Meadow) + `motion` (boolean). In production, model as a **skin/theme object** (brand name, 4 accent colors, logo, copy) injected at the app root so the same components render any tenant.
- **Real data hooks** (not implemented in the prototype): member balance/tier for nav + dock, live park hours/availability for locations + reservation, top-up amounts/pricing.

## Design Tokens summary (spacing scale)
Observed spacing multiples: 8 / 10 / 12 / 14 / 16 / 22 / 26 / 32 / 40 / 52 / 56–88px. Radii: 11, 14, 16, 22, 26, 28, 32, 999. Use an 8px-ish scale.

## Assets
- **No production images or icons** are included. Photo areas are **striped placeholders** with mono captions (e.g. "family photo · bowling") — replace with real lifestyle photography.
- **Icons** are emoji placeholders (🤸 🎳 🕹️ 🏎️ 🧗 🔫 🎂 🧒 ☕ 🅿️). Swap for a proper icon set (e.g. an SVG icon library) in production.
- **Brand mark** is a CSS shape (coral rounded tile + white ring). Replace with the real ORBIT logo when available.
- **Fonts**: Fredoka, Hanken Grotesk, Space Mono (Google Fonts).
- **QR / barcode** on the card back is a CSS grid placeholder — replace with a real member QR.

## Files
- `SapiensCore Home.dc.html` — the full homepage design reference (template markup + interaction logic in a `Component` class). All colors, copy, layout, and interactions described above live here.
