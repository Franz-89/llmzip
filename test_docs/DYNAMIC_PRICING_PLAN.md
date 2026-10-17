# Dynamic Pricing — Phased Implementation Plan

Status: **in progress.** Companion to `/DYNAMIC_PRICING.md`.

> **Note (2026-06-25):** pricing rules are built on the existing `rule`/`rule_condition`/`rule_action`
> engine (see design §12), not a new `pricing_rule` table. P1's absolute scheduling and P3's
> behavioural rules are both `rule` rows distinguished by `rule_action.action`. P0 is **done**
> (engine boundary + parity, signed off). P1 is underway.

## Principles

- **Vertical slices.** Each phase ships something usable and is independently testable.
- **Lowest novelty first.** Extend the audited `GamePrice` before building the novel behavioural
  + edge machinery.
- **Parity-first (strangler).** Route today's price resolution through the new engine and prove
  identical output *before* layering any new behaviour.
- **Core-only until Phase 5.** Edge execution is the last phase, riding the offline-first
  transaction port.
- **Every phase respects CLAUDE.md** (§11.2 of the design): controllers as passing-points, logic in
  `PricingManager` / engine Services, AutoDb-only, `idX`/`listX` naming, locked `{status,id,row}`
  envelope, `T::t()`, single-Bootstrap, no parallel routes/methods/flags.

Dependency spine: **P0 engine boundary → P1 deterministic → P2 clusters → P3 behavioural →
P4 preview/replay → P5 edge.** P1 is the big standalone value drop; P3 is the novel risk; P5 is scale.

---

## Phase 0 — Engine boundary + parity (invisible)

**Goal:** establish the pure resolver and prove it reproduces current prices exactly.

- **Engine library** (a directory of pure, I/O-free classes): input/output DTOs, the ordered
  **trace** structure, and a pipeline that today only runs `base → (clamp no-op)`.
- Wire `GameLocation::buildPriceData()` / PT-config building to resolve **through** the engine.
- `pricing_guardrail` table created but dormant (no floors/ceilings set yet).

**Exit criteria:** for a representative sample of gameLocations (arcade, attended multi-line,
selector, kiosk), engine output == current `buildPriceData` output; trace shows base layer only.
Zero behaviour change in production.

**Risk:** low. **sapiensclient:** none. **Value:** de-risks the core architectural bet cheaply.

---

## Phase 1 — Deterministic pricing (the big absolute slice)

**Goal:** time-driven pricing live — seasonal (period), weekday/holiday/holiday-eve, happy-hour
bands, and Special-Day date overrides — plus guardrails and the audit foundation.

- **Data:** add nullable `id_period` to `game_price`; new **price-schedule table** (scope entity +
  `day_of_week` + holiday/holiday-eve flags + `id_period`, carrying default price + optional
  `from`/`to` bands), mirroring `location_opening_hour_default`. Date-keyed **Special-Day price
  resolution** (consume the shared entity; if not ready, a minimal interim date-keyed price table —
  coordinate ownership with the holiday-definition generalisation, see design §5.3a).
- **Engine:** absolute layer — scope (GL→GLD→Game) → period (per-location dates via `PeriodLocation`)
  → day resolution (date exception > holiday/holiday-eve > weekday) → time band. Operating-day
  handling (close rolls to next morning).
- **Scope-selector framework** introduced here (selector set model + `SELECTOR_OWNER/LOCATION/GAME/
  GAME_LOCATION/TAG` resolution). Cluster selector added in P2.
- **Guardrails:** save-time reject (out-of-range manual price) + resolve-time clamp (now meaningful).
- **Propagation:** ~1-min **deterministic tick** (CommandManager cron, like `SyncPeriod`) →
  re-resolve → push via the **existing PT-config sync + handshake**, hash-deduped.
- **Audit:** minimal `pricing_change_event` (layer=deterministic, before/after) — audit starts the
  moment prices change automatically.
- **Tier integration (folds in here):** the `applies_tier` boolean path; retire the hardcoded
  `×0.90`; build Standard/VIP/Platinum display rows from real `LoyaltyTier` discounts.
- **UI (Alpine + htmx):** CRUD for price schedules, period-pricing, guardrails — v2 list-page playbook.

**Exit criteria:** an operator can set "Mon €4, from 16:00 €5", a seasonal period price with a
per-location end-date, and a one-off Special-Day price; the tick pushes changes to terminals within
~1 min; out-of-range saves are rejected and computed prices are clamped; every automatic change is
logged.

**Risk:** medium (new tables + cron, but built on existing price history). **sapiensclient:** none
for pricing (rides existing config sync); Special-Day *sync* only if the shared entity needs it.

---

## Phase 2 — Clusters (scoping primitive)

**Goal:** fast multi-location scoping, reusable beyond pricing.

- **Data:** `cluster` + `cluster_location`. Types `AUTOMATIC` (sys, ≤1, sync-grouping — reserved),
  `INSTITUTIONAL` (≤1/owner, flat, settings-usable, **by-reference**), `PERSONAL` (overlapping,
  `public`/`private`, **by-value**).
- **Resolution:** `SELECTOR_CLUSTER` (institutional) expands membership **live**; personal clusters
  are **exploded into `SELECTOR_LOCATION` rows in the UI** at selection time (never referenced).
- **UI:** cluster CRUD + membership; on the **location detail page**, conditionally show
  in-cluster/not-in-cluster only when the owner has ≥1 institutional membership (no enforcement).

**Exit criteria:** a rule/override scoped to an institutional cluster follows live membership
changes; a personal cluster used in the picker stores literal locations and ignores later edits;
location detail shows the membership nudge only when relevant.

**Risk:** low–medium (self-contained). **sapiensclient:** none (clusters stay core-side).

---

## Phase 3 — Behavioural layer (the novel reactive slice)

**Goal:** the first behavioural rule — idle + off-peak → relative discount + visual, reverting on
next transaction.

- **Data:** `pricing_rule` (scope selector set, `condition` JSON [`idle_offpeak`], `effect` JSON
  [`multiply`/`visual`], `transience` JSON, `applies_tier`) + `pricing_rule_state`
  (`firedAt`/`active`/`cooldownUntil`) per (rule, gameLocation).
- **Engine:** relative layer applied on top of the deterministic price (never sets absolute);
  clamped by guardrails; trace records the relative step.
- **Transience + anti-thrash:** `minDwellSeconds`, `cooldownSeconds`, `revertAfterMinutes`,
  `revertOnTransaction`.
- **Propagation:** ~5-min **behavioural tick**; revert-on-transaction hook clears state →
  re-resolve → push. Same hash-deduped config sync.
- **Audit:** enrich `pricing_change_event` with **trigger snapshots** (idle duration, off-peak).
- **Safeguard:** a basic dry-run scope resolution (count + before→after) before a rule can be
  activated — the rich Vue version lands in P4.
- **UI (Alpine + htmx):** rule CRUD.

**Exit criteria:** an idle off-peak rule fires on the tick, applies a relative discount + visual,
holds through a brief signal dip (dwell), doesn't re-fire during cooldown, reverts on the next
transaction, never produces a price below floor, and logs every change with its trigger snapshot.

**Risk:** high (the novel part — transience + anti-thrash + signal handling). **sapiensclient:** none
yet (core engine).

---

## Phase 4 — Vue preview / impact + historical replay

**Goal:** operators preview and simulate before applying — the trust + runaway-rule guard.

- **Vue island** (sanctioned 2nd after Trace; reference `islands/trace/`): live scope resolution
  (how many games, where, before→after), dry-run a draft rule with no side effects.
- **Historical replay:** feed historical signals → **fire-frequency + active-coverage** per
  gameLocation (catches "idle 60s → fires a million times/day"); confirms `minDwell`/`cooldown`
  tuning.
- **API-first** JSON endpoints feeding the island.

**Exit criteria:** a draft rule shows its affected set and price deltas without persisting; a replay
reports how many times it would have fired and what fraction of the operating day it would have been
live, over a chosen historic window/location.

**Risk:** medium (depends on retained signal history — note in design §6). **sapiensclient:** none.

---

## Phase 5 — Edge execution (scale + offline)

**Goal:** edge-primary, cloud-fallback; 77 NUCs / ~10K games running offline.

- **Port the pure engine to sapiensclient** — a fungible **copy**, not a fork (cross-project rule).
- **Sync down** rule/schedule/Special-Day definitions + per-NUC resolved rule scoping (clusters
  resolved core-side to gameLocations).
- **Edge propagation adapter:** merge the computed price slice into the core-supplied PT-config
  **template**, hash over the merge, handshake to local terminals (largely exists today).
- **Edge audit:** `pricing_change_event` written locally, **batch-synced up (~X min)**.
- **Config authority split:** core owns the static/design template; edge owns the dynamic price slice.
- Rides the offline-first transaction port; core remains full fallback for no-NUC / online-only shops.

**Exit criteria:** a NUC keeps applying scheduled + behavioural prices with no cloud connection;
changes reach local terminals in seconds via handshake; change events backfill to core on reconnect;
core and edge produce identical resolutions for the same inputs (the parity guarantee from P0).

**Risk:** high (distributed, offline, two-author config). **sapiensclient:** the main client work
lands here.

---

## Cross-cutting (every phase)

- **Parity tests** carried forward from P0 — each new layer must leave untouched cases unchanged.
- **Trace assertions** — the "why is this price now?" trace is verified per layer as it's added.
- **No scope creep** — Special-Day authoring bulk-remap UX, weather/occupancy/membership,
  multi-condition chains, automatic-cluster sync semantics stay **deferred** (design §9), expressible
  on the same primitives when their time comes.

## Suggested first move

Phase 0 is small, invisible, and de-risks everything. I'd start there: stand up the engine boundary
+ trace + parity test, no behaviour change. On your go, I'll create the task breakdown for Phase 0
and begin.
