# Permissions — v2 redesign (study doc)

**Status:** DRAFT / study. Not built. This is the artifact to argue over before any code.
**Branch:** work on `the-big-kahuna`. Do **NOT** use `origin/permissionAccess` (superseded — much has migrated since).

Guiding constraint: **preserve every current user's access exactly on day one.** The redesign is an *evolution* of the existing engine, not a rebuild.

---

**BUILT 2026-07-26 — Location writes + mask levels, Reporting area.**

- **Location masks are now two-level.** The 9 formerly single-level tab masks (info/users/opening_hours/ticket/loyalty_package/floor/table/stock/kiosk) each gained a `LOCATION_*_READONLY` token. `MASK_*` now maps `READ → *_READONLY`, `ADMIN → full`; each full token implies its readonly. `LOCATION_FULL` → view+write every tab; `LOCATION_FULL_READONLY` → view-only. So "read-only Floor, admin Stock" is now expressible.
- **Location write endpoints are mask-gated.** Every location-scoped save endpoint now calls `Permission::requireCan(PermissionArea::MASK_x, PermissionLevel::ADMIN)` **in addition to** its existing role check (additive → no broadening; seed types with `LOCATION_FULL` still pass). Covered: info/users/workstation/ticket (LocationController), opening-hours (LocationOpeningHourController), table (LocationTableController), activity×3 (ActivityLocationController), kiosk (KioskConfigController::updateLocationV2), game×4 (GameLocationController), product (ProductLocationController::updateLocationV2). **`updateTicketSetting` was unprotected (no gate at all) — fixed.** Genuinely shared endpoints (loyalty-package `update`, warehouse-stock `create`) were left to their own domains, not the location mask.
- **Reporting is now an area (§3.1) with per-report masks.** New `REPORTING` parent token + 11 standard `REPORT_*` tokens (individual_range, game, loyalty_card, game_location, product, workstation, maintenance, dynamic_pricing, coin_insert, coin_reconciliation, anomaly_finding); parent implies all 11. The 11 standard report links (MenuConfig) and controllers now gate `canAdminH() OR can(REPORT_x, READ)` — **OR semantics**: HQ users keep access via role (zero regression, seed-independent), and a non-HQ user granted a `REPORT_x` (or the parent) reaches just that report. This is the "reporting and nothing else" / "not all reporting" answer. The sensitive reports (accounting, staff-performance, sales-comparison) and kiosk-report (keys off `KIOSK_READONLY`) stay HQ-locked and are **not** implied by `REPORTING`. `IndividualStaffReport` (no menu link, staff data) left HQ-only.
- **No static `listPermissionByType` change** → no reseed required; existing owner-default rows stay correct. New tokens are grant-only (nobody holds them by default). `getDisplayGroups()` extended so the Sys owner-default editor lists every new token (catalog still covers all 70 constants exactly once).
- **Per-tab read-only UI affordance — done.** `detail.phtml` computes `$canEditTab = can(MASK_x, ADMIN)` and marks any view-but-not-edit pane `data-tab-readonly`; a small `window.locationDetailPage.applyReadonly` strips the save buttons from that pane's `form[data-list-submit]` and appends a lock "view only" note, re-run on `htmx:afterSettle` for the lazy tabs. Server `requireCan(..., ADMIN)` still enforces; this is purely visual. No-op for everyone today (all seed types hold `LOCATION_FULL` ⇒ ADMIN ⇒ no pane is marked).
- **Still open:** the shared loyalty/stock write endpoints (left to their own domains); and the sensitive reports could later be opened to masks too.

---

**APP-WIDE ENFORCEMENT AUDIT + HARDENING (2026-07-26).** A 5-way parallel audit (menu-visibility ↔ controller-enforcement parity, write-endpoint gating) surfaced a systemic gap: **there is no authorization middleware** — `public/index.php` only redirects `isGuest()` (type<1||id<1), so every admin route is only as protected as its own controller body, and menu visibility is cosmetic. Many writes/PII-reads were gated only by the absence of a menu link or a coarse role. **API safety proven before editing:** all fixes are `App\Controller\Admin\*` classes bound only in `routesAdmin.php`; the partner/device/customer surfaces (`GatewayAuth`, `Orbit`, `Porto`, `Workstation`, `Api\Local`) are separate classes/namespaces, so gating admin controllers cannot break any integration. UserType ordering: higher number = higher privilege (CUSTOMER 10 … SAPIENS 90, API 95, SYS 100).

Fixes landed:
- **Privilege escalation (was: any `canAdmin` incl. Local Manager could take over a Sapiens/Sys account or self-grant any permission).** `UserController` now enforces a ceiling `canManageUser()` (`target.type ≤ actor.type`, never self) on update/create/reset/resetPinEmail/forceChangePin/grantPermission/revokePermission/resetPermission; assigned `type ≤ actor.type` on create/update; and a non-HQ admin can only grant permissions within their own effective set. Mirrors the read guard `renderDetail` already had → behavior-preserving for legit management.
- **Ungated dangerous writes gated on the domain capability:** Headwind CRUD/reboot→`DEVICE_HEADWIND_FULL` (reads `_READONLY`); NUC command-queue→`NUC_FULL`, NUC logs→`NUC_READONLY`; Kiosk owner/org/kiosk global config→`KIOSK_FULL` (reads `_READONLY`); Warehouse stock create→`MASK_STOCK` ADMIN (reads READ); GameAcceptor CRUD→`TECH_GROUP`; Reservation reads+quickUpdate+create→`RESERVATION_GROUP` (also restores Customer-Service's create ability); ProductRequest/StockReview/Product/Marketing/Period/Holiday/VatRate/Workstation-position→`canAdminH` (match menu); LoyaltyPackage create/update→`MASK_LOYALTY` ADMIN.
- **Fiscal:** SII schedule + reconciliation reads/writes→`SAPIENS_ACCOUNTING_SYNC` (matching Odoo journal-entry + the menu); SiiLog→`canAdminH`. SalesComparison page now enforces `SALES_COMPARISON_DASHBOARD`; CashInBox report migrated to `canAdminH || can(REPORT_COIN_INSERT)`.
- **New Loyalty area (capability, per the model — not a role gate).** `Permission::LOYALTY_CARD` (view) added; `PermissionArea::LOYALTY` maps READ→LOYALTY_CARD, ADMIN→LOYALTY_CARD_RESET (reset implies view). Loyalty card list/detail/history + transaction/operation ledgers gated on `can(LOYALTY, READ)`; the 3 menu links gated too. Default seed = LOCAL_MANAGER/IT_SUPPORT/MANAGER/SAPIENS/API (not Customer-Service/field-tech — grantable per owner). Catalog now 71 tokens, editor covers all exactly once.

**Report data APIs (`API/Local/V1/Analysis/Reporting/*`) — step 1 DONE.** Design principle: *permission follows the data an endpoint serves, not the report page* — a report grant implies the data domains that report shows, so a shared endpoint feeding report A never over-exposes A's holder. Split by structure: **1:1 endpoints** (14) each back one report → gated `canAdminH() || can(REPORT_x, READ)` so a non-HQ grantee's report renders data end-to-end. **Sensitive** (accounting/staff-performance/sales-comparison/kiosk + the SII reconciliation API) → `canAdminH() && hasPermission(token)` (closes the HQ-admin-without-token data bypass). **Shared building-blocks** (`/sales`, `/item-sales`, `/game-performance/*`, `/activity`, `/reservation-flow`) + off-menu `individual-staff-performance` → LEFT at `canAdminH()` (locked, fails closed for non-HQ, no leak). **Steps 2-3 (follow-up):** trace React report→endpoint consumption for the 5 building-blocks, add `DATA_*` tokens, wire consuming report masks to imply them so composite reports (individual-range, game-report) render for non-HQ grantees too. Low nits: Game `create`(TECH_GROUP) vs `update`(canAdmin) vocab, voucher detail/pdf on canAdmin not the token, `SERVICE_SUPPORT` menu↔controller alignment, loyalty-package menu dead-links. **Architectural note:** a blanket role-floor middleware would conflict with the capability model (a reporting-only/loyalty-only user isn't an admin); the durable systemic fix is a per-route declarative-permission middleware, or continuing to gate each controller with the right capability (current approach).

---

## 1. Why

Problems today:

- **Coarse.** `LOCATION_FULL` = access to *everything* about a location. No per-mask granularity — you can't say "read the whole location, but admin only on Floor."
- **Sprawl.** 39 flat permissions, roughly half of them `_FULL` / `_READONLY` pairs expressing a *level* as two separate constants.
- **Static.** userType→permission defaults are hardcoded in `Permission::$listPermissionByType`; owners can't configure who-does-what.
- **Scope overload.** `LocationUser` is an **allowlist** for some userTypes and a **denylist** for others, decided implicitly by userType.
- **No recap.** No way to see "who can access X."

Goals:

- Two clean, decoupled axes: **capability** (area × level) and **scope** (which locations).
- Per-owner, **Sys-editable defaults in DB**; a **static floor** for SYS + API that can never be lost.
- Preserve all current access on day one.
- **Recap maps** (by permission, by location).

---

## 2. What already exists — and stays (the engine)

`App/Model/User/UserPermission.php` already resolves effective permissions as:

- **Base** = userType defaults (`Permission::getListPermissionByUserType`)
- **+ individual grants** — per-user, stored in user `setting['list_permission']`. *You can already grant a permission the userType lacks, without changing the userType* (`grantPermission`).
- **− individual revokes** — a `-permission` marker subtracts a userType default per user.
- **Implied hierarchy** (`Permission::$listPermissionHierarchy`) — e.g. accounting ⊇ cash ⊇ counter. This is where ADMIN⊇READ will live.
- **SYS** = all permissions, unrevocable.
- **Audit** = `UserPermissionHistory` logs every grant/revoke with who + when.

**We keep this engine.** The redesign changes only: the *vocabulary* (area×level), the *source* of defaults (static → per-owner DB + static floor), adds *location masks*, cleans *scope*, and adds *recap maps*.

---

## 3. Capability model — area × level

**Levels:** `NONE < READ < ADMIN`. Two active levels at launch (`ADMIN ⊇ READ` via the implication engine).

Decision taken: **2 levels now.** A third level, `OPERATE`, sits between READ and ADMIN and means "*can do the day-to-day actions, but not change configuration*" — e.g. Reservations: `READ` see bookings / `OPERATE` create-modify-cancel bookings / `ADMIN` change reservation rules. **Deferred** — add `OPERATE` to a specific area later, only where "handle" genuinely needs to be separable from "configure" (Reservations is the likely first). Nothing needs it at launch.

### 3.1 Top-level areas (mapped from the current 39 permissions)

| Area | Today's permission(s) | Model |
|---|---|---|
| **Location** | `LOCATION_*` (+`_READONLY`) | area with **masks** — see 3.2 |
| **Collection** (game acceptor) | `GAME_ACCEPTOR_COUNTER` / `_CASH` / `_ACCOUNTING` | **ladder**: counter < cash < accounting. **Stays as today — user-specific individual grant only, never a role/owner default** (too sensitive; assigned per person, not per role) |
| **Monitoring** | `MONITORING`, `MONITORING_COMMAND` | READ = view, ADMIN = command |
| **NUC** | `NUC`, `NUC_READONLY` | area × level |
| **PDA** | `PDA_FULL`, `PDA_READONLY` | area × level |
| **Headwind** | `DEVICE_HEADWIND_FULL`, `_READONLY` | area × level |
| **Kiosk (global)** | `KIOSK_FULL`, `KIOSK_READONLY` | **broad** kiosk config — the owner/org tiers of the config cascade (affects many locations) |
| ↳ `Location.Kiosk` mask | — | the **location tier only** — that one location's kiosk overrides. See §3.3 |
| **Reservations** | `RESERVATION_GROUP`, `_CANCEL`, `_CANCEL_REFUND` | READ/ADMIN + **elevated flags** (cancel, refund) |
| **Loyalty** | `LOYALTY_CARD_RESET` | area × level + **elevated flag** (card reset) |
| **Vouchers** | `VOUCHER_BULK_GENERATION`, `_DOWNLOAD` | generate / download |
| **Reporting** | `VAT_SAVING`, `SALES_COMPARISON_DASHBOARD`, `STAFF_PERFORMANCE_REPORT`, `ACCOUNTING_REPORT` | **masks** of Reporting (per-report toggles) |
| **Support/Trace** | `TRACE_ESCALATE`, `TECH_SUPPORT`, `SERVICE_SUPPORT`, `TECH_GROUP` | area × level + elevated flag (escalate) |
| **Integrations** | `NAYAX_GROUP`, `SAPIENS_ACCOUNTING_SYNC` | area × level |

**Not everything is a level.** A few current permissions are discrete **elevated actions** (reservation cancel/refund, loyalty card reset, trace escalate). Keep these as capability *flags* riding on their area — the engine already supports discrete permissions, so this needs no new machinery.

### 3.2 Location masks (2-level: Location → mask)

From the location detail tabs, the masks are:

`Info · Users · Opening Hours · Ticket Settings · Workstation · Loyalty Package · Game · Floor · Table · Product · Stock · Kiosk · Activities`

- Each mask carries its own level (`NONE/READ/ADMIN`).
- A **baseline** can be set at the Location level and **overridden per mask** (via the parent⊇child implication). "Read the location, admin only on Floor" = `Location:READ` + `Floor:ADMIN`.
- Today only some masks are gated (`LOCATION_PRODUCT/WORKSTATION/GAME/ACTIVITY` + global Kiosk); the rest are ungated. Migration brings them under the mask model **defaulting to current effective access** (no new lockouts — see §7).

### 3.3 Kiosk — two capability points, by cascade tier

Kiosk config is a 4-tier cascade (owner → org → location → kiosk). The "full view" needs all tiers, but *editing* a tier differs in blast radius, so split into two rights:

- **`Location.Kiosk`** (a Location mask) — edit **that location's** kiosk overrides (the location tier). Scoped to the location, like every other mask.
- **`Kiosk (global)`** area — edit the **broad** config (owner/org tiers, skin versions) that cascades into many locations. A more powerful right; not location-scoped.

Rule of thumb: change one shop's kiosk → `Location.Kiosk`; change the base that many shops inherit → global `Kiosk`.

---

## 4. Resolution & storage

```
effective(area) =
    max(
        static_floor(userType, area),          // code, SYS + API only — never removable
        owner_default(owner, userType, area),  // NEW DB table, Sys-editable, seeded from today
        individual_grant(user, area)           // existing: user setting list_permission
    )
    minus individual_revoke(user, area)        // existing: '-' marker
    then apply implication (ADMIN⊇READ, Location⊇mask, accounting⊇cash⊇counter)
```

- **static_floor** — the code map, kept **only** for `TYPE_SYS` (all) and `TYPE_API` (its guaranteed set). Unremovable by any DB config. This is the "API users go via static settings so they can never lose permission."
- **owner_default** — NEW DB table, Sys-editable, per-owner (typically 1 owner per installation; 2 locally for testing). **No role concept beyond userType** — a single userType (per owner) + individual grants/revokes is the whole model; we do *not* add owner-defined role bundles.
  - **Storage = ONE row per (owner, userType), permission list as JSONB + `status` (soft-delete).** Same shape as `UserPermission`'s `list_permission`. Tokens (not `area×level`) because the flags — reservation, tech_group, nayax, trace_escalate — don't fit levels; `area×level` is the *query/edit* layer on top. **Never hard-delete** (per the codebase rule): revert-to-default flips `status = DELETED`; save/seed upsert the single row. `OwnerPermissionDefault::getOneByOwnerType()` returns the row (any status) for upsert; `getListPermissionByOwnerType()` returns the ACTIVE row's list or null.
  - **OVERRIDE semantics (built).** A row exists only when an owner has customized a userType. **No rows for a userType → resolution falls back to static `listPermissionByType`** → byte-identical to today until an owner edits. SYS + API are never resolved from here (static floor). `UserPermission::getListTypeDefaultPermission()` caches the lookup (one query/request) and is **guarded** — a missing table (fresh deploy pre-DDL) or unresolvable owner falls back to static, so a permission check can never break. Owner resolved from the *target user's* own organizations (viewer-independent).

  **DDL (`utility/sql/sqlinstall00399.sql`, applied by the deploy sql-update step):**
  ```sql
  CREATE TABLE IF NOT EXISTS owner_permission_default (
      id_owner_permission_default bigserial PRIMARY KEY,
      id_owner        integer NOT NULL,
      user_type       smallint NOT NULL,
      list_permission jsonb NOT NULL DEFAULT '[]',
      status          smallint NOT NULL DEFAULT 1,   -- 1 active, 2 deleted (soft)
      created_at      timestamp with time zone NOT NULL DEFAULT now(),
      modified_at     timestamp with time zone NOT NULL DEFAULT now(),
      modified_by     bigint NOT NULL DEFAULT 1,
      UNIQUE (id_owner, user_type)
  );
  ```

  **Deploy — WIRED (nothing to add manually):**
  1. **Table** — migration `utility/sql/sqlinstall00399.sql` (idempotent `CREATE TABLE IF NOT EXISTS`), applied by `utility/updateDatabase.php` via `core-php/update_database.sh` on container start.
  2. **Seed** — `php command/v2/index.php SeedOwnerPermissionDefault` added to `core-php/Dockerfile`'s start script, right after `EnsureClusterDefault` (i.e. after the sql-update step). `App\Command\Permission\SeedOwnerPermissionDefault` (registered in `src/settings.php`) materialises the static defaults per owner (`OwnerManager::getListKey()` × owner-editable userTypes), skipping any `(owner, userType)` that already has rows — safe on every deploy. SYS + API never seeded (static floor). Seeded rows equal today's defaults → byte-identical until an owner edits.
- **individual grant/revoke** — existing per-user `list_permission` (unchanged).
- **audit** — existing `UserPermissionHistory`; extend to also log owner-default changes.

---

## 5. Scope model (decoupled from capability)

Three modes, made **explicit** (de-overloading `LocationUser`):

| Mode | Meaning | Today |
|---|---|---|
| `ALL` | every location | Sys / Sapiens |
| `ORG` | all locations of the user's organizations, **minus a deny list** | Manager / IT / Tech (`LocationUser` as denylist) |
| `INDIVIDUAL` | only an **allow list** | Local Manager / Customer Service (`LocationUser` as allowlist) |

Represent scope as `(mode, list)` where `list` is unambiguously allow-or-deny by mode. **Migration:** for org-userTypes the existing `LocationUser` rows become the *deny* list; for individual-userTypes they become the *allow* list — i.e. exactly today's meaning, nothing breaks.

- **Cluster** = an *optional* tool to help *build* the list later. **Not** a replacement for org/individual scope now (existing users are configured on org+individual; "whole org minus 3 shops" doesn't map cleanly to a cluster).
- Effective action on a location = **capability ∩ scope**.

---

## 6. Recap maps (Sys-only)

Two read-only views so "who can do/see what" is findable:

- **By permission/area** — given `area + level`, list the users who have it (floor ∪ owner-default ∪ grants, − revokes). Generalizes today's `getListUserByPermission`. *This is also the notification-routing source* (recipients for an area = users with ≥READ on it).
- **By location** — given a location, list who can access it and at what level per mask.

Both Sys-only.

---

## 7. Migration plan (behavior-preserving, phased)

0. **Seed** `owner_default` from `listPermissionByType` → identical behavior.
1. **Vocabulary** — introduce `hasPermission(area, level)` alongside legacy `hasPermission(string)`; legacy constants become computed aliases over area×level. No callsite breaks.
2. **Location masks** — gate the currently-ungated masks, each defaulting to current effective access (no lockouts).
3. **Scope de-overload** — migrate `LocationUser` to explicit `(mode, allow/deny)`.
4. **Sys UI** — owner-default editor + per-user grants; **recap maps**.

Every phase preserves current access; verify each with the recap maps (§6).

---

## 8. Default matrix (Phase-0 seed)

The exact area × level per userType that **reproduces today's `listPermissionByType` + implied hierarchy**. This is the DB seed; owners diverge from here. `VISITOR`/`CUSTOMER` omitted (no back-office access). `SYS` omitted (all areas ADMIN, unrevocable static floor).

**Legend:** `A` = ADMIN · `R` = READ · `–` = NONE · flags noted inline.

| Area | CUST_SERVICE | LOCAL_MGR | MANAGER | IT_SUPPORT | IT_SUP_TECH | SAPIENS | API |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **Location** (baseline → masks) | – | A ⁶ | A ⁶ | A | A | A | A |
| **Collection** (counter/cash/acct) | – | – | – | – | – | – | **acct** ¹ |
| **Monitoring** | – | – | – | A | A | A | – |
| **NUC** | – | – | – | A | – | A | A |
| **PDA** | – | – | – | A | – | A | A |
| **Headwind** | – | – | – | A | – | A | – |
| **Kiosk (global)** | – | – | – | A | – | A | – |
| **Reservations** (+cancel ²) | A | A | A | A | – | A | A |
| **Reservations · refund** | – | – | – | – | – | – | – |
| **Vouchers** (gen=A/dl=R) | – | – | – | – | – | A | A |
| **Support/Tech** ³ | – | – | R | A | A | R | R |
| **Integrations · Nayax** | – | – | – | A | A | – | – |
| **Integrations · AccountingSync** | – | – | – | – | – | – | on |
| **Trace · escalate** (flag) | – | – | – | – | – | on | on |
| **Reporting** · VAT | – | – | – | – | – | – | R |
| **Reporting** · sales-comp / staff-perf / acct-report | – | – | – | – | – | – | – |
| **Loyalty · card-reset** (flag) | – | – | – | – | – | – | – |

**Notes / things this surfaced:**

1. **Collection** — user-specific for humans (never a type default), so `–` across the board **except API**, where it's part of the static floor at `accounting` (the NUC/POS integration must push collection data). Human grants stay individual.
2. **Reservations implies cancel** — `RESERVATION_GROUP` implies `RESERVATION_CANCEL` today, so *everyone with reservations can cancel*. Encoded as a cancel flag riding on the area. ⚠ **Confirm intended** — cancel is a real money-adjacent action; you may want it as a separable flag rather than auto-on.
3. **Support/Tech** — mapping the fuzzy "group" perms: `TECH_GROUP` → READ, `TECH_SUPPORT`/`SERVICE_SUPPORT` → ADMIN (both imply `TECH_GROUP`). ⚠ Confirm what these actually gate.
4. **Entirely individual today (no type default):** loyalty card-reset, reservation refund, and the sales-comparison / staff-performance / accounting-report reports. They're granted per-user now and stay that way — the matrix just records that they have no role default.
5. **API is narrower than it looks** — no Monitoring, Headwind, or Kiosk; but it *does* hold Collection(acct), AccountingSync, and VAT that no human type has.
6. **Manager & Local Manager → Location ADMIN (deliberate Phase-2 change, not today's behavior).** Today they reach the location page via `canAdmin()` but hold *no* `LOCATION_*` permission, and its tabs are ungated — so they see everything by accident, yet don't even get the Location menu link. Decision: grant them Location ADMIN so the model is consistent — they keep full access (scope-limited to their locations for Local Manager) and *gain* the menu link. Owners can tighten specific masks later. This is what makes gating the Location tabs by `can()` safe (every `canAdmin` type then holds the Location permission).

---

## 9. Decisions log

Resolved:

- ✅ **Collection** — stays exactly as today: user-specific individual grant (counter/cash/accounting), never a role/owner default (§3.1).
- ✅ **Kiosk** — split by cascade tier: `Location.Kiosk` mask (one location) vs global `Kiosk` area (owner/org base) (§3.3).
- ✅ **Owner defaults** — per-owner; no role bundles beyond userType (§4).
- ✅ **`OPERATE` level** — deferred; add per-area later where "handle" must split from "configure" (§3).
- ✅ **Mask depth** — 2 levels (Location → mask) now; deepen later only if a mask needs it.
- ✅ **Scope overload** — clean `LocationUser` into explicit `(mode, allow/deny)`, preserving current access (§5).

Still open:

- **Elevated-action flags** (reservation cancel/refund, loyalty card reset, trace escalate) — keep as discrete flags on their area (current lean), or fold into levels later?
- Anything surfaced during the Phase-0 seed once the default matrix is written out per userType.
