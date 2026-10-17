# Dynamic Pricing — Design (for sign-off)

Status: **design, not yet implemented.** This is the artifact to review before any code.
Companion: `/MEMBERSHIP.md` (a future, related feature — separate workstream).

---

> **Architecture revision (2026-06-25): built on the existing `rule` engine.** See §12.
> A dormant `rule`/`rule_condition`/`rule_action` scaffold already exists (empty tables, stub
> models, purpose-built for weekday/holiday/date-range conditions driving opening_time/pricing
> actions). Pricing rules are built by **finishing that engine**, not by adding a `pricing_rule`
> table. §5.4 (the original `pricing_rule` shape) is superseded by §12; everything else stands.

## 1. Goal

One composable price-resolution engine for SapiensCore. New pricing behaviours are added
as **configuration / new rule types on the same primitive**, never as special cases.
Hollywood Bowl is one driver, not the only one.

### The central distinction — two natures of rule

- **ABSOLUTE / deterministic** — *sets* the price. "Day/period/time changes → Game X **is** €4."
  Clock-driven, no live signal. (Periods, weekday/holiday schedules, time-of-day bands.)
- **RELATIVE / behavioural** — *modifies* the current resolved price, never sets an absolute.
  "Make it 50% cheaper than whatever it currently is." Reactive to a live signal
  (idle, occupancy, …) and **transient**. If base resolves to €10, a −50% rule yields €5, not €1.

These are stored separately (their columns diverge by nature) but composed by **one engine**.

---

## 2. Architecture

### 2.1 The engine is a pure resolver library

A directory of classes with **no I/O** — no DB, no network, no internal clock. Everything is
passed in; everything comes out:

**Input bundle**
- Definitions: absolute prices (period/weekday/holiday/time-band schedules), behavioural
  `pricing_rule`s, **expanded** institutional-cluster membership, guardrails, identity-modifier
  config (tier today, membership later).
- Signals: clock, per-gameLocation idle/occupancy, last-transaction marker.
- Current `pricing_rule_state` (for transience + anti-thrash).

**Output bundle**
- Resolved price slice (per gameLocation, incl. the tier display rows).
- The ordered **trace** (which rule fired, before→after, why).
- `pricing_change_event`s (runtime audit).
- New `pricing_rule_state`.

Because it is pure, the **same classes** serve three callers with no algorithm change:
1. **Live** resolution (scheduled ticks).
2. **Dry-run preview** (hypothetical rule, no side effects).
3. **Historical replay** ("run this rule as if last Tuesday on Location X").

### 2.2 Propagation is a separate, environment-specific adapter

The engine never pushes. What to *do* with the output is an adapter:

- **Edge adapter (target primary, already exists today):** merge the computed price slice into
  the local PaymentTerminal config → `computeConfigHash` compare → if changed and terminal
  online, send the **handshake** command → terminal HTTP-downloads the config → applied
  instantly, no restart; offline terminals self-request handshake on reconnect. 77 NUCs each
  run the identical engine over their own terminals; seconds end-to-end.
- **Core adapter:** the existing outbound sync to the NUC (online-only shops, no-NUC future,
  and preview).

### 2.3 Phasing

- **Phase 1 — CORE ONLY.** Preview and historical replay both need the engine in core anyway,
  so we validate the algorithm + data model + event log centrally first.
- **Phase 2 — EDGE.** Drop the same engine onto sapiensclient/NUC, riding the offline-first
  transaction port. Edge becomes primary, core the fallback. Zero algorithm change.

The PaymentTerminal config gains **two authors** once Phase 2 lands: core owns the static/design
template; the edge engine owns the dynamic price slice and merges it into the template before
hashing (hash over the merged result). That merge is the only new edge plumbing.

---

## 3. Resolution pipeline (fixed order, fully traceable)

For one gameLocation at moment *D* (an *operating-day* moment — see §5.3):

```
base price (GamePrice, no schedule overlay)
  → ABSOLUTE   period context → day resolution (specific-date exception > holiday/holiday-eve > weekday) → time-of-day band
  → RELATIVE   active pricing_rule effects, in priority order (transience + anti-thrash)
  → MODIFIER   identity modifiers — tier today (boolean "applies?"), membership later
  → GUARDRAIL  clamp to floor/ceiling
  → OVERRIDE   manual override wins; logged
```

Every step appends `{ layer, ruleId, ruleName, before, after, reason }`. The latest trace per
gameLocation is persisted (answers "why is this price now?").

---

## 4. Scope selectors — dumb "which", aligned with PaymentTerminal

Scope = *which gameLocations a rule touches*. It **never implies a price**. Aligned with
`PaymentTerminalConfig`'s `action` + `id_action` (+ `owner`) pattern, general → specific,
**most-specific wins**.

| Selector | Resolves via |
|---|---|
| `SELECTOR_OWNER` | owner |
| `SELECTOR_LOCATION` | `id_location` |
| `SELECTOR_GAME` | `id_game` |
| `SELECTOR_GAME_LOCATION` | `id_game_location` |
| `SELECTOR_TAG` | existing `tag` + `tag_relation` (games) |
| `SELECTOR_CLUSTER` | institutional cluster (live membership) — **institutional only** |

Specificity ranking for absolute conflicts: `owner < cluster < location < game < tag < game_location`.

---

## 5. Data model

### 5.1 Clusters (new — location grouping)

> **Superseded as source of truth by `/CLUSTERS.md`** — the cluster design has been
> extended beyond pricing (`cluster:N` token in `listLocationCountry`, AUTOMATIC partition
> invariant + sync split, profile-tab personal clusters). This section remains the
> pricing-scope view; on conflict, `CLUSTERS.md` wins.

`cluster` ( `id_cluster`, `owner`, `id_user` nullable, `name`, `type`, `visibility`, `status`,
`detail` ) + membership `cluster_location` ( `id_cluster`, `id_location`, `status` ).

| Type | Membership | Visible to | Settings-usable? | Reference semantics |
|---|---|---|---|---|
| `AUTOMATIC` (sys) | location ∈ ≤1 | **Sys only** | No — "groups of sync" (NUC sync batching, design later) | n/a |
| `INSTITUTIONAL` | location ∈ ≤1 per owner; **flat** (no nesting) | owner's users | **Yes — only type** | **by-reference (live)** |
| `PERSONAL` | unlimited, overlapping; `public`/`private` | creator; or all same-owner users if `public` | No — reports / rapid pick | **by-value (snapshot)** |

- **By-reference (institutional):** a rule stores `SELECTOR_CLUSTER + id_cluster`; the engine
  expands membership **live** every resolve. Add/remove a shop tomorrow → it gains/loses the rule.
- **By-value (personal):** the **UI explodes** the cluster into individual `SELECTOR_LOCATION`
  rows at selection time. The rule never references the personal cluster; later edits don't
  propagate. "You are not selecting the cluster."
- **No membership enforcement.** But the location detail page conditionally shows
  in-cluster / not-in-cluster **only when the owner has ≥1 institutional membership anywhere**
  (derived per-owner "uses clusters?" flag). Nudge, not constraint.

### 5.2 Absolute store — `GamePrice` + period + schedule

The deterministic price keeps riding the existing **`GamePrice` versioning** (the audit trail:
`price_uuid` + `version` + `valid_from`/`valid_to` + `status`; scope GAME / GLD / GAMELOCATION;
multi-line via `sort_order`/`is_primary`).

Extensions:
- Add nullable **`id_period`** to `game_price` (precedent: `activity_package.id_period`). A
  period-scoped price is a versioned `GamePrice` row with `id_period` set. Per-location date
  overrides come from the existing `PeriodLocation` (`use_custom_date`/`from_date`/`to_date`)
  resolved by `ReservationPeriodManager::getPeriodLocation($idLocation, $date)`.
- **Weekday / holiday / holiday-eve / time-band schedule** lives in its **own table**, mirroring
  `location_opening_hour_default` (keyed by scope entity + `day_of_week` + holiday flags +
  `id_period`). **Not** in `PeriodLocation.detail` (already overloaded).
- **Specific-date exceptions** (see §5.3a) live in a calendar-keyed table, evaluated as the
  most-specific day tier — they overlay on top of the active period, they do **not** replace it.

**Schedule shape (see §5.3 for time bands):**
- Mandatory minimum is a single **always-on price** per day-type ("Monday €5, period").
- An optional flag enables **time bands**.

Absolute resolution order: scope (GL→GLD→Game) → period → day resolution
(**specific-date exception > holiday / holiday-eve > weekday**) → time-of-day band.
All-or-nothing per scope level (as today).

### 5.3 Time-of-day bands — `from` mandatory, `to` optional, default fallback

- Each day-type has one **always-on default price** (mandatory). E.g. Monday €4.
- Optional **bands**, each `{ from (required), to (optional), price }`:
  - `from 16:00 → €5` (no `to`) — €5 from 16:00 until operating-day close.
  - `from 16:00 to 17:00 → €3` — €3 only in that window; outside it the price falls back to the
    **day default** (so after 17:00 it's €4 again). A happy hour in one line.
- Resolution: the band covering `now` wins; **if no band covers `now`, use the day default**
  (not "the previous band" — uncovered time always reverts to default).
- Bands within a day are **non-overlapping** (validated at save), same as opening-hours `listHour`.
  Overlap, if ever allowed later, would need an explicit precedence rule — V1 forbids it.
- **"Close" = the operating day, which rolls into the next morning** (consistent with how opening
  hours treat close). The engine keys on the operating day, not the calendar day, so an open-ended
  evening band carries past midnight.
- The ~1-min deterministic tick catches band edges (e.g. 16:00, 17:00) with no extra machinery.

### 5.3a Specific-date exceptions — a shared "Special Day" entity

The gap that period / holiday-category / weekday don't cover: **one exact calendar date with its
own value** ("Dec 24 close at 14:00", "anniversary day cheaper games"). Your "price is Y, period"
case — it overrides everything for that day.

**This is NOT pricing-owned.** A Special Day is a cross-subsystem calendar entry that several
subsystems read: opening hours, reservation/activity availability (yes/no per location — the
existing division), and pricing. Pricing is one consumer — the same relationship pricing and
opening hours have with `Period`.

- **Ownership sits outside the pricing build.** Candidate: **generalise the existing holiday
  definition** (already a per-date, per-scope calendar entry) so it can carry more than a category
  flag — optional hours override, reservation-availability, and (later) price overrides. One
  calendar entry; subsystems hang their settings off it. This is a cross-cutting decision (touches
  opening hours + reservations), to be made with those subsystems, not unilaterally here.
- **Generalises holiday definitions.** Holiday = a *category* stamped on dates; a Special Day =
  *specific values* for one date.
- **Not a 1-day Period.** Periods are validated non-overlapping (`PeriodLocation::validateNoOverlap`),
  so a 1-day period couldn't coexist with a season it falls inside — and operators shouldn't have to
  name/manage a Period per one-off date. It's a calendar exception, not a window.

**Pricing's part (a deferred consumer):**
- The engine resolves a **date-keyed absolute price as the most-specific day tier** — wins over
  holiday/holiday-eve and weekday, **overlays the active period (does not replace it)**, same band
  shape as §5.3. This resolution support is cheap and lands with the engine.
- The price override is **per game group, not a flat day price.** "Games at €4 → €1, games at €5 →
  €2" is ordinary absolute price-setting scoped per group, keyed to the date — **not a new
  mechanism.** The "select by current price / tag / cluster → remap" is an **authoring action**,
  i.e. the Vue impact screen (§6) with a filter + bulk set. So the realistic case is in the model
  already; only the selection/bulk-remap tooling is built iteratively, on customer need.
- **Phasing:** the Special Day can ship first with hours + reservation-availability; pricing folds
  in later as another consumer with no engine rework (the date-keyed resolution already exists).

### 5.4 Behavioural store — `pricing_rule`

`pricing_rule` ( `id_pricing_rule`, `owner`, `name`, `status`, `priority`,
`id_scope_selector_set`, `condition` JSON, `effect` JSON, `transience` JSON, `applies_tier`
bool, `detail` JSON ).

- **`condition` (pluggable `type`)** — V1: `idle_offpeak` (idle threshold + off-peak gate as a
  time window). Future types (weather, occupancy surge, member-only, multi-condition chains) are
  new `type` values — **no schema change**.
- **`effect` (pluggable `type`)** — relative only: `multiply` (×0.5), `delta` (−1.00), `visual`
  (badge/colour). Never `set`.
- **`transience`** — `revertAfterMinutes`, `revertOnTransaction`, `minDwellSeconds`,
  `cooldownSeconds` (anti-thrash, non-optional given a multi-minute tick).
- **`applies_tier`** — see §5.5.

**Runtime state** `pricing_rule_state` per `(id_pricing_rule, id_game_location)`:
`firedAt`, `lastChangeAt`, `active`, `cooldownUntil`. Edge-held; the thing that makes transience
and anti-thrash survive across ticks.

### 5.5 Identity-modifier layer — tier now, membership later

- **Tier (now):** a single boolean per rule/price — "does tier apply?". If yes, the engine's
  output price is handed to the existing tier %-discount path (maps to today's `allowTierRule`
  gate); the terminal already displays the tiered rows (base + VIP + Platinum), so it's not a
  surprise. This also lets us retire the hardcoded `×0.90` display placeholders by computing the
  rows from real `LoyaltyTier` discounts.
- **Membership (future):** the same shape — an identity modifier applied at transaction by the
  card-holder's identity, with operator-controlled per-modifier applicability ("applies to
  deterministic? to behavioural?"), decided per membership. The engine must **not** assume tier
  is the only identity modifier. See `/MEMBERSHIP.md`.

### 5.6 Guardrails — `pricing_guardrail`, enforced twice

Floor/ceiling scoped Game → Location → gameLocation (most-specific wins).
- **Save-time** (margin protection from human error): reject a manual `GamePrice` version or
  override outside `[floor, ceiling]`.
- **Resolve-time**: clamp the computed price into `[floor, ceiling]`.

### 5.7 Override

Highest-priority absolute, one operator action, logged to price history (modelled as a flagged
`GamePrice` version so it inherits the audit trail). Wins over the relative layer. Clamp-on-override:
default **still clamped** (save-time already blocks bad entry); an explicit "force" could bypass
with a louder audit entry.

### 5.8 Runtime audit — `pricing_change_event`

**Separate** from `GamePrice` versioning. GamePrice versions audit *definition* changes (an
operator). `pricing_change_event` audits *runtime* changes (the engine):
`id_game_location` / `id_game` / `id_location`, `id_pricing_rule` (null = deterministic),
`layer`, `price_before`, `price_after`, **trigger snapshot** (idle duration, occupancy, off-peak),
`fired_at`, `reverted_at`. Reverts are events too. Edge-written, **batch-synced (~X min, not
realtime)** to core. Joined with transactions/revenue to measure uplift; doubles as the persisted
"why is this price now?" trace.

---

## 6. Simulation / preview

The Vue impact screen and historical replay both call the pure engine.

- **Dry-run preview:** resolve a draft rule's scope → affected gameLocations, before→after prices,
  counts, locations. No persist, no push.
- **Historical replay:** feed historical signals → "run this rule as if last Tuesday on Location X".
- **Headline output is frequency, not just price delta.** Replay reports **how many times the rule
  would have fired and how much of the (operating) day it would have been live** — the guard
  against runaway rules ("idle 60s" firing a million times/day) and the direct readout of whether
  `minDwell`/`cooldown` are tuned right.
- **Note:** replay fidelity is bounded by retained signal history. Transactions exist; fine-grained
  idle/occupancy needs telemetry retention (decide what to persist — not a V1 blocker).

---

## 7. Real-time application

- Deterministic ~1-min tick + behavioural ~5-min tick = the engine called on schedule, output
  handed to the propagation adapter.
- Hash-dedup (`computeConfigHash` / last-config compare) means a tick that changes nothing pushes
  nothing.
- `revertOnTransaction` hooks the transaction path to clear `pricing_rule_state` → re-resolve → push.
- No daemon-core price path (daemon-core is monitoring only); price uses the PT config sync +
  handshake that exists today.

---

## 8. Frontend

- **API-first.** JSON endpoints on the domain controllers (`routesAdminApi.php`), the v2 response
  envelope.
- **Vue island** for the interactive core (rule builder, live scope resolution, impact/replay) —
  a legitimate second island after Trace, which is the reference (`islands/trace/`). Simple CRUD
  (periods, guardrails, cluster membership) can stay Alpine + htmx where it doesn't need Vue.

---

## 9. V1 scope vs deferred

**V1:** resolution engine + absolute (period + weekday/holiday/holiday-eve + date-keyed Special-Day
resolution + open-ended time bands)
+ relative layer + tier boolean + guardrails (two-point) + Period scheduling + ONE behavioural
trigger (idle + off-peak → relative discount + visual, revert on next transaction) + the trace +
clusters (3 types, by-ref/by-value) + tag/cluster scoping + `pricing_change_event` audit + the Vue
preview/impact + historical replay. Core-only execution.

**Deferred (must be expressible on the same primitive, not built now):** edge execution (Phase 2),
weather, occupancy/demand surge, membership, card-only/member-exclusive dynamic pricing,
multi-condition chains, automatic-cluster sync grouping.

---

## 10. Open / later

- Exact entry UX for sparse time bands (§5.3).
- Shared **Special Day** entity (§5.3a): ownership/generalisation of the holiday definition to carry
  hours + reservation-availability + pricing — a cross-subsystem decision. Ship hours + reservation
  first; pricing folds in as a consumer. Bulk "select-by-current-price → remap" authoring UX is
  built iteratively on customer need.
- Telemetry retention for high-fidelity historical replay (§6).
- Automatic-cluster "groups of sync" semantics (§5.1).
- Clamp-on-override "force" affordance (§5.7).

---

## 11. Cross-repo (sapiensclient) + project-rule conformance

### 11.1 sapiensclient touchpoints (small, pattern-following)

- **Engine port = fungible copy, not a fork** (CLAUDE.md cross-project sync). The engine is I/O-free
  precisely so Phase 2 is a copy of the same classes, kept identical across repos.
- **Phase 1 needs ~no client pricing change.** Core runs the engine; the resolved price reaches
  devices over the **existing PT-config sync + handshake** (the `buildPriceData` path). New client
  code only lands with the Phase 2 edge engine.
- **Special Day** mirrors the existing **Period sync** — `Outbound…Manager` (core) → `Inbound…Manager`
  + model field (client), same shape as `SyncPeriod`/`SyncPeriodLocation`. Built with the
  holiday-definition owner, not unilaterally.
- **Clusters stay core-side.** A NUC is one location; the edge receives rules already resolved to its
  own gameLocations, so no cluster model on the client.
- Any shared v2 utilities (list.js, Vue island helpers) stay identical across repos — port, don't fork.

### 11.2 Conformance to CLAUDE.md

- **Layering:** controllers are passing-points (parse → `PricingManager` / engine Service → Response,
  no logic, no SQL, no shape transform). Business logic in Managers/Services; the resolver is a Service
  library. Models own their array shape (`getStoreArray()`); static finders `getListByX`/`getOneByX`.
- **Persistence:** AutoDb/AutoRecord only, never raw SQL; `create()` + `->store()`. No denormalised
  `*_by_name` columns — store ids, render via `Cache`. Constants named, never hard-coded.
- **Naming:** `idGame`/`idLocation`/`idPricingRule`, `listX` (incl. JSON keys); method names are the
  action (`list`/`one`/`update`/`create`/`delete`/`renderEditForm`) with **no `api` prefix**. Tables
  snake_case singular, PK `id_<table>`, FK `id_<ref>`.
- **API:** locked v2 envelope — reads return the plain payload; writes return `{status, id, row}`
  with `row` server-rendered via `_row.phtml`; errors `{status:'error', errors:{…}}`. No
  `ReturnHandlerBuilder`. Human messages through `T::t()`.
- **Frontend:** this is the **sanctioned second Vue island** after Trace (explicit decision, per the
  "new islands require a deliberate call" rule); single-Bootstrap rule respected (no `tabler.min.js`
  alongside `bootstrap`); no jQuery; state in Alpine stores / Vue provide-inject, not `window`; row
  HTML always from a server `_row.phtml`; no DataTables; v2 folder layout under
  `templates/adminlte/v2/…` and `public/assets/adminlte/v2/…`.
- **PHP style:** `==` for DB-int / JSON-transited values, `===` only for bool sentinels; no inline
  `\App\…` FQNs (use statements + short names); `foreach` over arrow-fn `array_map`; blank line before
  `return`; braces never `endif`/`endforeach`; comments only when the WHY is non-obvious; no emojis;
  no back-compat shims/flags; don't widen scope.

---

## 12. Architecture revision — built on the existing `rule` engine

Supersedes §5.4. A dormant scaffold already exists and is reused:

- `rule` ( id_rule, owner, name, description, **priority**, status ) — the named rule container.
- `rule_condition` ( id_rule, **condition_type**, **condition_value** JSONB, condition_operator, status ) — the WHEN.
- `rule_action` ( id_rule, id_rule_condition?, **action**, id_action, **detail** JSONB, status ) — the WHAT/WHERE.

All three are AutoRecord stubs (status placeholder `__your_status__`, no constants, only `getMoreWhere`,
referenced by nothing). We finish them.

### 12.1 Nature lives in the action, not a second table
The two natures stay distinct as two **action types** rather than two rule tables:
- `ACTION_GAME_PRICE_SET` (absolute / deterministic — *sets* the price)
- `ACTION_GAME_PRICE_MODIFIER` (relative / behavioural — *modifies* the current price, never sets)

So a rule's nature is queryable from `rule_action.action`. `GamePrice` remains the versioned, audited
**price-value** store; an absolute action references/copies a price, a relative action carries a factor.
(Reserved future actions: `ACTION_OPENING_TIME`, `ACTION_ACTIVITY_PACKAGE` — the shared scheduling reuse.)

### 12.2 Condition vocabulary (`condition_type`)
Absolute (V1): `WEEKDAY`, `DATE_RANGE` (period: `condition_value.idPeriod` or `{from,to}`), `HOLIDAY`,
`HOLIDAY_EVE`, `SPECIFIC_DATE` (Special Day), `TIME_BAND` (`{from, to?}`, `to` optional = until
operating-day close). Behavioural (P3, reserved): `IDLE`, `OFF_PEAK`. `condition_operator` reserved for
negation / ANY-vs-ALL chaining (the deferred multi-condition chains); V1 rules are single-condition, AND-ed.

Resolution precedence within the absolute layer is unchanged (§3): period context → specific-date >
holiday/holiday-eve > weekday → time band, on top of the GamePrice base.

### 12.3 Scope lives in `rule_action.detail` (the one new modelling call)
`rule_action` has a single `id_action`, but pricing scope is multi-target. So scope is carried in the
action's JSONB `detail` as a **selector list** — the dumb selectors from §4:
`detail.scope = [ {type: 'game'|'location'|'gameLocation'|'tag'|'cluster', id} ]`, plus the effect
(`detail.effect = {type:'set'|'multiply', amount?|factor?}`), optional `detail.bands`, `detail.applyTier`,
`detail.visual`. Scope stays logically orthogonal (data the resolver expands to a gameLocation set), even
though it physically sits in the action JSONB. `id_action` is unused for pricing in V1 (kept 0); indexed
scope columns are a later optimisation if query patterns demand it. For V1 (core-only), the input-gathering
loads an owner's active rules and expands their scope in PHP before handing candidates to the pure engine.

### 12.4 What stays unchanged
GamePrice base + versioning (audit), guardrails (`pricing_guardrail`, two-point), the `pricing_change_event`
runtime audit, the pure engine + trace, the Vue preview/replay, clusters, and the propagation adapters are
all unchanged. Only the rule **storage** moves from a new `pricing_rule` onto the finished `rule` engine.

### 12.5 Period via condition, not `id_period` on `game_price` (supersedes §5.2)
Because overrides now live in rules, **period pricing is a `DATE_RANGE` condition**, not a
period-scoped `GamePrice` row — so `game_price` gains **no `id_period` column**. `GamePrice` stays the
pure **base/value** store; every override (period / weekday / holiday / specific-date / time-band) is a
rule whose SET amount lives in `rule_action.detail.effect.amount`. Override changes are audited by the
rule's standard created/modified columns plus the `pricing_change_event` runtime log; `GamePrice`
versioning continues to audit the base. Per-location period date overrides still come from the existing
`PeriodLocation` resolver, referenced by the `DATE_RANGE` condition's `condition_value.idPeriod`.

### 12.6 Absolute precedence + condition status (implemented)
The winning absolute rule is chosen by, in order: **day specificity** → **time-band** → **rule priority**
→ **newest rule**. Day specificity ranks: specific-date (4) > holiday/holiday-eve (3) > weekday (2) >
date-range/period (1) > none (0). So **period is the seasonal baseline and weekday/holiday/date refine
on top of it** (a "Monday €4" overrides "Summer €8" on summer Mondays); a matching **time-band beats the
whole-day** rule of equal day-rank (happy hour within the day). All resolution stays in the pure engine.

Condition matching implemented: `WEEKDAY`, `SPECIFIC_DATE`, `HOLIDAY`, `HOLIDAY_EVE`,
`DATE_RANGE` (explicit `{from,to}` dates), `TIME_BAND` (`{from, to?}`, `to` empty = until close,
`from > to` wraps midnight). **`DATE_RANGE` by named Period (`condition_value.idPeriod`) with
`PeriodLocation` per-location date overrides is a follow-up** — the explicit-dates form ships first.

### 12.7 Effect type is independent of trigger (refines §12.1)
A rule_action's effect is `{type: 'set'|'percent'|'delta', value}` — set a fixed price, take a
percentage off, or a fixed amount off. **The effect is independent of the trigger:** a scheduled
percentage ("Mon 12–14 −50%") is a clock-condition rule with a PERCENT effect, not a behavioural one.
So the deterministic vs behavioural **nature comes from the conditions** (clock vs signal), not the
action. `rule_action.action` still records SET vs MODIFIER (derived from effect.type) for queryability.
Absolute resolution is two passes over the matching rules: the most-specific **SET** establishes the
price, then the most-specific **PERCENT/DELTA** adjusts it (base €10 → set €4 → −50% → €2). Scope is a
**list** of selectors (`detail.scope = [{type,id,label}]`) — one rule targets many games/locations/tags.
