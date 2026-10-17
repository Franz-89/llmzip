# Event system

**Audience:** agent implementing the Event feature (company-hosted events at a location).
**One-line summary:** an Event is **not** a new entity. It is a **reservation type** (`reservation.type = EVENT`) whose play-time rules are **stamped onto each participating loyalty card** at activation — the engines enforce card-level restrictions, so nothing new has to sync and offline works for free. The same restriction block is how the loyalty-package rules that exist-but-are-never-enforced finally get enforced.

---

## 1. The decision rule (the whole design in one line)

> **Authoring/booking/lifecycle → reservation (type EVENT).**
> **Enforcement at game-tap time → a restriction block on the loyalty card, evaluated by both engines.**

The engine, at tap time, has exactly two things in hand: the **card** and the **game location** (`App/Engine/LoyaltyCardTransactionEngine.php`, mirrored on sapiensclient). It never loads reservations or packages. The reservation-activation flow already stamps a config snapshot onto the card (`perk_applied` → `detail['reservationSetting']`) and the card already syncs to every NUC with `cardVersion` rebase protection. Rules that must be enforced per-play therefore **ride on the card**, compiled from the event config at activation — never looked up live.

What this buys:

- **Zero new synced entities.** The card mirror carries the rules; offline fallback needs nothing extra.
- **One enforcement layer, two consumers.** The same block enforces the package rules that are currently defined but dead (`LoyaltyMatchLimitDTO`, `LoyaltyProductDTO`, time expiry) and the event rules. Built once.
- **Mid-event config changes** = re-stamp the event's cards and let the existing `SyncLoyaltyCard` fan-out do the rest.

### Use case (canonical)

A company books an event at one of our locations: X products included, post-payment or deposit, N loyalty cards pre-configured (via a loyalty package), games may or may not award tickets, some games excluded (by Game), optionally bookable only by Membership X.

---

## 2. What exists today (verified 2026-07-20)

**Reservation is already ~80% of the shell.** `reservation` has: location, date + time_slot, party size, contact info, hold→pending→confirmed→checked-in→completed lifecycle, **deposit machinery built** (`deposit_required`, `deposit_amount`, `deposit_deadline`, `amount_paid`, partial-payment statuses), `detail` jsonb, NUC sync (by `booking_code` — all outbound reservation endpoints are by-code), and the NFC activation queue: `reservation_loyalty_card` junction (card ↔ reservation, activation audit both sides, created on the NUC and synced up) whose `perk_applied` **SETs** card balances at tap and zeroes them at deactivation (`InboundReservationLoyaltyCardManager`). It has `activity_type` (bowling/birthday/jump — an activity-catalog concept) but **no reservation-kind column**.

**LoyaltyPackage rules: enforced vs. dead.** Enforced: balance application (credit/bonus/courtesy/time/ticket), price, channel flags, location scoping, status. **Defined but enforced nowhere:** match limits (`LoyaltyMatchLimitDTO`), product/game lists (`LoyaltyProductDTO`), time activation type (on-first-play vs on-sell), time expiry (no expiry timestamp is ever recorded; `FIRST_ATTEMPT_AFTER_TIME_EXPIRED` exists as a rejection constant with nothing setting up the condition), free-activation flags.

**Engines are in deliberate parity.** Core `App/Engine/LoyaltyCardTransactionEngine::calculatePaymentBreakdown()` and the sapiensclient mirror run the same checks (card status → game active → time rules → tier discount → balance priority courtesy→bonus→credit→VAT-postponed) with a shared `RejectionReason` enum (codes 1–6). **No game-exclusion mechanism exists anywhere.**

**Ticket machinery.** Config vocabulary: `BusinessSettingDTO.listTicketMode` — per payment method (COIN/EMV/LOYALTY) → `TicketMode` (NONE / PAPER_BY_GAME / PAPER_FIXED / VIRTUAL_BY_GAME / VIRTUAL_FIXED) + quantities + `allowTicketReward` / `allowMultiTicketPayout`; LOYALTY supports all five modes. Runtime decision is **client-side at game start**: `PaymentController` (sapiensclient, ~line 343) picks the wire `payoutMode` (`'paper'`|`'virtual'`) from the location's `PulseBoxPayoutMode` (+ service-card override) and `PulseSenderManager::startGame` sends it to the PulseBox; returned pulses land in `ticket_payout` (`payout_type` PENDING / NOT_PAID / PAID_VIRTUAL / PAID_PAPER). Core-side, `ticketReward` comes from the Nayax POS config and is credited unconditionally on confirmation — no disable flag today.

**Tier vs Membership.** One table: `loyalty_tier.type` = TYPE_TIER (earned via `total_credit_used` thresholds) vs TYPE_MEMBERSHIP (granted). The card carries `id_loyalty_tier` and `id_membership`; the engine already reads both for discounts.

---

## 3. Data model

### 3.1 `reservation.type` (new column)

```sql
ALTER TABLE reservation ADD COLUMN type smallint NOT NULL DEFAULT 1;
```

```php
// Reservation
const TYPE_STANDARD = 1;
const TYPE_EVENT    = 2;
```

One column, one migration. Existing flows are untouched (default STANDARD). `type = EVENT` is the hook for permission gating (permission v2: creating events is its own permission — plain reservation staff can't).

### 3.2 Event config — `reservation.detail['eventSetting']` (jsonb, no new table)

**THE MODEL (corrected 2026-07-20 — supersedes the first draft):** an Event is a FULLY
CUSTOM reservation. Nothing is derived from an activity package: the operator defines
every property directly, BEFORE picking a date. People count is the primary quantity
and lives in the standard `reservation.nr_person` column (so the shop manages the
event exactly like any reservation once people arrive). Inclusions are defined as
typed amounts, PER PERSON automatically ("10 people + 5 bonus" = 5 bonus each), and
stored in **`LoyaltyPackageSettingDTO` shape** — the exact structure card activation
(`perkApplied`) already consumes, so nothing downstream translates. A loyalty package
is only an optional UI prefill for those fields.

```
eventSetting: {
    pricing: { pricePerPerson, discountType, discountValue },  // how the total was built: per-person × people − discount (Voucher::VALUE_TYPE_* vocabulary); informational — reservation.total_amount stays the single money truth
    listActivity: { bowling: {enabled, nrGamePerPerson}, jump: {enabled, timeMinute} },  // included activities, SAME shape as the birthday package — the client types the occupancy slot from it (bowling wins, then jump, else EVENT) so events count against lane/jump capacity; wizard shows the fields per location capability (/reservation/event/location-info)
    perk: { credit, bonus, courtesy, ticket, timeOption {...} },  // LoyaltyPackageSettingDTO shape, PER PERSON
    idLoyaltyCardPackagePrefill: N | null,   // audit only: which package prefilled the fields
    durationMinute: N,                       // "how long will this be?" (events have no package duration)
    listProductIncluded: [ { idProductLocation, quantity } ],  // picker: ProductLocation::getListByIdLocation
    paymentMode: 'deposit' | 'deferred',     // deferred = paid later / bank transfer (§6)
    listExcludedGame: [ idGame, ... ],       // by Game only — never per gameLocation
    isTicketWin: Helper::YES | NO,           // event-wide ticket policy
    matchLimit: { type, nrMatch },           // same vocabulary as LoyaltyMatchLimitDTO
    idMembership: N | null,                  // stored; future self-service booking gate
    block: { enabled, fullDay, fromTime, toTime, idHoliday }   // date block link (§3.4)
}
```

There is deliberately no `nrCard`: cards = people, so the standard max-cards rule
(max of booked / checked-in guests) applies unchanged.

Wrapped in an `EventSettingDTO` (this is real transformation — aggregation + defaults — so a DTO is justified). Follows the existing `detail['setting']` pattern on reservation.

**Activity package is non-load-bearing for events:** a dedicated `ActivityType::EVENT`
on both repos; the NUC hold path skips package + availability validation for events
(the calendar is advisory — §12 wizard). The event still writes its occupancy record
so other bookings' calendars see the load.

**`publicName` (2026-07-27):** optional customer-facing occasion name in
`eventSetting` ("BMW Summer Party" — the reservation `name` stays the contact
person). Wizard define-step field; headline in the confirmation email; leads
the report modal title. Syncs to the NUC inside eventSetting — the future
payment-terminal greeting reads it there.

### 3.2b Creation UI — dedicated 3-step event wizard (core only)

`/reservation/new?event=1` (sidebar `Reservation ▸ New event`, EVENT_MANAGE-gated) is
its OWN flow, not the standard wizard with a panel:

1. **Define** — location, company contact, nr people, negotiated total, payment mode,
   per-person inclusions as amount fields (optional "load from package" prefill),
   included products via SEARCH (catalogs can hold thousands — nothing lists until
   ≥2 chars typed; `ProductLocation::getListByIdLocationNSearch`, top 30, price
   hints via `renderFinalSellingPrice`, **stock deliberately not filtered** — an
   event can include products stocked for the day; picked items accumulate with a
   quantity each), rules (exclusions / tickets / match limit / membership), duration.
2. **When** — ADVISORY calendar: every day selectable; closed days marked ("venue
   opens for this event"); per-day occupancy shown so customer service knows what may
   need moving. Start time free input. Optional date block (§3.4), range prefilled
   from start+duration and widenable (setup/teardown).
3. **Confirm** — full recap, deposit amount (or deferred), create → CONFIRMED, synced.
   Or **Save draft** (§3.2c).

### 3.2c Drafts (core-only, hold nothing)

A draft is a quote-in-progress: the operator captures the full definition without
committing capacity anywhere. Decided 2026-07-20: "it holds nothing".

- **Representation:** same reservation row, `type = EVENT` + `status = PENDING`
  (`Reservation::isEventDraft()`). No new column, no new status value. Booking code
  is core-local: `'D' + invoicePrefix + '_' + key(5)` — replaced by the NUC code at
  confirm.
- **Holds NOTHING:** no NUC hold (the NUC never hears about drafts), no date block,
  no user registration, no email, no PDF. Zero capacity held on either side.
- **Create/save:** wizard "Save draft" button → `createEventDraft` (local store +
  commit only). Editing a draft re-enters the wizard (`editing.isDraft`); "Save
  draft" re-saves locally via `updateEventDraft`.
- **Confirm:** editing a draft and submitting WITHOUT `isDraft` promotes the SAME
  row in place: register user (porto→orbit→skip fallback), NUC hold + convert, swap
  booking code to the NUC one, `status = CONFIRMED`, payment status by deposit;
  commit BEFORE block/PDF/email side effects. Id and history are preserved.
- **Cancel:** `cancelReservation` short-circuits for drafts — local status flip
  only, no `syncCancelReservation` (there is no NUC counterpart), no block release,
  no cancellation email.
- **Guards:** settlement (`registerEventPayment`) throws for drafts; the report
  modal hides the payment + resend-email forms; `sendEventEmail` is blocked by the
  missing `idUser`. Row badge: purple Event + yellow Draft
  (`reservation.type.event_draft`) so drafts are unmistakable in the list.

### 3.4 Date block — Holiday extension (`EVENT_BLOCK`)

Optional per event: "the venue is reserved, not closed". A `holiday` row with a new
`type` column (`STANDARD = 1`, `EVENT_BLOCK = 2`) + `detail.bookingCode` linking it
to the event.

- **Full-day block** = a closed holiday day (existing semantics).
- **Time-range block** = the holiday's EXISTING custom day-schedule set to the
  **complement** of the blocked range (block 16:00→close ⇒ open 10:00–16:00; a
  mid-day block yields two open windows — `listHour` already supports it). Because
  slot generation on BOTH repos derives from opening hours, online booking, the core
  admin wizard and the NUC front-desk calendar all respect the block with zero new
  engine code — identical semantics to closing time.
- **Hard close (block boundary):** "blocked from 17:00" means no reservation may
  END after 17:00 — NOT "last start at 17:00". The holiday detail stores the raw
  `blockRange {fromTime, toTime}`; `getScheduleForDay` (both repos) marks the
  complement window whose close equals `fromTime` with `hardClose = 1`; both
  `ReservationCalendarManager`s then drop generated starts that sit at the
  boundary or whose activity duration would cross it (a start ending EXACTLY at
  the boundary is allowed). Natural closing times stay soft — the last game may
  still run past close, unchanged v1 behavior. Blocks created before this
  change carry no `blockRange` and keep the old boundary behavior until the
  event is re-saved (edit → block release + recreate → resync).
- **Pricing/rule isolation (load-bearing):** holidays also feed price multiplier
  rules and time-slot rule matching (`isHoliday` / `isHolidayEve`) on both repos.
  `EVENT_BLOCK` must be honored ONLY by opening-hours consumers and ignored by
  pricing + rule matching, or event days silently get holiday pricing.
- **Sync:** the holiday outbound payload does NOT ship `detail` today — it must carry
  `type` + `detail` (bookingCode, custom schedule) for the NUC to behave identically.
- Lifecycle: created at event creation (if enabled), released (soft-deleted +
  resynced) when the event is cancelled. Invalidation is ALWAYS status-only —
  never a hard delete.
- **Standard holidays stay creatable on blocked days** (an event may move):
  `Holiday::getUnique` excludes `EVENT_BLOCK` rows, so the admin uniqueness check
  only sees standard holidays. Where both exist on the same day, type-based
  ordering makes the block win deterministically on both repos (`ORDER BY type
  DESC` in the core reader; `type ASC` appended on the client list so the
  map-overwrite keeps the block).

### 3.5 Client operational surface (NUC)

Events are OPERATIONAL at the shop, never editable there:

- **Allowed** (all normal arrival management): guest check-in counting (add/remove
  guest), card activate/deactivate, product delivery, payment history, completion.
  Completion never demands payment for events — the balance is `deferred`/external,
  settled core-side (§6).
- **Blocked** (server-side `type == EVENT` guards + hidden UI): quick-edit, full
  edit/replace, time-slot move, room selection, cancel. Events are defined and
  changed on core only.
- **Included products** land in the EXISTING pre-order fulfillment UI
  (`SellerReservationFulfillmentManager` + ReservationPanel "Pre-ordered" box):
  `listForReservation` is extended to MERGE event products from
  `eventSetting.listProductIncluded` as pending entries — these are NOT payments
  (no `payment_location_item` rows, no zero-value payment artifacts); delivered
  quantities are tracked in the reservation `detail` and sync with the reservation.

### 3.3 Card restriction block — `loyalty_card.detail['restriction']`

The canonical enforcement structure, stamped at activation, wiped at deactivation. Source-agnostic so packages can use it too:

```
restriction: {
    source: 'event' | 'package',
    bookingCode: '...',               // when source = event; the cross-system event tag
    listExcludedGame: [ idGame, ... ],
    isTicketWin: Helper::YES | NO,
    matchLimit: { type, nrMatch, counterTotal: n, counterPerGame: { idGame: n } },
    validUntil: timestamp | null      // finally gives time packages an expiry
}
```

- A card is in **at most one event at a time**, so counters live here safely: deactivation wipes the block → the next event starts clean. No cross-event contamination (this is why we do NOT count `loyalty_card_transaction` rows for limits).
- `bookingCode`, not `idReservation` — booking code is the stable cross-system reservation key (ids can differ; sync endpoints are by-code).
- The relational card↔event link for reporting is the existing `reservation_loyalty_card` junction. The in-detail `bookingCode` is only the runtime tag the engine reads. **No new column on `loyalty_card`, no new table.**

---

## 4. Enforcement (both engines, parity)

Insert a restriction-check step in `calculatePaymentBreakdown()` — after the game-active check, before balance processing — **identically in sapienscore and sapiensclient**:

1. **Game exclusion:** `gameLocation.idGame ∈ restriction.listExcludedGame` → deny.
2. **Expiry:** `validUntil` in the past → deny.
3. **Match limit:** counter at `nrMatch` (total or per-game per `type`) → deny. On approval, increment the counter in the same card mutation as the balance deduction (rides `card_version`).

New `RejectionReason` codes (shared enum, both repos):

```php
const REJECTION_GAME_EXCLUDED       = 7;
const REJECTION_MATCH_LIMIT_REACHED = 8;
const REJECTION_RESTRICTION_EXPIRED = 9;
```

**Transaction stamp:** at approval, when the card has an event restriction, write `bookingCode` into `loyalty_card_transaction.detail`. Cheap, and it makes "games played per event" a direct query instead of an activation-time-window join (survives card reuse across events; a companion table stays backfillable from these stamps if reporting ever outgrows jsonb).

**Counter rebase (load-bearing caveat):** counters ride the card snapshot. The client's inbound rebase (`InboundGatewayLoyaltyCardManager::computeUnsyncedLocalDelta`) must learn to rebase counters the same way it rebases balances — count unsynced local plays under the same `bookingCode` and re-add them on top of an incoming snapshot — or an in-flight core snapshot overwrites offline increments.

**Parity harness:** extend/clone the `CheckPriceEngineParity` pattern to feed both engines identical card+restriction fixtures and diff the verdicts.

---

## 5. Membership gating

`eventSetting.idMembership` set → booking/participation is restricted to customers whose card/user carries that membership (`loyalty_card.id_membership`). This is a **booking-time, core-only check** in the reservation flow — the engine never needs it, so it does not go in the restriction block.

---

## 6. Payment: deposit and deferred

- **Deposit:** already built (`deposit_required`, `deposit_amount`, `deposit_deadline`). Events just use it.
- **Deferred (EVENT-only, replaces the "post-payment" draft):** the company pays later or via bank transfer, handled core-side. The event confirms with `payment_status = UNPAID` and `paymentMode = 'deferred'`; check-in already works unpaid, and **completion at the shop never demands payment for events** (`checkCompletion` skips the payment gate when `type = EVENT`) — the outstanding balance is settled on core, outside the shop flow.
- **Online balance payment (2026-07-25):** the public status page (Porto) shows
  total / paid / outstanding and a Pay-online button for any alive reservation
  that owes money (events stay payable after completion — deferred settlement).
  `ReservationBalancePaymentManager` (modeled on OnlineTopupManager: direct
  Stripe PaymentIntent, payment/payment_transaction/payment_item rows, item
  action RESERVATION → Odoo's normal ONLINE bucket, per §13d "online-machinery
  payments flow via the normal path"). Applied amount is CAPPED at the
  outstanding of completion time (race vs manual settlement — excess is
  SysLogged, never silently applied). Events additionally append
  `detail.listEventPayment` with `source: 'online'` + `syncEventUpdate`;
  standard reservations push money-only via the new NUC endpoint
  `reservation/payment/update` (`syncPaymentUpdate`) so the shop's completion
  gate sees the payment. The status page's old broken branch (UNPAID → hold
  payment page with an empty hold = reload trap) now falls through to the
  status view unless a LIVE hold actually exists.

---

## 7. Ticket policy

`eventSetting.isTicketWin = NO` compiles into `restriction.isTicketWin = NO` on each card. Enforcement is layered, **client-first** (matching where the payout decision actually happens). **Design approved 2026-07-20** after firmware verification:

1. **Client, game start** (`PaymentController` payoutMode decision): card restriction says no tickets → send `payoutMode = 'none'` on the wire. This check runs FIRST, before the location `PulseBoxPayoutMode` mapping — it must override PAPER locations too, or a restricted card would physically dispense. **Firmware fact (verified in sapiens-pulse 0.0.19/0.0.20/v2):** `'none'` is natively accepted and behaves like `'virtual'` — physical dispensing suppressed, pulses counted, `pulse_count` reported back tagged `payoutMode: 'none'`.
2. **Client, pulses return** (`PulseManager::processPulseCount`): an explicit `'none'` case records the full ticket count as **`PAYOUT_TYPE_NOT_PAID_RULE = 5`** (new type — deliberately NOT reusing `NOT_PAID = 2`, which today means "feature disabled / no payout decided"; the new type makes "tickets the event would have won" a first-class report stat), resolution LOYALTY_CARD, status COMPLETED, no credit call. Belt-and-braces: if the mode arrived as `'virtual'` but the card's restriction says no, downgrade to the same type before crediting.
3. **Core, confirmation:** zero `ticketReward` on the transaction when the card restriction says no tickets (already shipped in step 1 of the build plan — covers the Nayax path).

Known firmware edge (pre-existing): pulses arriving with no session + WebSocket down trigger the firmware's safety fallback to paper.

---

## 8. Activation / deactivation

Reuse the existing flow (`reservation_loyalty_card` + `perk_applied` + `InboundReservationLoyaltyCardManager::activateCard`), extended:

- `perk_applied` gains the compiled restriction block alongside the balance perks. Balances come **directly from `eventSetting.perk`** (already in `LoyaltyPackageSettingDTO` shape — per-person amounts typed by the operator; the package-lookup indirection from the first draft is removed).
- Activation: SET balances (as today) + write `detail['restriction']`.
- Deactivation: zero balances (as today) + **delete `detail['restriction']`** (counters die with it).
- Both directions already trigger `SyncLoyaltyCard` — unchanged.

---

## 9. Sync

**Nothing new syncs.** Reservations (holds, conversions, detail) already sync by code; cards already sync with rebase; the restriction block and counters ride the card snapshot. The only sync-layer work is the counter-rebase extension in §4. If a full Event mirror is ever wanted on the NUC, the same-PK mirror checklist (`game_price` / `pricing_guardrail` template) applies — explicitly **not** part of this build.

---

## 10. Reporting (no event table needed)

- **Events created** — `reservation WHERE type = EVENT`.
- **Turnover** — `total_amount` / `amount_paid` + linked `payment_location_item` upsells.
- **Cards involved** — `reservation_loyalty_card` per reservation.
- **Games played** — `loyalty_card_transaction` filtered by the `bookingCode` detail stamp (§4).

---

## 11. What we are explicitly NOT doing

- **No `event` table, no Event model.** Volume is low; the reservation shell + jsonb covers it. Revisit only if reporting outgrows the stamps.
- **No new synced entity.** Rules ride the card.
- **No per-gameLocation exclusions.** By `id_game` only — "model A blocked here but allowed there" has no use case.
- **No transaction-counting for match limits.** Counters live in the wiped-on-deactivation restriction block.
- **No firmware `'none'` payout in v1.** Virtual + not-paid recording achieves the behavior with today's firmware.
- **No parallel controllers/routes.** Event authoring lives in the reservation domain (v2 playbook), gated by type + permission.

---

## 12. Build plan

1. **Restriction block + engine enforcement** (both repos). ✅ done — `LoyaltyCardRestrictionDTO` (identical file both repos), `LoyaltyCard::getRestrictionDTO/setRestriction` (direct detail write — `setDetail()` merge would resurrect a cleared block; core `store()` bumps `card_version` on restriction change so counter-only mutations survive the NUC version guard), checks in both engines' breakdown methods (expired → excluded → match limit, before the free-game special case), `RejectionReason` 7–9 + terminal messages + admin `renderDenialReason` cases (+ en/es/pt seeds), `ticketReward` zeroed on the Nayax path when `isTicketWin = NO`, `bookingCode` stamped into every transaction detail, counter increment in all five core confirm sites + client `applyCharges`, core counter mirror for synced-up offline plays (`InboundLoyaltyCardTransactionManager`, bookingCode-guarded), counter rebase in the client snapshot receiver (`applyRestrictionFromSnapshot` — only the `restriction` key is applied from the pushed detail; local session state untouched), and the `CheckRestrictionEngineParity` command (byte-identical fixture harness in both repos). *Standalone value: this alone activates the dormant package rules (product lists → `listExcludedGame` inverse or allow-list variant, match limits, `validUntil` expiry for time packages).*
2. **`reservation.type` + eventSetting**. ✅ done — `sqlinstall00400.sql` (core) + `sqlinstall00247.sql` (client) add `reservation.type` (default STANDARD); `TYPE_STANDARD/TYPE_EVENT` + `isEvent()` + `getEventSetting()` + `renderTypeBadge()` on both Reservation models; `EventSettingDTO` (`App/DTO/Reservation/`) with `buildRestriction()` compiling the §3.3 card block for step 3; `Permission::EVENT_MANAGE` (default: MANAGER + SAPIENS — deliberately NOT implied by RESERVATION_GROUP) + `PermissionArea::EVENTS` single-level mapping; event creation rides the EXISTING admin wizard (`ReservationDataController::createReservation`): `reservationType`/`eventSetting` in the JSON body, gated by `Permission::requireCan(EVENTS, ADMIN)`, events always confirm via the external-payment branch (deposit amount, or 0 = post-payment → CONFIRMED + UNPAID, which check-in already permits); NUC transit: `type`+`eventSetting` ride the hold **detail** (`ReservationHoldManager::createHold`) and `convertHoldToReservation` lifts `type` into the column while the detail merge carries `eventSetting`; UI = permission-gated Event panel in `_customerForm.phtml` (package, nr cards, payment mode, ticket win, excluded games multi-select, membership, match limit) + EVENT badge in the list row. **Entry point:** sidebar `Reservation ▸ New event` → `/reservation/new?event=1` (item rendered only with EVENT_MANAGE). Event mode reuses the wizard exactly like `isEdit` does: controller passes `isEventMode` (flag silently ignored without the permission), the page title flips, and the JS locks the event panel on (toggle pre-checked, switch hidden) so the wizard can only author an EVENT. The in-wizard toggle remains available in standard mode for the "this booking is actually an event" case. *Not in this slice:* event editing via the replace path, included-products UI (DTO field exists), self-service booking (so the membership gate is stored now, enforced at activation in step 3). *Ops note:* owners with customized MANAGER defaults in `owner_permission_default` replace the static list — grant `event_manage` there explicitly.
3. **Activation stamping**. ✅ done — client `ReservationLoyaltyCardManager`: EVENT reservations resolve the perk from the event's `idLoyaltyCardPackage` (NUC mirror via SyncLoyaltyCardPackage; falls back to the activity perk when the event names none), stamp `detail['restriction']` (compiled by `EventSettingDTO::buildRestriction`, counters zeroed) in the SAME store as the balance SET, ship the block inside `perkApplied` on the junction row, and cap activations at `eventSetting.nrCard` when > 0 (else the standard max(booked, checked-in)); deactivation wipes the block explicitly (setDetail merges — reservationSetting clear alone does NOT remove it). Core `InboundReservationLoyaltyCardManager` mirrors: activation stamps from `perkApplied['restriction']`, deactivation clears; both bump `card_version` so the fan-out snapshot survives the NUC version guard, and the origin NUC re-applies an identical block (reservation SETs are excluded from the balance rebase by design, so no double-count). `EventSettingDTO` is byte-identical on both repos. **Membership gate is deliberately NOT enforced at activation**: activation targets fresh AVAILABLE/MAP cards which carry no membership (a member's personal ACTIVE card is already rejected by the standing validation) — the gate stays stored in eventSetting for the future self-service booking path.
4. **Ticket suppression** (§7 approved design). ✅ done — `PaymentController` checks the card restriction FIRST (before service-card/location-mode mapping) and sends `'none'`; `PAYOUT_TYPE_NOT_PAID_RULE = 5` added on BOTH repos' TicketPayout models (+ render + en/es/pt seeds); `PulseManager::processPulseCount` gained an explicit `'none'` case (records full count, resolution LOYALTY_CARD, bookingCode in detail, COMPLETED, no credit) and a virtual-downgrade belt-and-braces before `payVirtualTicket`. (Core `ticketReward` zeroing already shipped in step 1.)
5. **eventSetting v2 + wizard rebuild** (§3.2/§3.2b). ✅ done — `EventSettingDTO` v2 (byte-identical both repos): `perk` in `LoyaltyPackageSettingDTO` shape, `durationMinute`, `listProductIncluded` by `idProductLocation` (invalid/zero entries dropped), `paymentMode deposit|deferred`, `block{}`; `nrCard` gone (standard max-cards rule restored in the activation manager). `ActivityType::EVENT = 4` both repos — deliberately LOOKUP-ONLY (a separate singleton in `getActivityType()`, never in `getListActivityType()`, so no activity picker or location config ever shows it); `ActivityEventPackageSettingDTO`/`ActivityEventSettingDTO` registered in both factories on both repos so `getSettingDTO()` works at every consumer (the event "setting" is just `{durationMinute}`, giving `getDurationInSecond()` for free at conversion/shop-detail/payment). Client `ReservationHoldManager::createEventHold` (booking code prefix `E`, no package, no availability, type+eventSetting in hold detail); `convertHoldToReservation` lifts type, skips the PDF, writes the ActivityTimeSlot occupancy record with `EVENT` type. Core: dedicated `createEvent` endpoint (`POST /reservation/create-event`, requireCan) + advisory-calendar (`/reservation/event/calendar-info/{idLocation}` — isClosed + nrReservation per day) + location product list endpoints; the standard wizard was RESTORED to its pre-event state (old panel removed from `_customerForm`/`adminReservation.js`) and `/reservation/new?event=1` renders the new 3-step `event.phtml` + `eventWizard.js` (define w/ per-person amounts + package prefill via data-perk, products with qty, rules; advisory month calendar, closed/occupancy badges, free time + duration, optional block prefilled from start+duration; recap + create). Activation perk resolves from `eventSetting.perk` (`getEventPerkDTO`), and `hasLoyaltyPerk`/`getLoyaltyPerkDTO` are event-aware so the shop card modal + detail chips work unchanged.
6. **Client operational lock** (§3.5). ✅ done — `Reservation::supportQuickAction()` returns false for events (hides row edit buttons + blocks quick-edit endpoints in one place); explicit guards in `changeTimeSlot`, `setRoom`, `SellerReservationReplaceManager::replace`; `checkCompletion` charges NO per-guest difference for events (open tab from real on-the-spot sales still settles); `getDetail` ships `isEvent` and the ReservationPanel slot-move chip locks on it (guest stepper, cards, complete stay). Fulfillment merge: `listForReservation` merges `eventSetting.listProductIncluded` as pending/delivered rows with **synthetic negative ids** (−idProductLocation) so the existing Vue delivers them unmodified; delivered counters live in reservation detail `eventProductDelivered` (NOT payment rows), `markDelivered`/`markAllDelivered` route negatives to the detail counter + ReservationSync.
7. **Date block** (§3.4). ✅ done — `holiday.type` (`sqlinstall00401` core / `00248` client), `TYPE_EVENT_BLOCK` + `isEventBlock()` + `getBookingCode()` + create mapping on both Holiday models; `getScheduleForDay` on BOTH repos returns the block's custom schedule without ever raising `_isHoliday_`/`_isHolidayEve_` (pricing + rule isolation) and an event block never makes the previous day an eve; holiday sync payload now carries `type` + `detail` and the client inbound applies them; `EventBlockManager` (core) builds the schedule — full day = closed custom schedule, range = complement of the location's windows (mid-day block ⇒ two open windows) — creates/releases the holiday with the event and triggers `SyncHoliday`.
8. **Cancellation + polish**. ✅ done — core `cancelReservation` gates events by EVENT_MANAGE (plain RESERVATION_CANCEL staff cannot cancel an event) and releases the EVENT_BLOCK holiday after commit (day reopens, resynced). The NUC-side cancel chain already closes everything: `deactivateLinkedLoyaltyCards` wipes each event card's balances AND restriction block via the step-3 deactivation. Core list row: deep-edit + cancel-refund hidden for events (quick edit of contact/comments stays — core IS the management side); cancel shown to EVENT_MANAGE. Holiday admin list badges EVENT_BLOCK rows with the linked booking code.

## 13b. Editing, reporting, settlement (shipped)

- **Event report** ✅ — row button on the event list → `_eventReport.phtml` modal: definition recap, active/total cards, games played + card spend + tickets won (from `LoyaltyCardTransaction::getListByEventBookingCode` — the detail bookingCode stamps), suppressed tickets (`TicketPayout::getListByEventBookingCode` filtered to `NOT_PAID_RULE`), revenue with outstanding balance, payment history.
- **Deferred settlement** ✅ — register-payment form inside the report (EVENT_MANAGE, shown while outstanding > 0): `POST /reservation/action/event-payment/{id}` appends to `detail.listEventPayment` (amount/note/at/by), updates `amount_paid` + `payment_status`, and mirrors to the NUC via `syncEventUpdate`. Settlement is deliberately separate from editing — `updateEvent` never touches `amount_paid`.
- **Event editing** ✅ — row edit button → the SAME wizard prefilled (`?event=1&idReservation=X`): location locked (change of location = cancel + recreate), everything else editable including date/time/duration/block. Same endpoint (`create-event` with `idReservation` → `updateEvent`): NUC push FIRST via the new authoritative `reservation/event/update` endpoint (`ReservationManager::applyEventUpdate` — fields + detail + occupancy `ActivityTimeSlot` moved with the event; guarded to EVENT type) — if the shop is unreachable nothing changes anywhere; then commit, then `EventManager::restampActiveCards` (new block per §3.3 with **counters carried over** so past plays keep counting against the new limits; balances deliberately untouched — perk amounts apply at activation only), then the date block is released + recreated (day/range/enabled may all have changed).

## 13c. Confirmation email (shipped)

Events get their OWN email, not the consumer reservation one: a B2B deal recap
(`templates/email/porto/eventConfirmation.phtml` via
`EmailManager::sendEventConfirmationEmail`) — schedule + duration, people,
per-person inclusions, included products, conditions (ticket policy, excluded
games, match limit), money with outstanding balance and a deferred-payment
note; no PDF/barcode/status-link (events are managed person-to-person on
core). Sent opt-in: a "send confirmation email" checkbox on the wizard's
confirm step (default on, both create and edit — the edit send uses the
"updated details" subject/title variant), plus a "send recap email" button in
the report modal (EVENT_MANAGE). Never automatic on edits — the operator
decides when the negotiated state is worth sending. Registered payments do NOT
auto-email (§13d applies; an acknowledgment can be added later if wanted).

## 13e. Remaining (future slices)

- Surface `detail.eventSetting` in the shop's ReservationPanel (an "Event" info box — data already ships in getDetail).
- Optional payment-acknowledgment email when a settlement is registered.

## 13d. Accounting (decided 2026-07-20)

Registered event payments do NOT flow to Odoo, by design: a deferred/bank
settlement is invoiced and accounted outside the POS/online pipelines, so the
`detail.listEventPayment` audit trail is the system's whole record — no
`payment_location` rows, ever. The only exception is a payment that actually
runs through the online payment machinery, which flows through the normal
online-payment accounting exactly like any other — nothing event-specific.

## 13. Future / open

- **Package-side authoring for restrictions** — packages already define match limits / product lists; wiring their sale paths to stamp `restriction` (source `'package'`) makes them real outside events. Decide whether product lists mean allow-list or exclude-list semantics there (event side is exclude-by-game).
- **Time activation type** (on-first-play vs on-sell) — `validUntil` gives the substrate; on-first-play needs a first-play stamp to start the clock. Deferred with the package work.
- **Firmware `'none'` payout mode** — confirm PulseBox firmware behavior, then prefer it over virtual-and-suppress.
- **Included products redemption** (`listProductIncluded`) — redeemed at POS against the event; kept light in v1 (recorded in eventSetting, checked manually / via upsell flow). A structured redemption counter can follow the same restriction-block pattern if needed.
