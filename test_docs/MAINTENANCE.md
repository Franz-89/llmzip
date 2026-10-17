# Maintenance & tech-work model

**Audience:** agent implementing the maintenance / tech-work feature.
**One-line summary:** maintenance is **not** a new system. It splits across the two logs we already have — `game_location_operation` (routine, costless actions) and `Trace` (faults/repairs that carry parts + labor hours). The only new capability is **logged hours** on a Trace.

---

## 1. The decision rule (the whole design in one line)

> **Broken/fault, or has a cost/hours you want to account for → Trace.**
> **Routine, costless action → `game_location_operation` (GLO).**

The signal that flips it is **cost**. The moment there is money or repair-time worth recording, it belongs on a Trace. This keeps **one cost ledger** (Trace), so cost-per-machine and tech-time reports never have to union two tables.

### Worked examples

| Situation | Where | Why |
| --- | --- | --- |
| Changed the ticket paper | GLO (`REFILL_PAPER`) | routine, no cost |
| Cleaned / dusted the cabinet | GLO (`CLEAN`) | routine, no cost |
| Calibrated the acceptor | GLO (`CALIBRATE`) | routine, no cost |
| Swapped a PulseBox during a planned upgrade | GLO (`REPLACE_PULSE_BOX`) | routine, no fault |
| **Machine broken → replaced a board** | **Trace** | fault + part cost + labor hours |
| Acceptor jammed and was repaired | Trace | fault + labor hours |
| PulseBox **failed** and was swapped | Trace (scope PulseBox or game location) | fault + device cost |

The board-replacement case is the one that felt ambiguous. It is a **Trace**: something was broken (a fault) and there is a real cost. In practice the Trace usually **already exists** — someone reported the machine down — so the tech doesn't create anything new; he **logs the board cost + his hours on the existing Trace and resolves it**. A repair that finishes in one visit is still a repair. Only the rare "it broke while I was standing there, nobody reported it" case needs a fresh Trace (open → resolved in one shot).

### What we are explicitly NOT doing

- **No cost/hours on GLO.** Cost is the signal it's a Trace. Adding cost to GLO too would split reporting and re-introduce the "which log did the tech use?" ambiguity.
- **No new polymorphic maintenance table.** GLO + Trace already cover it.
- **No auto-orchestration for maintenance.** Escalation from a GLO note to a Trace stays **manual** (the existing `game_location_operation.id_trace` bridge). We are not auto-opening Traces for tech work.

---

## 2. Hours on a Trace (the only real new capability)

### Model

Hours are **labor lines** on the existing `trace_cost` table — `cost_type = TYPE_LABOR (3)`. We reuse everything (`create()`, `getListByTrace()`, the cost tab) and add exactly one column.

- **quantity** = hours worked (e.g. `2`, `0.5`) — indicative, round to the nearest 0.5h.
- **unit_cost** = **stays 0.** Labor lines carry **no rate**. The hourly cost is a reporting concern applied later, not stored here. So a labor line contributes **0 to the monetary cost total** — hours and money never get conflated.
- **worked_on** = date of the work (**new column**), defaulting to today, editable.
- **created_by** = the logged-in tech (already on `trace_cost`).
- Total Trace cost (parts + consumables + external) is unchanged; labor adds 0 to it. Hours are summed separately from `quantity` where `cost_type = LABOR`.

### Time-tracking UX — decided

A tech **never fills a timesheet**. When he adds his note / resolves, he types **one number** ("hours"). Everything else is a byproduct the system already knows:

- **WHO** = logged-in user → `created_by` (free, no input).
- **WHEN** = `worked_on`, defaults to today (free).
- **Multiple visits across days** = just more LABOR lines with different `worked_on` — a Trace already accumulates over time. Comes back tomorrow → another line dated tomorrow.

From that you derive, with no extra data entry:

- **Total hours** — `SUM(quantity) WHERE cost_type = LABOR`
- **Tech time** — group by `created_by`
- **Per-day** — group by `worked_on`

This is exactly the CMMS norm (one labor line per work-order session, attributed to the tech, entered after the fact, rounded) — without the timesheet friction, because attribution comes from the session + clock, not a form.

### Schema change

```
ALTER TABLE trace_cost ADD COLUMN worked_on date NULL;   -- set for LABOR lines
```
(shipped as `sqlinstall00383.sql`)

`TraceCost` (done):
- `getWorkedOn()` / `setWorkedOn(?string)`
- `create()` accepts `workedOn`, and `unitCost` now defaults to `0` (labor lines pass no rate)
- **no** rate constant — deliberately. The rate is applied in reporting, not stored.

### Presentation

Inside the existing cost tab, render a **"Work / Time"** subsection filtered to `cost_type = LABOR` (dated hour entries + labor subtotal), and keep parts/consumables/external in the main cost list. One table, two views. No new tab required.

---

## 3. Scope additions (for device-scoped Traces)

**Scoping principle:** a device that has no independent existence from a game (it's 1:1 with a game location) does **not** get its own scope — the fault is scoped to the **game location**, and the specific device is (eventually) an optional pointer within that scope. A device that is **location-wide** (independent of any one game) does get its own scope.

- **PulseBox → NO scope.** 1:1 with a game location. A pulsebox fault is a `SCOPE_GAME_LOCATION` trace; which device it is comes from the (future) device pointer — see §6.
- **DeviceCoolcode → `SCOPE_DEVICE_COOLCODE = 5`.** ✅ done. Location-wide (lobby/ticket station), independent entity.
- **PaymentTerminal → keeps existing `SCOPE_PAYMENT_TERMINAL = 42`.** A PT in selector mode can span several game locations (or a kiosk), so it sometimes has no single game location — it stays a valid independent scope, *and* can be surfaced as a device pointer under a game trace.

`App/Model/NoDb/Trace/TraceScope.php` — added `SCOPE_DEVICE_COOLCODE = 5` (KIOSK is 4): `_TXT` + `_ICON` consts, entries in `getList()`, `getListOption()`, `isValidScope()`, `getIconByScope()`, `getListWithOperationalStatus()` (it has heartbeat online/offline), and a `resolve()` case → `Cache::getDeviceCoolcode($idScope)` (accessor already exists).

**Cross-cutting (done for DeviceCoolcode):**
- Scope integer values are frozen and mirrored in the JS `islands/trace/constants.js` (`DEVICE_COOLCODE: 5`) and given a config in `utils.js` `getScopeConfig`.
- `trace.scope.device_coolcode` registered in the `trace` `TranslationBlock` and seeded (en/es/pt).

### No new classifier field

We considered a new "what are you opening?" sub-info field and **rejected it**: `trace_type` (MAINTENANCE / INCIDENT / …) already answers that, and `operational_status` (OPERATIONAL / DEGRADED / OFFLINE) is the separate hardware-health axis. Those two existing fields cover it; a third would duplicate `trace_type`.

---

## 4. GLO device sub-types (routine device actions)

For the costless/routine device swaps the tech logs as a GLO, extend the tech sub-type enum. This is a NoDb enum — cheap, no schema change. ✅ done (sapienscore side):

`App/Model/NoDb/Game/GameLocationOperationTechSubType.php`:

```php
const REPLACE_PULSE_BOX        = 7;
const REPLACE_PAYMENT_TERMINAL = 8;
```

Added matching `_TXT` consts, `getList()` entries, `renderLabel()` cases, and seeded `game_location_operation.tech.replace_pulse_box` / `…replace_payment_terminal` (en/es/pt).

**sapiensclient mirror — ✅ done.** Same two constants (`= 7` / `= 8`), `getList()`, and `renderType()` icon cases (`ti-cpu` / `ti-credit-card`) added to `sapiensclient/App/Model/NoDb/Game/GameLocationOperationTechSubType.php`, plus seeded `game_location_operation.tech.replace_pulse_box` / `…replace_payment_terminal` (en/es/pt, noun-phrase house style). Enum values are in parity across both repos. *(If a separate native PDA app holds its own hardcoded sub-type list, that third surface still needs the two options.)*

**Pre-existing gap (not introduced here):** the *entire* `game_location_operation.tech.*` vocabulary (repair, clean, …) is currently unseeded in the translation tree — only the two new keys above are seeded. Worth a seeding pass for the rest when that feature's UI lands.

---

## 4b. One problem, several machines (anchor + affected)

A trace has ONE anchor (`trace.scope` / `trace.id_scope`) and, optionally, a set of **affected** entities (`trace_target`, `sqlinstall00432`). The anchor is unchanged from before: it's what the trace is filed against, where its cost lands, and the TraceEngine dedup discriminator. What the affected set adds is the ability to say "three games in this location went dark" without nominating one of them as the arbitrary protagonist of a fault nobody has diagnosed yet.

### The rule

> **Anchor at the level you're certain about. Add targets for what you observe.**

Three games dark and you don't know why? You are certain it's at Location A, and you observe games 12, 14, 17. That is exactly what the trace should say — no more, no less. Nobody has to be right on day zero.

### One kind only

The affected set is **homogeneous** — one scope for the whole list, held on `trace.target_scope`. If more than one *kind* of thing is affected, it isn't a game problem, it's a location problem: anchor on the Location and describe it. The constraint is a diagnostic heuristic disguised as a form rule, and it's what lets the board's scope filter stay a single indexed table (`scope = X OR target_scope = X`) with no join.

Offered types come from `TraceScope::getListAffectable()` — limited to scopes `TraceSearchRepository::getEntityList` can enumerate per location, because a multi-select needs a bounded list rather than a type-to-search box. Extending it = add the scope there plus a list method in the repository (and mirror `SCOPES_AFFECTABLE` in `constants.js`).

### Cost belongs to the anchor, and is never auto-split

A €400 switch that took six games down was spent **once, at the location**. There is no allocation driver, so there is no honest per-game figure — and the system must not invent one. Splitting it six ways fabricates precision the operator never had; putting all €400 on whichever game got clicked first is simply wrong.

Therefore:

- **Money joins on `is_primary = 1`** (equivalently, on `trace.scope`/`id_scope`). Cost-per-machine means *cost of traces anchored on that machine* — direct cost. Shared cost sits at the level where it was actually incurred, unallocated.
- **Counts join on every `trace_target` row.** "How many incidents did game 14 have", MTTR, and the floor viewer's trouble markers all want the full set — a game taken down by a location-anchored outage really was in trouble.

If allocation is ever wanted, do it at *report* time with a stated driver (revenue, hours, machine count) and label it as allocated. Store the truth; allocate in the report, never in the ledger.

### Split is the release valve

The anchor is immutable — deliberately, since that's what makes mirroring it into `trace_target` safe (written once, never resynced). When investigation shows one of the affected entities was its own fault, **split** it: `TraceManager::splitTarget()` spins it into a trace anchored on that entity, linked back as a `TYPE_CHILD` sub-task, and drops it from the parent's affected set. Its cost and hours then land where they belong, and the umbrella can't close while the split-off work is open.

Same shape as `promoteChecklistItem`, different source list. Cost of the immutable anchor: a trace filed on game 12 that turns out to be the NUC's fault stays slightly coarse, or gets closed as a duplicate. Accepted trade.

### Installs and other work that has no subject yet

"Install 4 Pax IM25 in location A" can't be scoped to a payment terminal — the terminals don't exist; the trace exists in order to create them. Same for procurement. For work-order traces the anchor is the **place**, the affected set is the entities that *do* exist (the 4 game locations receiving them), and the units are checklist items, each promotable to a child if one install turns into its own job. `trace_type = REQUEST` is the planned-work bucket (`OTHER` means unclassified — treat a rising `OTHER` share as a missing type).

## 5. Reporting (all from one ledger)

- **Cost per machine** — `trace_cost` joined to `trace` on `scope` + `id_scope` (the ANCHOR — see §4b), `SUM(quantity * unit_cost)`.
- **Incident count per machine** — `trace_target` joined to `trace`, every row, not just primary.
- **Tech time** — LABOR lines, `SUM(quantity)` grouped by `created_by`.
- **Time by day** — LABOR lines grouped by `worked_on`.
- **Repair count / MTTR** — from Traces (fault records); routine GLO rows (esp. `REFILL_PAPER`) stay out of it by construction, since they're never Traces.

---

## 6. Build plan

1. **`trace_cost`** — `sqlinstall00383.sql` adds `worked_on date`. ✅ done
2. **`TraceCost`** — `worked_on` getter/setter, `create()` accepts `workedOn`, `unitCost` defaults to 0 (no rate). ✅ done
3. **Trace API + UI** — ✅ done. `POST /{id}/hours` → `TraceApiController::addHours` → `TraceManager::addHours` (writes a `LABOR` `trace_cost` row, `unitCost` 0, `worked_on` set; timeline event `trace.update.message_hours_logged`; reuses `publishCostAdded`). Island: `traceApi.logHours`, `store.addHours` (in-place splice, no refetch), cost tab split into money lines (`moneyCosts`, excludes LABOR) + a **Work / Time** section (`laborEntries`, total-hours badge, hours + date form defaulting to today). Vite build green.
4. **`TraceScope`** — `SCOPE_DEVICE_COOLCODE = 5` (PHP + `constants.js`/`utils.js` mirror + `resolve()` via `Cache::getDeviceCoolcode`), i18n registered + seeded. **No `SCOPE_PULSE_BOX`** (reached via game location — see §6 device pointer). ✅ done
5. **`GameLocationOperationTechSubType`** — `REPLACE_PULSE_BOX = 7`, `REPLACE_PAYMENT_TERMINAL = 8` + i18n, on **both** sapienscore and sapiensclient (parity). ✅ done
6. **Translations** — hours keys + `trace.hours.*` UI labels + `trace.scope.device_coolcode` + the two GLO keys all registered/seeded (en/es/pt). ✅ done

## 7. Future / open

- **Device pointer under a game-location trace** *(future, deferred)* — when scope = `GAME_LOCATION`, optionally point at which attached device is the subject (pulsebox / payment terminal / none). Needs a small device-picker UI + a field on `trace` (or `trace.detail`) to hold the pointer. This is how pulsebox/PT faults get device-level attribution without their own scope.
- **Itemized parts on a maintenance Trace** — labor is one LABOR line per session; parts remain normal `trace_cost` PART/CONSUMABLE lines. No change needed; noted so we don't over-model.
- **Native PDA sub-type list** — if the on-device PDA app enumerates tech sub-types itself (rather than fetching `getList()`), add the two options there too. Both PHP repos are already done.
