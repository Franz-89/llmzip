# Outbound sync queue — unified core→NUC push queue (design proposal)

**Status: INVESTIGATION 2026-07-19** — nothing built. Companion to `/CLUSTERS.md` §7
(the sync-split sketch); this doc refines §7 into a concrete, generic queue design and
records where it deliberately diverges. Dev-DB numbers verified read-only on
`core-dev-database-1` / `core-local`.

---

## 1. Current-state map

### 1.1 Anatomy of every core→NUC push

Every push follows one uniform pipeline — this uniformity is what makes a generic queue
possible:

```
domain write
  → CommandManager::runPhpCommand('SyncX', array(par), background=true)   // fork, fire-and-forget
    → App/Command/SapiensClient/Sync/SyncX.php                            // re-reads entity from DB
      → OutboundXManager::syncX($entity)                                  // builds JSON payload
        → OutboundGenericSyncManager::genericSync(owner, builder, action, idAction, [listLocationCountry])
          → foreach location of owner → foreach NUC of location           // THE FAN-OUT
            → OutboundSendRequestSapiensClient::sendRequest(...)          // curl, sequential
            → SyncTrackingNucManager::updateSync(...)                     // result ledger upsert
```

Key files:

| Piece | File |
|---|---|
| Command runner | `App/Manager/CommandManager.php:82-111` (`runPhpCommand` shells `php index.php <Cmd> <par...> &`) |
| Fan-out loop | `App/Manager/API/Admin/SapiensClient/Outbound/OutboundGenericSyncManager.php:30-46` |
| Single-NUC variant | same file `:51-78` (`genericSyncNuc` — note `:74`: the tracking write is **commented out**) |
| Transport | `App/Manager/API/Admin/SapiensClient/Outbound/OutboundSendRequestSapiensClient.php:13-106` |
| Result ledger | `App/Manager/Sync/SyncTrackingNucManager.php:20-24` → pg function `update_sync_nuc_status` (`utility/sql/sqlinstall00117.sql`) |

The fan-out loop, verbatim (`OutboundGenericSyncManager.php:30-46`):

```php
foreach ($listLocation as $location) {
    if ($location->supportSync()) {
        foreach ($location->getListNuc() as $nuc) {
            if ($nuc->supportSync()) {
                $resultDTO = OutboundSendRequestSapiensClient::sendRequest($requestBuilder, $nuc, $owner);
                ...
                SyncTrackingNucManager::updateSync($nuc->getId(), $action, $idAction, $status, $startSync);
            }
        }
    }
}
```

`$listLocation` is **all locations of the owner** (`LocationManager::getListByOwner`,
country/location filter only when the caller passes one). Gates are only
`Location::supportSync()` (`App/Model/Location/Location.php:836` — not
deleted/closed/WIP) and `Nuc::supportSync()` (`App/Model/Nuc/Nuc.php:516` — LIVE +
primary + in-network). **There is no liveness check, no clustering, no batching, no
queue: one background PHP process makes one sequential HTTP call per NUC of the whole
fleet, per entity change.**

Transport (`OutboundSendRequestSapiensClient.php`): plain `http://` over
Tailscale/VPN, `CURLOPT_CONNECTTIMEOUT` 3s (`:42`) and — noteworthy — **no
`CURLOPT_TIMEOUT`**: a NUC that accepts the connection but responds slowly can stall the
whole fan-out process indefinitely. Sequential means one offline NUC adds ~3s to every
single push process; five offline NUCs add ~15s each.

### 1.2 The loyalty-card snapshot fan-out (worst offender)

`OutboundLoyaltyCardManager::syncLoyaltyCard`
(`App/Manager/API/Admin/SapiensClient/Outbound/OutboundLoyaltyCardManager.php:20-62`)
serialises the **full current card state** (all balances + `cardVersion` — the
balance-audit §9 monotonic guard, `:44-46`) and hands it to `genericSync`. The payload is
built from the card row **at command run time**, not at trigger time — this is what makes
latest-state-wins coalescing free (see §3).

`CommandManager::runPhpCommand('SyncLoyaltyCard', ...)` has **~24 trigger sites**, and
they include the hottest paths in the system — every NUC-originated play/topup that syncs
up to core immediately triggers a full-fleet fan-back-out:

| Trigger | Site |
|---|---|
| Every LCT synced up from any NUC | `App/Manager/API/Admin/SapiensClient/Inbound/InboundLoyaltyCardTransactionManager.php:66` |
| Every carrier LCO synced up | `App/Manager/API/Admin/SapiensClient/Inbound/InboundLoyaltyCardOperationManager.php:305` |
| Nayax / DW200 / payment-terminal charges | `App/Engine/LoyaltyCardTransactionEngine.php:774,922,996,1144,1257,1890` |
| Online topup | `App/Manager/Loyalty/OnlineTopupManager.php:241` |
| Coolcode tickets, Pulse payout, promo/voucher, tier change, admin edits, reservations | `TicketController.php:90`, `PayoutModeController.php:179`, `MarketingPromoController.php:210-211`, `LoyaltyCardTierManager.php:238`, `Admin/Loyalty/LoyaltyCardController.php:122,210,230,406`, `InboundReservationLoyaltyCardManager.php:124,155` |

**Verdict: yes, it really is "every card change → every NUC of the owner, instantly",
one forked PHP process + N sequential HTTP calls per change.** Cost grows as
(card events/day) × (fleet size); an offline NUC additionally taxes every one of those
processes with a 3s connect timeout, and the missed snapshot is never re-sent.

### 1.3 Failure handling today

- Transport failure → `DebugLog` scope `device-sync` LEVEL_ERROR
  (`OutboundSendRequestSapiensClient.php:86,93`) + `SyncTrackingNuc::STATUS_ERROR` in the
  ledger. The command completes "successfully" regardless (fire-and-forget background
  fork; `CronJobManager` wraps each run but records outcome only).
- **No retry exists anywhere.** Grep of `App/Command` for consumers of
  `STATUS_ERROR`: the only reader is
  `App/Command/Loyalty/ReconcileLoyaltyCardBalances.php:100-112`, which is **read-only
  audit** (logs stuck card pushes to DebugLog scope `balance-reconcile`, retries
  nothing).
- Recovery is accidental: a later change to the *same* entity re-runs the sync and
  upserts the ledger row; an entity that stops changing while a NUC is offline stays
  stale on that NUC **forever** (the known hole: admin edits a location while its NUC is
  down → nothing ever re-pushes it).

### 1.4 `sync_tracking_nuc` — verdict

Schema (`utility/sql/sqlinstall00117.sql`, verified live): PK, `id_nuc`, `action`
(enum `App/Model/NoDb/Sync/SyncTrackingNucAction.php` — 52 actions, `LOYALTY_CARD = 11`),
`id_action`, `status` (1 SUCCESS / 2 ERROR — **no PENDING**), `last_attempt_at`,
`last_successful_attempt_at`, `retry_count`, UNIQUE `(id_nuc, action, id_action)`. All
writes go through pg function `update_sync_nuc_status` (upsert + append to
`sync_tracking_nuc_history`).

**It is a last-result ledger, not a queue**: it answers "what was the outcome of the most
recent attempt for entity X on NUC Y" and nothing consumes its ERROR rows. `retry_count`
counts *observed consecutive failures of organically re-triggered pushes*, not scheduled
retries (dev DB: `action=45` rows with `retry_count` up to 5, all sharing one
`last_attempt_at` — repeated pushes, no sweeper). This is exactly why "the cron table
isn't ideal at the current level": both this ledger and the `CronJobManager` rows are
write-only telemetry — errors land, nothing acts.

Keep it (see §7.3) — as a ledger it is genuinely useful: per-NUC, per-entity last-known
sync state is the observability surface the queue itself shouldn't try to be.

### 1.5 `nuc_command_queue` — verdict

Schema `utility/sql/sqlinstall00156.sql`; model `App/Model/Nuc/NucCommandQueue.php`
(statuses PENDING_APPROVAL/QUEUE/SENT/EXECUTED/ERROR/CANCELLED/DELETED; `getNext()`
`:304`). It is a **device-lifecycle command queue, pull-based**: admin queues
REBOOT/SHUTDOWN/REPLACE_PRIMARY/SETUP_SSH/RUN_TAILSCALE
(`App/Controller/Admin/Nuc/NucCommandQueueController.php`), and **spare** NUCs poll it via
`App/Controller/GatewayAuth/API/V1/Nuc/SpareController.php:32-65`. 40 rows total in dev,
last used Jan 2025. It is *not* involved in data sync and its smallint `command` enum +
no-params shape can't carry sync payloads.

**Verdict: leave it alone.** It does prove the useful precedent though: per-NUC pending
rows + the NUC-comes-back-and-drains pattern already exist in miniature. The new queue is
the push-side generalisation (core-driven drain, since primary NUCs don't poll).

### 1.6 What core knows about each NUC

| Signal | Exists? | Where |
|---|---|---|
| Identity / routing | yes | `nuc` table (one primary per location, `id_location` FK, `supportSync()` gate); dev DB: 3 NUCs |
| Liveness | yes, ~10-min resolution | `MonitoringCheckNucs` command (`src/settings.php:69`) → `MonitoringCheckOrchestrator` → `OutboundMonitoringManager::checkNucHeartbeat` (`Outbound/OutboundMonitoringManager.php:39-111`, in-run retry ×3) → `monitoring_check` rows (SCOPE_NUC, TYPE_HEARTBEAT) + `monitoring_alert` (`sqlinstall00231.sql`: `consecutive_failures`, `first_failed_at`) |
| Client version | **reported but discarded** | The NUC's heartbeat response includes `version` (client `InboundGatewayMonitoringManager::getHeartbeatData` `:23`, from the client's `VERSION` constant) — core stores it inside `monitoring_check.detail.heartbeat_data` and never reads it structurally. No field on `nuc`/`nuc_setting`. |
| Capability flags | yes, per location | `location_.detail` JSONB via `Location::getDetailQuick` — precedent: `pda_balance_sync_v2` (`Location.php:979`, set in `Admin/LocationController.php:323`, gated on in `OnlineTopupManager.php:58`) |

### 1.7 Clusters — built and ready to route

Schema live (`utility/sql/sqlinstall00384.sql`): `cluster` (type 1 AUTOMATIC /
2 INSTITUTIONAL / 3 PERSONAL, partial-unique default catch-all per owner) +
`cluster_location`. The routing primitive the queue needs already exists:
`ClusterManager::getAutomaticClusterForLocation(int $idLocation): Cluster`
(`App/Manager/Cluster/ClusterManager.php:384-396`) — explicit AUTOMATIC membership row
wins, else the owner's implicit default catch-all; every NUC location resolves to exactly
one AUTOMATIC cluster by construction (docs/CLUSTERS.md §2). AUTOMATIC clusters are
never shipped to NUCs and exist *only* for this routing (§6). The seed command
`App/Command/Cluster/EnsureClusterDefault.php` is idempotent, runs per deploy.

### 1.8 Push-sync vs RPC — the classification that decides what can queue

The 45 classes under `App/Manager/API/Admin/SapiensClient/Outbound/` split cleanly:

- **Push-sync (queueable)** — one-way "here is state/an event", `*/sync` endpoints:
  loyalty card/context/tier/package, location, organization, product (+country/location),
  activity package (+location), game location (+default), game price, pricing
  guardrail/rule, period (+location), holiday, VAT, user (+password), payment terminal,
  POS device, pulse box, kiosk config, marketing promo, discount button, location table,
  system settings, pool, workstation position, warehouse stock movement / shipping /
  product request, cash internal transfer. All are invoked through
  `runPhpCommand('SyncX', array(par))` — uniformly command + params.
- **RPC (must stay direct, never queued)** — synchronous request/response where the
  caller consumes the answer: `OutboundReservationManager` (create-hold/convert/get),
  `OutboundNfcPaymentManager` (check-status/start-game), `OutboundActivityTimeSlotManager`
  (availability pull), `OutboundMonitoringManager` (heartbeat), kiosk *local-state* reads,
  `OutboundGenericRequestManager` one-offs, and the trace relay. A queue would break
  their semantics; they fail loudly to their caller today, which is correct.

---

## 2. Proposed queue table — `sync_outbound`

One row = one pending delivery to one NUC. Fan-out happens at **enqueue** time (row per
target NUC), payload is built at **drain** time (commands already re-read the entity from
DB — freshness is free).

```sql
CREATE TABLE sync_outbound (
    id_sync_outbound bigserial PRIMARY KEY,
    id_nuc bigint NOT NULL,                 -- target (FK nuc)
    id_location_origin bigint,              -- where the change happened; NULL = admin/global
    command text NOT NULL,                  -- runPhpCommand name, e.g. 'SyncLoyaltyCard'
    par jsonb NOT NULL DEFAULT '[]',        -- positional params array, e.g. [3691601]
    action bigint,                          -- SyncTrackingNucAction::* (ledger continuity)
    id_action bigint,                       -- entity id for the ledger
    dedupe_key text,                        -- e.g. 'loyalty_card:3691601'; NULL = never coalesce
    class smallint NOT NULL,                -- 1 = coalescable snapshot, 2 = ordered operation
    tier smallint NOT NULL,                 -- 1 = realtime (same cluster), 2 = batch (rest of fleet)
    status smallint NOT NULL DEFAULT 1,     -- 1 pending, 2 processing, 3 done, 4 error-retryable, 5 dead
    attempts smallint NOT NULL DEFAULT 0,
    next_attempt_at timestamp with time zone NOT NULL DEFAULT NOW(),
    last_error text,
    created_at timestamp with time zone NOT NULL DEFAULT NOW(),
    created_by bigint,
    modified_at timestamp with time zone,
    processed_at timestamp with time zone
);

-- coalescing: at most ONE live coalescable row per (NUC, entity)
CREATE UNIQUE INDEX sync_outbound_dedupe_idx
    ON sync_outbound(id_nuc, dedupe_key)
    WHERE status IN (1, 4) AND dedupe_key IS NOT NULL;

-- drain scans
CREATE INDEX sync_outbound_drain_idx
    ON sync_outbound(id_nuc, tier, status, next_attempt_at);
CREATE INDEX sync_outbound_order_idx                        -- class-2 ordering per NUC
    ON sync_outbound(id_nuc, id_sync_outbound) WHERE status IN (1, 4);
CREATE INDEX sync_outbound_created_at_idx ON sync_outbound(created_at);
```

Convention notes: singular snake_case table, `id_sync_outbound` PK, smallint enums (no
booleans), `detail`-style jsonb for `par`, the standard `set_updated_timestamp` trigger.
`action`/`id_action` are carried so the drainer keeps feeding the existing
`sync_tracking_nuc` ledger unchanged.

Status semantics: `4 error-retryable` stays in the dedupe window (a newer snapshot
coalesces into the failed row and resets it), `5 dead` (attempts exhausted) falls out of
it and becomes an alerting surface.

---

## 3. Coalescing — the two classes

**Class 1 (coalescable snapshot):** the payload is "current full state of entity X",
rebuilt from DB at send time — so N pending deliveries of the same entity to the same NUC
are literally the same delivery. Enqueue is an UPSERT:

```sql
INSERT INTO sync_outbound (id_nuc, id_location_origin, command, par, action, id_action,
                           dedupe_key, class, tier)
VALUES (...)
ON CONFLICT (id_nuc, dedupe_key) WHERE status IN (1, 4)
DO UPDATE SET par = EXCLUDED.par, tier = LEAST(sync_outbound.tier, EXCLUDED.tier),
              status = 1, attempts = 0, next_attempt_at = NOW(), last_error = NULL;
```

"Sync card A" queued 10 times before the drain runs = **one row**; `tier` upgrades to
realtime if any of the 10 came from the NUC's own cluster. Safety is not heuristic: the
snapshot carries `card_version` and the v2 NUC applies it under a monotonic guard
(balance-audit §9, `OutboundLoyaltyCardManager.php:44-46`), so even a stale in-flight
delivery racing a fresh one cannot regress state. Coalescing for card snapshots is
**provably** latest-state-wins. Same argument holds for every config snapshot (location,
product, promo, ...) where the payload is a DB re-read.

**Class 2 (ordered operation):** delta/event pushes where each row is a distinct fact and
order matters (warehouse stock movements — dev ledger `action=45` is exactly this shape —
shipping lines, cash internal transfers, user password changes). `dedupe_key = NULL`,
always append, and the drainer delivers them **strictly in `id_sync_outbound` order per
NUC**: a class-2 failure halts that NUC's drain (head-of-line blocking, deliberate) until
retry succeeds or the row is dead-lettered by an operator. Class-1 rows are
order-independent by definition and may be delivered around a blocked class-2 row.

---

## 4. Enqueue API — `OutboundSyncQueueManager`

One manager, one entry point; producers never think about clusters, tiers, or targets:

```php
OutboundSyncQueueManager::enqueue(
    ?int $idLocationOrigin,   // where the change happened; null = admin/global change
    string $command,          // 'SyncLoyaltyCard'
    array $par,               // [$idLoyaltyCard]  (per-NUC targeting added by the drainer)
    int $class,               // self::CLASS_SNAPSHOT | self::CLASS_OPERATION
    ?string $dedupeKey,       // 'loyalty_card:123' | null
    int $action, int $idAction // SyncTrackingNucAction continuity
): void
```

Internally:

1. Resolve targets: owner's locations with `supportSync()` → their primary
   `supportSync()` NUCs (exact same gates as `genericSync` today).
2. Resolve tier per target: `ClusterManager::getAutomaticClusterForLocation($idLocationOrigin)`
   → NUCs whose location is in that cluster get `tier = 1`, everyone else `tier = 2`.
   `idLocationOrigin === null` (admin/global config change) → tier 1 for all (rare, low
   volume — Salvatore to confirm, §9.3).
   Capability override: a command may force tier 1 for NUCs lacking its batch
   capability (§6).
3. One UPSERT per target NUC (§3).
4. Kick the realtime drainer (non-blocking `runPhpCommand('SyncOutboundDrain', [...], true)`
   with a cheap advisory-lock/flag so bursts don't stampede).

Producer migration is mechanical and gradual: a push site changes
`CommandManager::runPhpCommand('SyncLoyaltyCard', array($id), true)` →
`OutboundSyncQueueManager::enqueue($idLocationOrigin, 'SyncLoyaltyCard', array($id),
CLASS_SNAPSHOT, 'loyalty_card:' . $id, SyncTrackingNucAction::LOYALTY_CARD, $id)`.
Un-migrated sites keep working untouched — the two paths share the wire contract.

Multi-step DB writes stay per repo rules; **enqueue fires after commit**, same as sync
commands today (memory: `feedback_sapiensclient_db_transactions` — same principle on
core).

## 5. Drain workers

**Delivery primitive:** the drainer runs the row's command *targeted at one NUC* — i.e.
payload build via the existing `OutboundXManager` + `genericSyncNuc`
(`OutboundGenericSyncManager.php:51-78`), reinstating the ledger write that is currently
commented out at `:74`. The wire contract (endpoints, payloads, GatewayAuth) is
untouched; NUCs need **zero changes**.

**Realtime drainer** (`SyncOutboundDrain`, cron every minute + post-enqueue kick):

- Select distinct NUCs with `tier = 1` due rows (`status IN (1,4) AND next_attempt_at <= NOW()`).
- Skip NUCs currently failing heartbeat (`monitoring_alert` open with
  `consecutive_failures >= 2` for check_type heartbeat) — don't burn 3s timeouts on a
  known-down box; rows just wait. Attempt anyway if the alert is stale (> 30 min old) so
  the heartbeat is never a hard dependency.
- Per NUC (parallelisable per NUC, sequential within): deliver in `id_sync_outbound`
  order, **blocks of ~50 rows**, class-2 halt-on-failure per §3. Claim rows with
  `UPDATE ... SET status = 2 WHERE status IN (1,4) ... RETURNING` (or
  `FOR UPDATE SKIP LOCKED`) so overlapping drainers never double-send.
- Success → `status 3`, `processed_at`; ledger upsert SUCCESS. Failure → `status 4`,
  `attempts + 1`, `next_attempt_at = NOW() + LEAST(2^attempts minutes, 1 hour)`,
  `last_error`; ledger upsert ERROR. `attempts > ~20` (≈ a day) → `status 5` dead +
  DebugLog ERROR scope `device-sync` (class 1 could alternatively retry forever — §9.6).

**Batch drainer** (nightly cron): same per-NUC block loop over `tier = 2` rows, larger
blocks (~200), spread over the night window, rate-limited per NUC. Because class-1 rows
coalesced all day, the nightly work per NUC is bounded by *distinct changed entities*,
not event count.

**Offline NUC / catch-up:** an offline NUC is nothing special — its rows sit pending,
class-1 keeps coalescing on top of them (a card changed 50 times during a 3-day outage =
1 row). When heartbeat flips back to success, hook
`MonitoringCheckOrchestrator` to kick the drainer for that NUC immediately; otherwise the
next cron pass catches it. **This closes the §1.3 hole by construction** — the
admin-edited-location-while-NUC-down case becomes a pending row that delivers on return.

## 6. Capability gating

What core actually has (§1.6): per-location detail flags (read at enqueue/drain time via
`Location::getDetailQuick`) and a per-NUC client version already arriving in every
heartbeat but currently buried in `monitoring_check.detail`.

Recommendation, concretely:

1. **Persist the heartbeat version**: in `OutboundMonitoringManager::checkNucHeartbeat`,
   on success write `heartbeat_data.version` into `nuc.detail` (e.g. key
   `clientVersion`, plus `clientVersionAt`). One-line-ish change, gives core a queryable
   fleet-version map for free.
2. **Per-command capability registry** in `OutboundSyncQueueManager`: a static map
   `command → requirement`, where a requirement is a location-detail flag and/or a
   minimum `clientVersion`. First and only entry initially:
   `SyncLoyaltyCard` batch-tier delivery requires `pda_balance_sync_v2 = 1` (the
   `card_version` rebase is what makes *delayed* snapshots provably safe; a legacy NUC
   applying an hours-old snapshot without the monotonic guard could regress local state).
3. **Gating semantics = tier forcing, not blocking**: a target NUC that fails a command's
   batch requirement gets its row forced to `tier = 1` (today's behaviour: immediate
   push, just with retries added). Nothing is ever silently dropped, and the mixed fleet
   ("core updates everywhere at once, clients little by little") degrades to exactly the
   current behaviour per un-upgraded NUC. When the flag/version flips, that NUC starts
   enjoying batching — no queue change needed.

## 7. Migration path

### 7.1 Order

1. **Phase 0** — table + `OutboundSyncQueueManager` + both drainers + `nuc.detail`
   version persistence. No producer migrated; test via a manual enqueue.
2. **Phase 1 — card snapshot fan-out** (the design's first and most important customer):
   flip the ~24 `runPhpCommand('SyncLoyaltyCard', ...)` sites to `enqueue(...)`,
   class 1, `dedupe_key 'loyalty_card:<id>'`, origin = the location the triggering
   event came from (inbound LCT/LCO carry it; Nayax/terminal engines know their
   location; admin edits pass null). This alone removes the dominant fan-out load and
   closes the offline-card-staleness hole.
3. **Phase 2 — config snapshots**: `SyncLocation`, `SyncProduct*`, `SyncUser`,
   `SyncGameLocation`, promos/vouchers/packages... — same mechanical flip, class 1,
   `dedupe_key '<entity>:<id>'`. Mostly admin-originated → tier 1 everywhere at first
   (volume is trivial); the win here is retry + offline catch-up, not batching.
4. **Phase 3 — ordered operations**: warehouse stock movements, shipping, cash internal
   transfer, user password — class 2, no dedupe key. Do these last; head-of-line
   semantics deserve their own testing pass.
5. **Never migrated**: the RPC set (§1.8) — reservations, NFC payment, time slots,
   heartbeat, kiosk state reads, trace relay, `OutboundGenericRequestManager`. The
   distinction is mechanical: if the caller reads the response, it is not a push.

### 7.2 Coexistence

Wire contract unchanged → queued and direct pushes interleave safely during the whole
migration (class-1 payloads are DB re-reads; card ops additionally carry
`card_version`). No client release required for any phase; `pda_balance_sync_v2` gates
only *batch-tier* card delivery (§6.3).

### 7.3 `sync_tracking_nuc` fate

**Keep, as the result ledger it already is** — the drainer writes it exactly as
`genericSync` does today (and fixes `genericSyncNuc:74`). Do **not** implement
CLUSTERS.md §7's "STATUS_PENDING rows in sync_tracking_nuc" variant: the ledger's UNIQUE
`(id_nuc, action, id_action)` would force coalescing onto class-2 ordered ops (wrong),
it has no command/par columns (so it could only ever serve hardcoded actions, defeating
the unified-queue goal), and mixing "current known state" with "work to do" makes both
harder to query. `sync_outbound` = work to do; `sync_tracking_nuc` = how it went;
`sync_tracking_nuc_history` = the audit trail. Update CLUSTERS.md §7 to point here once
this is accepted.

## 8. Scale sanity

Dev DB (read-only, 2026-07-19): 302,703 loyalty cards, 282 locations, 3 NUCs, ledger
1,692 rows (1,650 SUCCESS / 42 ERROR — errors sitting there unretried, as designed
today). Dev traffic is negligible, so parametrically, with F = fleet NUCs, E = card-change
events/day, D = distinct cards changed/day, k = avg AUTOMATIC-cluster size:

| Model | HTTP pushes/day | Offline-NUC cost |
|---|---|---|
| Today | E × F | 3s timeout burned per event per offline NUC; missed pushes lost forever |
| Queue + clusters | realtime E' × k + nightly ≤ D × (F − k) coalesced | zero (rows wait); full catch-up on return |

Worked example — F = 100, E = 100,000 (e.g. 50 busy shops × 2,000 card events),
D = 15,000, k = 5: today ≈ **10,000,000** pushes/day (plus 100k forked PHP processes each
crawling 100 NUCs sequentially); queued ≈ 500k realtime (E' ≤ E; intra-burst coalescing
shrinks it further) + ≤ 1.4M nightly in rate-limited blocks ≈ **~2M/day, with the
latency-sensitive part 20× smaller and the bulk moved off-peak**. The ratio improves
linearly with fleet growth: today's design scales O(E×F); the queue scales
O(E×k + D×F) with the D×F term coalesced, schedulable, and cheap.

## 9. Salvatore to decide

1. **Dedicated `sync_outbound` table vs CLUSTERS.md §7's pending-rows-in-ledger** — this
   doc argues for the dedicated table (§7.3); §7 of CLUSTERS.md should be amended either
   way.
2. **`par` as `jsonb` (proposed) vs plain `text`** — jsonb matches repo convention and
   keeps params queryable; text is closer to the literal "par can be a string" brief.
3. **Tier for origin-less pushes** (admin/global config, `idLocationOrigin = null`):
   proposed realtime-everywhere since volume is trivial — confirm, or route them batch
   for non-cluster NUCs too.
4. **Class-2 head-of-line blocking**: a poisoned ordered row blocks its NUC's class-2
   stream until dead-lettered — accept (proposed), or add per-command sub-streams so
   e.g. stock movements can't block password syncs.
5. **Batch window**: single global night window vs per-location
   `location_.business_day_cutoff_hour`/timezone (fleet spans PT/ES/US in dev data).
6. **Dead-letter policy**: attempts cap ≈ 20 with 1h max backoff then `status 5` + alert
   (proposed), vs retry-forever for class 1 (a snapshot can never be wrong to resend).
7. **Retention**: delete `status 3` rows after N days (proposed 7) vs keep and rely on
   `sync_tracking_nuc_history`; also decide history retention itself.
8. **Post-enqueue kick mechanics**: forked drain command with advisory lock (proposed)
   vs pure 1-minute cron (simpler, +up-to-60s realtime latency).
9. **Heartbeat-version persistence location**: `nuc.detail.clientVersion` (proposed) vs a
   dedicated `nuc_setting.sapiensclient` key.
10. **Phase-2 scope**: which config syncs are worth batch tier at all, or whether
    everything except loyalty cards stays tier-1 until proven noisy.


---

## 10. DECISIONS (Salvatore, 2026-07-20) — resolves §9 and adds requirements

Mapping to §9 items plus new directives from review:

1. **§9.1 — dedicated `sync_outbound` table: YES.** Amend CLUSTERS.md §7 accordingly.
2. **§9.2 — `par` as `jsonb`: YES.**
3. **§9.3 — origin-less pushes realtime-everywhere: YES** — and they still go
   THROUGH the queue (a NUC can be offline at push time; the queue is what
   makes "everywhere" eventually true).
4. **§9.4 — head-of-line blocking: REJECTED as proposed.** Requirements:
   (a) a blocked ordered stream raises a **Notification to the SmartMonkey
   admin user** (core Notification system; exact recipient Salvatore will
   specify); (b) new manual row status **SKIPPED (6)** — an admin can mark a
   stuck row skipped from the admin UI and the stream continues ("product
   stuck but harmless → skip, keep working"); (c) blocking is scoped so
   realtime snapshots are NEVER stopped by an ordered-stream block; and
   (d) per §10.9 below, ordering lanes are **per command-family per NUC**,
   never global per NUC — a product error must never block loyalty sync.
5. **§9.5 — batch window: manually defined** (config, not hardcoded night;
   "it's not just at night"). Per-owner or global setting, editable.
6. **§9.6/§9.9-related — dead-letter: lane-scoped.** Cap+dead-letter is fine
   WITHIN a lane, but a dead row in lane X (products) must have zero effect
   on lane Y (loyalty). Class-1 snapshots: retry-forever is acceptable
   (a snapshot resend is never wrong).
7. **§9.8 — post-enqueue kick: confirmed** (fork drain command with advisory
   lock after tier-1 enqueue; cron as safety net).
8. **§9.9 — NUC version: store in `nuc` record, update only when the
   heartbeat value differs from stored** (no write per heartbeat). Enables
   the rule: "above version X → list/batched sync payloads; below →
   individual legacy pushes".
9. **NEW — version handshake on upgrade:** sapiensclient gains a command,
   run after a successful install/upgrade when the client is ready, that
   proactively reports its version to core — so core knows immediately,
   not at the next heartbeat.
10. **NEW — non-NUC-origin operations** (e.g. online top-up): the origin
    location for cluster routing is decided by rule — e.g. the card's LAST
    LOCATION USED — so every operation still resolves to exactly one
    cluster. The enqueue API must accept an explicit origin resolution for
    these cases.
11. **NEW — enqueue-during-drain:** more updates keep arriving while a
    drain runs. The coalescing UPSERT must be race-safe against rows
    moving PENDING→PROCESSING (a new enqueue during processing creates a
    NEW pending row rather than updating the in-flight one — never lose
    the newer state).
12. **Phase scope (§9.10):** batch tier certainly for loyalty cards.
    Products: probably, BUT product imports must process completely and in
    order — batching may split them into blocks processed strictly
    sequentially (one lane, ordered), never sampled or partially applied.

13. **NEW — tier isolation on the kick (Salvatore, 2026-07-20):** the
    post-enqueue kick drains ONLY tier-1 rows for that NUC; a large tier-2
    night backlog is invisible to it and never delays a realtime update.
    Corollaries: (a) **cross-tier upward coalescing** for class-1 — a
    tier-1 enqueue that matches a PENDING tier-2 row's dedupe key PROMOTES
    that row to tier-1 instead of duplicating (the card syncs now, the
    night batch shrinks); (b) **ordered lanes never mix tiers** — each
    class-2 command-family lives in exactly one tier, or realtime rows
    could overtake pending batch rows of the same lane and break ordering.
    Only class-1 snapshots (order-free via card_version) get promotion.

Retention (§9.7) left open — no decision recorded yet.

---

## 11. Implementation status — slice 1 (2026-07-20)

Slice 1 is BUILT and emulated on the dev DB (`core-dev-database-1` / `core-local`).
Core-side only; **zero sapiensclient changes** — the wire contract is untouched, the
drainer delivers through the existing outbound managers + `genericSyncNuc`.

### 11.1 What exists

| Piece | File |
|---|---|
| Migration (applied to dev) | `utility/sql/sqlinstall00398.sql` — `sync_outbound` table, partial-unique dedupe index, `enqueue_sync_outbound()` + `claim_sync_outbound()` pg functions |
| Queue row model | `App/Model/Sync/SyncOutbound.php` (class/tier/status enums, finders) |
| Enqueue API | `App/Manager/Sync/OutboundSyncQueueManager.php` — `enqueue(owner, idLocationOrigin, command, par, class, dedupeKey, action, idAction, forceTier)` |
| Drain logic | `App/Manager/Sync/OutboundSyncQueueDrainManager.php` — per-NUC per-tier; class-1 order-free, class-2 per-lane head-of-line |
| Drain command | `App/Command/Sync/SyncOutboundDrain.php` (`SyncOutboundDrain <idNuc|0=all due> <tier>`), registered in `src/settings.php`; per-(NUC,tier) pg advisory lock |
| Single-NUC card delivery | `OutboundLoyaltyCardManager::syncLoyaltyCardNuc()` (payload rebuilt at drain time) |
| Ledger write reinstated | `OutboundGenericSyncManager::genericSyncNuc()` — the commented-out `updateSync` at old `:74` is live again |
| NUC version persistence (§10.8) | `OutboundMonitoringManager::checkNucHeartbeat()` writes `nuc.detail.clientVersion`/`clientVersionAt` only when the heartbeat value differs; accessors `Nuc::getClientVersion()`/`setClientVersion()` |

Decisions honored: §10.11 race rule (the dedupe window is `status IN (1,4)` only, so an
enqueue during PROCESSING inserts a NEW pending row — verified under simulated
concurrency); §10.13a cross-tier upward promotion via `tier = LEAST(...)` in the UPSERT;
§10.13b ordered lanes never mix tiers (class-2 enqueues are pinned to one tier —
default realtime — via `forceTier`); §10.4 lane isolation (lane key = `command`; a dead
product row blocks only its own lane; class-1 snapshots are never blocked); §10.6
class-1 retry-forever with 2^attempts backoff capped at 1h, class-2 dead-letters at 20
attempts + `NotificationManager::addHigh` (recipient: `NOTIFICATION_RECIPIENT_ID`
constant in the drain manager, TODO Salvatore — currently falls back to Sapiens users);
§10.7 post-enqueue kick forks `SyncOutboundDrain(idNuc, 1)` — tier-1 only per §10.13.

### 11.2 Producer migration (Phase 1 done)

All **21 live** `runPhpCommand('SyncLoyaltyCard', ...)` sites flipped to
`OutboundSyncQueueManager::enqueue(...)` with `dedupe_key 'loyalty_card:<id>'`
(the doc's "~24" counted 2 commented-out engine lines and the Marketing pair that
collapsed into ONE enqueue — origin cluster realtime + rest batch replaces the old
"sync this location now + sync everywhere" double push). Origins: inbound LCT/LCO/
reservation + engines + Coolcode/Pulse controllers pass their location; admin edits
(`LoyaltyCardController` ×4) and tier/public/topup managers pass what they have
(card location / `$idLocation` / null ⇒ realtime everywhere per §10.3).

### 11.3 Emulation results (dev DB, all PASS, test rows cleaned up)

1. 10 enqueues of one card → **1 row** (same id returned 10×).
2. Row forced PROCESSING + concurrent enqueue → in-flight row untouched, **new pending row** created.
3. Tier-2 pending row + tier-1 enqueue, same dedupe key → **same row promoted to tier 1**, still 1 row.
4. Dead class-2 head (lane `product`) → lane blocked, **class-1 snapshot delivered anyway**, notification row created; manual `status=6` (SKIPPED) → next drain proceeds past it.
5. Failing delivery → `status 4`, `attempts+1`, `next_attempt_at` in the future; nothing lost; class-1 never dead-letters.
6. Registered command end-to-end: `php index.php SyncOutboundDrain 1 1` delivered a real card snapshot to the live dev NUC and wrote the `sync_tracking_nuc` ledger (SUCCESS).
7. Advisory lock: drain while another session holds the (NUC,tier) lock → 0 NUCs drained, row waits; after release → delivered.
8. Post-enqueue kick: manager enqueue alone → forked background drain delivered within seconds.

### 11.4 Known limits / deliberate slice-1 scope cuts

- **Batch window (§10.5)**: `SyncOutboundDrain <idNuc> 2` drains tier 2 whenever invoked —
  the manually-configured window IS the cron schedule for now (schedule the tier-2
  invocation in the window you want). A proper editable setting (per-owner or global)
  is slice 2.
- **Cron safety nets — SCHEDULED 2026-07-25**: the schedule is baked into the docker
  images via a crontab versioned in each app repo (`utility/docker/crontab` → image
  `/etc/crontabs/root`, busybox `crond` started next to php-fpm in the entrypoint).
  Core: `SyncOutboundDrain 0 1` every minute, `SyncOutboundDrain 0 2` every 15 min
  (window-gated internally). Client: `LoyaltyCardTransactionSync` every ~30s (twin
  lines, pg-advisory-locked) + `GameLocationOperationSync` sweep every minute. No host
  crontab anywhere — the schedule ships with the code version, which is what the
  capability-gating design assumes. Read-only admin views: core Maintenance > Cron,
  client hidden route.
- **Admin UI for SKIPPED (§10.4b)** is out — operators flip `status=6` manually until the
  queue admin page lands (slice 2).
- **§10.9 client-side version handshake command** is sapiensclient work — not in this slice.
- **§10.10 origin rule for online top-up** ("card's last location used"): the enqueue API
  takes the explicit origin; `OnlineTopupManager` currently passes its `$idLocation`
  (the top-up's location) — a smarter last-location-used resolver is slice 2.
- **FIXED 2026-07-25 — anonymous-context fan-out drop.** `enqueue()` resolved the fleet
  via `LocationManager::getListByOwner`, which rides `Organization::getListByOwner`'s
  `canAdmin()` gate — in anonymous contexts (public card page completing an online
  top-up) it silently returned an empty fleet, so the top-up applied on core but no
  snapshot row was ever enqueued. Every "missing top-up enqueue" observed on
  2026-07-23/24/25 was this, not stale container code. Fix: `enqueue()` now uses the
  ACL-free `getListByOwnerSystem` variants (Organization + LocationManager), so the
  queue works identically in every producer context. Reproduced and verified both ways.
- **Un-flipped producers** (`SyncLocation`, `SyncProduct*`, ...) still fan out directly —
  Phase 2/3 per §7.1. The drainer's delivery registry currently knows `SyncLoyaltyCard`
  only; an unknown command fails the row cleanly (retry/dead + alert, nothing lost).
- **Enqueue is synchronous in the producer's request path** (per-target cluster resolution
  + one pg-function call per target). Fine at current fleet size; for large fleets move
  the fan-out into a single set-based pg call or a background enqueue command (slice 2).
- Translation key `sync.error.outbound_lane_blocked` added as
  `translation_utility/adminlte/{en_00140,es_00133,pt_00120}` — run the translation
  import on deploy as usual.

### 11.5 Suggested slice 2

1. Batch-window setting (per-owner, editable) + cron registration; heartbeat-recovery
   kick (hook `MonitoringCheckOrchestrator` on down→up transition).
2. Queue admin page: list/filter rows, SKIP button (status 6), retry-now, dead-letter
   review; lane health widget.
3. Phase 2 producers: config snapshots (`SyncLocation`, `SyncProduct*`, `SyncUser`, ...)
   — mechanical flips, class 1, tier 1 everywhere first.
4. Capability gating (§6): per-command registry consuming `nuc.detail.clientVersion` +
   `pda_balance_sync_v2`, forcing tier 1 for non-capable NUCs; sapiensclient §10.9
   version-handshake command.
5. Retention job (§9.7 — still undecided) + set-based enqueue fan-out for large fleets.

---

## 12. Implementation status — slice 2 (2026-07-21)

Slice 2 is BUILT and emulated on the dev DBs (`core-dev-database-1` / `core-local`,
handshake end-to-end against `client-dev-sapiensclient-1`). **No new migrations** —
the batch window reuses `organization_setting` (sqlinstall00168); everything else is
code-only.

### 12.1 Batch window (§10.5)

Per-owner editable setting: `OrganizationSetting::TYPE_SYNC_BATCH_WINDOW` (type 4),
detail `{"startHour": h, "endHour": h}`, server-time hours, wrap-around supported,
`start == end` = always open. Defaults (no row): 01→06
(`OutboundSyncQueueManager::BATCH_WINDOW_DEFAULT_*`). API:
`OutboundSyncQueueManager::{getBatchWindow, setBatchWindow, isBatchWindowOpen}`.

**The window gates the tier-2 fleet sweep per NUC** (`SyncOutboundDrain 0 2` resolves
each due NUC → location → owner and skips NUCs whose owner's window is closed), so the
sweep can be cron-scheduled at any frequency and the *setting* decides when batches
flow — an owner edit needs no crontab change. An explicit `SyncOutboundDrain <idNuc> 2`
bypasses the window (manual/admin drain). Editable from the queue admin page (§12.3).

**Cron registration** — scheduling is external to the repo (no in-repo crontab; the
`src/settings.php` `commands` map is a registry only). Add to the deployment crontab:

```
* * * * *          cd /app/command/v2 && php index.php SyncOutboundDrain 0 1
0,15,30,45 * * * * cd /app/command/v2 && php index.php SyncOutboundDrain 0 2
```

Tier 1 every minute is the safety net behind the post-enqueue and recovery kicks;
tier 2 every 15 minutes gives the window ~15-min granularity (the tier-2 sweep also
runs retention, §12.6).

### 12.2 Heartbeat-recovery kick (§5 offline catch-up)

`MonitoringAlertEvaluator::handleSuccessfulCheck` — the FIRST success after a failure
streak (`consecutiveSuccesses == 1` on an active NUC heartbeat alert) stores the
streak reset and forks `SyncOutboundDrain(idNuc, 1)` via
`OutboundSyncQueueManager::kickDrainNuc()` (also now used by the post-enqueue kick and
the admin retry/requeue actions). The store-before-fork ordering guarantees the kicked
drain's `isNucKnownDown()` never reads the stale "down" alert. Tier 1 only — tier-2
backlog waits for its window per §10.13. Emulated: pending row delivered ~1 s after
the simulated down→up check.

### 12.3 Queue admin page (§10.4b)

Route `GET /sync-outbound` (v2 Tabler, `Login::currentUser()->canAdmin()`, sidebar
entry next to Cluster). `App/Controller/Admin/Sync/SyncOutboundController.php` +
`templates/adminlte/v2/syncOutbound/{index,module/_list,module/_row}.phtml`.

- List with server-side filters (status / NUC / lane / tier, 500-row chunk), status
  count strip, dead-letter quick filter (`?status=5`).
- Row actions (inline `data-list-submit` forms, `{status, id, row}` envelope):
  - **Skip** → `POST /sync-outbound/skip/{id}` — PENDING/RETRY/DEAD → SKIPPED (6);
    unblocks a dead class-2 lane head.
  - **Retry now** → `POST /sync-outbound/retry/{id}` — RETRY → PENDING, due now,
    tier-1 kick (attempts preserved so future backoff continues from history).
  - **Re-queue** → `POST /sync-outbound/requeue/{id}` — DEAD → PENDING, attempts 0
    (dead rows are class-2/no-dedupe-key, so the coalescing index cannot conflict).
- Batch-window editor card (per owner) → `POST /sync-outbound/batch-window`.
- Manager methods (`OutboundSyncQueueManager::{markRowSkipped, retryRowNow,
  requeueDeadRow}`) validate transitions and reject anything else.

Translations `sync.*` + `menu.sync_outbound` + `api.success.nuc.client_version`:
`translation_utility/adminlte/{en_00141, es_00134, pt_00121}` — run the import on
deploy as usual.

### 12.4 Capability gating (§6 — infrastructure)

`OutboundSyncQueueManager::LIST_COMMAND_MIN_CLIENT_VERSION` — per-command minimum
`nuc.detail.clientVersion` map, **empty by default** (entries added when a payload
actually needs a client capability, e.g. `'SyncLoyaltyCard' => '2.4.0'`). The drain
manager checks it before delivering: below-minimum (or unreported version) → the row
simply **waits** — status untouched, `waitingVersion` counted in the drain summary,
distinct `device-sync` log. Class-2 lanes wait whole (delivering around the head would
break ordering). Emulated with a temporary entry: unreported → waits; reported 1.0.4
vs min 99.0.0 → waits; min 1.0.0 → delivers.

Note this is a second, orthogonal mechanism to §6.3's tier-forcing (which remains the
plan for `pda_balance_sync_v2`-style "deliver now instead of batched" gating —
slice 3): the min-version map is for payloads a legacy client cannot apply at all.

### 12.5 Client version handshake (§10.9)

- **sapiensclient**: command `ReportClientVersion` (registered in `src/settings.php`;
  `App/Command/ReportClientVersion.php` → `OutboundClientVersionManager`) posts
  `{idLocation, version}` through the standard machine-auth pipe to
  `/v1/sapiensclient/nuc/client-version`. Version source =
  `InboundGatewayMonitoringManager::getSystemVersion()` (now public; same source the
  heartbeat reports). **Run it in the post-upgrade step of the client deployment**,
  after the client is serving.
- **sapienscore**: route + `GatewayAuth/API/V1/SapiensClient/Nuc/NucController` →
  `InboundNucVersionManager::reportClientVersion()` — resolves the location's primary
  NUC and persists via the same on-change `nuc.detail.clientVersion`/`clientVersionAt`
  path as the heartbeat (§10.8). Emulated end-to-end from the dev client container:
  version 1.0.4 persisted; a second report changed nothing (on-change verified).

### 12.6 Retention (§9.7 — REDESIGNED 2026-07-21, TimescaleDB-native)

Owner directive: **no application-level retention DELETE jobs.** The earlier slice-2
approach (`DONE_RETENTION_DAYS` + `purgeDoneRows()` in the tier-2 sweep) is REMOVED
and replaced by database-native retention (`utility/sql/sqlinstall00403.sql`):

- **`sync_outbound` stays a plain table holding only LIVE rows** (pending /
  processing / retry / dead / skipped). It is deliberately **NOT a hypertable** —
  `drop_chunks` on it would destroy old pending rows for long-offline NUCs.
- **`sync_outbound_done`** is a new **hypertable** (time column `processed_at`
  NOT NULL, 1-week chunks) mirroring `sync_outbound`'s columns plus the origin
  queue id as `id_sync_outbound_origin`. Retention:
  `add_retention_policy('sync_outbound_done', INTERVAL '7 days')` — TimescaleDB's
  background job drops whole chunks, so a completed row lives 7–14 days.
- **Completion is an atomic pop**: on successful delivery the drain manager calls
  the pg function `complete_sync_outbound(id)` — a single CTE statement that
  DELETEs the PROCESSING row from `sync_outbound` and INSERTs it into
  `sync_outbound_done` (status 3, `processed_at = NOW()`). No window where the row
  exists in both or neither table; per-row at delivery time, not a batch job.
- `SyncOutbound::STATUS_DONE` stays defined for the history rows' status value /
  render back-compat, but no live row ever carries it anymore.
- Admin page: the "done" status filter now reads the history hypertable via the
  read-only model `App/Model/Sync/SyncOutboundDone.php`
  (`templates/.../module/{_listDone,_rowDone}.phtml`, clearly labeled — keys
  `sync.label.done_history*` in `translation_utility/adminlte/{en_00143, es_00136,
  pt_00123}`); the done count in the status strip comes from the history table.
- `sync_tracking_nuc`(+history) remains the long-term audit trail.

Emulated (dev DB): enqueue + drain → row moved to `sync_outbound_done` with
`processed_at` set and gone from `sync_outbound`; fake 16-day-old done row →
`CALL run_job(<retention job_id>)` dropped its (fully expired) chunk, while a
10-day-old row survived because its 1-week chunk still reaches into the window
(chunk-granularity retention — the documented 7–14 day lifetime), a 3-day-old
row was kept, and a 30-day-old PENDING row in `sync_outbound` was untouched
(plain table — retention can never reach it).

### 12.7 Emulation results (dev DB, all PASS, test data cleaned up)

1. Window: defaults `{1,6}`; set/read `{22,6}`; wrap-around open/closed per hour
   correct; `{4,4}` always open; hour 25 rejected.
2. Sweep gating: tier-2 row + closed window → `0 NUC(s) drained`; open (wrapping
   23→2 at 23:xx) → delivered to the live dev NUC, ledger SUCCESS.
3. Recovery kick: fabricated OPEN heartbeat alert (3 failures) + SUCCESS check →
   kick logged, forked tier-1 drain delivered the pending row within ~1 s.
4. Admin actions: skip 1→6, retry-now 4→1 (due now), requeue 5→1 (attempts 0),
   skip 5→6; all invalid transitions rejected (`Operation not allowed`).
5. Capability gate: see §12.4. Const restored to `array()` after emulation.
6. Retention: only the >7-day DONE row purged by the tier-2 sweep
   *(superseded by the §12.6 TimescaleDB-native redesign, 2026-07-21)*.
7. Handshake: `php index.php ReportClientVersion` on the dev client container →
   core persisted `{"clientVersion":"1.0.4"}`; idempotent on re-run.
8. Admin page render smoke: index + list + rows rendered (correct per-status action
   buttons, per-owner window forms).

### 12.8 Remaining (slice 3)

- **Phase 2/3 producers**: `SyncLocation` flipped 2026-07-26 — all 10 direct
  `runPhpCommand` sites now `enqueue()` with a target-filtered fan-out
  (`listIdLocationTarget` = the location itself, preserving genericSync's
  own-NUC-only semantics), `case 'SyncLocation'` added to the drainer registry
  (delivery via `OutboundLocationManager::syncLocationNuc`).
  **Device producers flipped 2026-07-26** — all class 1 (CLASS_SNAPSHOT),
  all origin- AND target-filtered to the device's own location (the old paths
  all sent to the primary NUC of the device's own location only):
  - `SyncPulseBox`: `DeviceConfigSyncManager::checkAndSyncPulseBox` (the single
    producer site) — hash guard kept, `runPhpCommand` → `enqueue()`, dedupe
    `pulse_box:<id>`; delivery via `OutboundPulseBoxManager::syncPulseBox(pb, idNuc)`.
  - `SyncKiosk` (registry key only — NO CLI command; old producers synced
    inline): `DeviceConfigSyncManager::checkAndSyncKiosk` (unconditional, as
    before) and the inner send of `OutboundKioskManager::syncKioskIfChanged`
    (guard kept) — dedupe `kiosk:<id>`; delivery via
    `OutboundKioskManager::syncKiosk(kiosk, idNuc)`.
  - `SyncPaymentTerminal` (registry key only — NO CLI command): inner send of
    `OutboundPaymentTerminalManager::syncPaymentTerminalIfChanged` (hash guard
    kept — funnel for every `DeviceConfigSyncManager::checkAndSync*` path) —
    dedupe `payment_terminal:<id>`; delivery via `syncPaymentTerminal(pt, idNuc)`.
    Terminals ALSO still travel inside the `SyncLocation` bundle — the redundant
    paths coexist deliberately.
  - `SyncPosTerminalDevice`: 2 sites in `PosTerminalDeviceController`
    (create/update) — par + dedupe key are the LOCATION id
    (`pos_terminal_device:<idLocation>`), because the wire payload is the
    location's whole device list (existing command semantics); delivery via the
    new `OutboundPosTerminalDeviceManager::syncPosTerminalDeviceListByLocationNuc`
    (empty device list = success no-op, mirroring the fleet variant).
  - Straggler: `Reservation/EventManager::restampActiveCards` still had a live
    `runPhpCommand('SyncLoyaltyCard')` — flipped to the standard card enqueue
    (full fleet, no target filter, like every other card producer).
  - NOT flipped (deliberate): `OutboundNucManager`'s provisioning bulk pushes
    (`syncPulseBoxList` / `syncPaymentTerminalsByLocation` with explicit idNuc)
    — already single-NUC direct sends, not fleet producers; CLI command files
    kept as escape hatches.
  **Calendar/master-data producers flipped 2026-07-26** — all class 1
  (CLASS_SNAPSHOT), par shapes kept identical to the old CLI commands so the
  registry rebuilds the same payloads; the CLI files stay as escape hatches:
  - `SyncHoliday` (CLI key maps to `SyncListHoliday`): 4 sites
    (`HolidayController` create/update, `EventBlockManager` create/release) →
    `OutboundHolidayManager::enqueueHolidayScope(country, idLocation)`. par =
    `(country, idLocation)`. idLocation > 0 => origin + target = that location,
    dedupe `holiday:<country>:<idLocation>`; idLocation 0 (country-level
    holiday) => the old CLI looped EVERY owner and genericSync filtered by
    country code — preserved via `OwnerManager::getListKeySystem()` (new,
    ACL-free) + `LocationManager::getListIdByOwnerCountrySystem()` (new —
    country → owner's location ids through the same `Location::getListApiSync`
    split), one enqueue per owner with a country-resolved target list, dedupe
    `holiday:<country>`, origin NULL (realtime everywhere, §10.3); owners with
    no location in the country are skipped (the old zero-NUC no-op). Delivery
    via the new `OutboundHolidayManager::syncHolidayScopeNuc` — the scope list
    is rebuilt at delivery time (location list or country list, exactly the old
    CLI's load), empty list = success no-op, owner for the auth token resolved
    from the target NUC's location (in the old owner loop only the fleet owner
    ever matched).
  - `SyncActivityPackage`: 4 sites in `ActivityPackageController` →
    `OutboundActivityPackageManager::enqueueActivityPackage()` — the old
    fan-out filtered by the package's COUNTRY code; resolved to the owner's
    location ids at enqueue time (empty resolution => skip the enqueue; empty
    country => whole-fleet NULL filter, matching the old split's no-condition
    behavior). Dedupe `activity_package:<id>`, origin NULL; delivery via the
    existing `syncActivityPackage(pkg, idNuc)`.
  - `SyncActivityPackageLocation`: 2 sites in
    `ActivityPackageLocationController` — origin + target = the APL's own
    location, dedupe `activity_package_location:<id>`; delivery via the
    existing `syncActivityPackageLocation(apl, idNuc)`. (The promo command
    `SyncMarketingPromoActivityPackageLocation` on the update path is NOT part
    of this wave and still runs via CLI.)
  - `SyncPeriod`: 2 sites in `PeriodController` — the old fan-out had no
    country/location filter => whole owner fleet (NULL target), origin NULL,
    dedupe `period:<id>`; delivery via the existing `syncPeriod(period, idNuc)`.
  - `SyncPeriodLocation`: 1 site in `PeriodController` (date cascade) —
    origin + target = the row's location, owner = the LOCATION's owner (not
    created_by), dedupe `period_location:<id>`; delivery via the existing
    `syncPeriodLocation(pl, idNuc)`.
  **Location sub-family producers flipped 2026-07-26** — all class 1
  (CLASS_SNAPSHOT), par shapes kept identical to the old CLI commands; the CLI
  files stay as escape hatches (`SyncListGamePrice`,
  `SyncWorkstationPositionLocationList` untouched):
  - `SyncGameLocation`: 3 sites in `GameLocationController` (create, update,
    related-GL cascade) → `OutboundGameLocationManager::enqueueGameLocation()`.
    The old path sent to the primary NUC of the entity's own location only —
    preserved as origin + target = that location. Dedupe `game_location:<id>`;
    delivery via the existing `syncGameLocation(gl, idNuc)`.
  - `SyncGameLocationDefault`: 1 site (`GameLocationDefault::syncToNuc`, the
    write-funnel hook) → `enqueueGameLocationDefault()` — the old fan-out had
    NO location filter => whole owner fleet (NULL target), origin NULL, owner
    from the GLD's location. Dedupe `game_location_default:<id>` (the payload
    is the single row, not a location set); delivery via the existing
    `syncGameLocationDefault(gld, idNuc)`.
  - `SyncGamePrice`: 1 site (`GamePrice::syncToNuc` — the funnel for every
    price write incl. `syncScopeEntityToNuc`) → `enqueueGamePrice()` — old
    fan-out unfiltered => whole owner fleet (NULL target), origin NULL, owner
    from the price's game. Dedupe `game_price:<id>`; delivery via the existing
    `syncGamePrice(gamePrice, idNuc)`.
  - `SyncWorkstationPositionLocation`: 2 sites
    (`WorkstationPositionLocationController` update,
    `Workstation/WorkstationPositionLocationManager::completeList` create) →
    `enqueueWorkstationPositionLocation()` — origin + target = the row's own
    location (the old genericSync location filter). Dedupe
    `workstation_position_location:<id>`; delivery via the new
    `syncWorkstationPositionLocationNuc(wpl, idNuc)` (returns the raw
    genericSyncNuc array; the old `sync()` keeps its bool contract for the CLI
    and now shares `buildRequest()`).
  - `SyncListVatRate` (the List command IS the producer path — no per-row
    command exists): 2 sites in `VatRateController` (create, update) →
    `OutboundVatRateManager::enqueueVatRateCountry(country)`. par = `(country)`,
    payload = the country's whole VAT list rebuilt at delivery time, so dedupe
    `vat_rate:<country>`. The old CLI looped EVERY owner and genericSync
    filtered by country code — preserved via `OwnerManager::getListKeySystem()`
    + `LocationManager::getListIdByOwnerCountrySystem()`, one enqueue per owner
    with a country-resolved target list, origin NULL; owners with no location
    in the country are skipped (the old zero-NUC no-op). Delivery via the new
    `syncVatRateCountryNuc(country, idNuc)` — empty list = success no-op, owner
    for the auth token resolved from the target NUC's location.
  - **LocationTable — investigated, deliberately NOT queued**: there is no
    `SyncLocationTable` CLI command and zero `runPhpCommand` producers. The
    only live callers of `OutboundLocationTableManager::sync*` are (a)
    `OutboundNucManager`'s init/backfill bulk push (explicit idNuc — not a
    fleet producer, same category as the other provisioning pushes) and (b)
    `LocationTableController::save`, which fires
    `OutboundSyncService::syncLocation()` on the SAME code path — and the
    `SyncLocation` bundle already carries `listLocationTable` (client
    `InboundGatewayLocationManager` upserts them from the location payload).
    Tables therefore always travel inside the location bundle; the dedicated
    `syncLocationTableList` call there is a redundant belt-and-braces send left
    as-is. No registry key added. (Side note: that controller still syncs the
    location INLINE via `OutboundSyncService::syncLocation`, not the queue —
    it is not a `runPhpCommand` site, so no wave has flipped it yet.)
  **SyncUser + inline user/location producers flipped 2026-07-26 (wave E)** —
  the wave whose motivation is ADMIN-REQUEST LATENCY: the user/location/table
  save paths ran INLINE NUC syncs (one sequential curl per NUC, 3 s connect
  timeout each when a NUC is offline), so admins waited on NUC HTTP just to
  save a user setting or add a user to a location. After this wave those
  producer paths only insert queue rows (milliseconds); delivery happens in
  the drain. All class 1 (CLASS_SNAPSHOT):
  - `SyncUser`: 15 producer sites flipped to the new funnel
    `OutboundUserManager::enqueueUser(User)` — the 8 `runPhpCommand('SyncUser')`
    sites (`RegisterController` ×3, `ProfileController` ×3, GatewayAuth
    `UserController` + `UserPinController` — gateway context works because
    enqueue's fleet lookup is ACL-free) AND the 7 INLINE
    `OutboundUserManager::syncUser()` sites (`UserController` ×3,
    `LocationController` add-user-to-location, `RegisterController` forced
    reset, `PinManager::forceChangePin`, `UserManager` create). Targeting
    preserved from the old fan-out: owner = the first sync location's owner,
    target filter = `Location::getListForSync(idUser)` ids resolved at enqueue
    time (status-bypassing — a deleted/banned user still syncs so clients
    revoke the login); no location yet => no enqueue (the old
    'nothing to sync' no-op). Origin NULL (realtime everywhere), dedupe
    `user:<id>`, action `SyncTrackingNucAction::USER`. Delivery via the new
    `OutboundUserManager::syncUserNuc(user, idNuc)` (delegates to the untouched
    `syncUser` single-NUC branch — identical wire payload, genericSyncNuc
    result). CLI `SyncUser` kept as escape hatch.
  - The last two INLINE `OutboundSyncService::syncLocation` controller sites
    flipped to the standard SyncLocation enqueue (dedupe `location:<id>`,
    origin + target = the location itself): `LocationController` create-location
    (the `syncWarehouse` call there stays inline — not part of this wave) and
    `LocationTableController::save`. In the latter the redundant direct
    `OutboundLocationTableManager::syncLocationTableList` send was REMOVED:
    the `SyncLocation` bundle already carries `listLocationTable` and the
    client `InboundGatewayLocationManager` upserts each row through
    `InboundGatewayLocationTableManager::syncLocationTable` — same data, one
    queued path (supersedes the §12.8 side note above). Live testing exposed
    that this client branch had ALWAYS been a silent no-op: it passed the raw
    table row where `syncLocationTable` expects the `locationTable` envelope,
    so the isset guard returned false and tables only ever reached the client
    via the direct list endpoint. Fixed on sapiensclient 2026-07-26 (wrap in
    `array('locationTable' => ...)`); verified by content round-trip (capacity
    6→7→6 through the queued bundle alone). NUCs running a client older than
    that fix won't mirror table edits from the bundle until they upgrade —
    gate via `LIST_COMMAND_MIN_CLIENT_VERSION` if that matters before fleet
    rollout.
  Still pending:
  `SyncProduct*`, promos… (class 1) and the ordered set
  (warehouse/shipping/cash/password, class 2); extend the registry per command.
- **§6.3 tier-forcing capability rule** (`pda_balance_sync_v2` → batch-tier card
  delivery) once batch-tier card rows actually ship.
- **§10.10 origin resolver** for online top-up (card's last location used).
- **Set-based enqueue fan-out** for large fleets (§11.4).
- **`NOTIFICATION_RECIPIENT_ID`** — still the TODO fallback to all Sapiens users.
- **Lane health widget** on the admin page (blocked-lane overview) — the list +
  filters cover review; a dedicated widget is polish.
- Amend CLUSTERS.md §7 to point here (§10.1) — still pending.
- **Ledger retirement for cards + cron_job_status retention (done 2026-08-02).**
  `sync_tracking_nuc` hit 10.6M rows / 9.2GB in prod, dominated by the
  per-(NUC,card) LOYALTY_CARD rows (action 11) written by
  `SyncTrackingNucManager::updateSync` on every `genericSync`/`genericSyncNuc`
  delivery (both writes are live — the §1.1 "commented out at :74" note is
  historical; slice 1 reinstated it). Since every card delivery now lands in
  `sync_outbound_done`, `updateSync` skips action LOYALTY_CARD (early return —
  all other actions still ledger). Consumer moved:
  `ReconcileLoyaltyCardBalances`' failed-push signal now counts live
  `sync_outbound` rows `command='SyncLoyaltyCard' AND status=STATUS_RETRY`
  instead of sync_tracking_nuc STATUS_ERROR (same report shape). Separately,
  `cron_job_status` (8.8M rows / 5.4GB, append-only, never purged) became a
  Timescale hypertable on `created_at` (1-week chunks, 30-day
  add_retention_policy, PK re-keyed to `(id_cron_job_status, created_at)`
  like 00403) — `sqlinstall00418.sql`. Existing action-11 rows are NOT
  deleted by this slice; a one-off prod DELETE (batched) can reclaim the
  9.2GB once the queue history is trusted.
- **Reconcile chain-walker: include till top-up events.** Live testing 2026-07-25:
  `ReconcileLoyaltyCardBalances` reported a chain break on card 3691531 between two
  LCTs — the gap was a till top-up (client `payment_location_item`, which DOES carry
  `balanceBefore`) whose event kind the core walker doesn't read. Balances agreed on
  both sides; the walker just needs the seller payment-item events in its chain.
- **SHIPPED 2026-08-02 (§13 — batched tier-2/catch-up delivery):** batched
  `SyncLoyaltyCard` drain transport (client `loyalty-card/sync-batch` endpoint +
  `OutboundLoyaltyCardManager::syncLoyaltyCardBatchNuc`, gated by
  `BATCH_SYNC_MIN_CLIENT_VERSION` = client 2.1.0), in-process kick dedup
  (`suspendKicks`/`flushKicks`, wired into the inbound LCT batch), version-report
  wiring hardened (failure-tolerant image CMD + daily crontab line), and
  `markRetry` now records the actual failure reason in `last_error`. Details,
  measurements and remaining levers in §13. The §6.3 tier-forcing rule and
  §11.4 set-based enqueue remain open (thresholds in §13.5).
- **SHIPPED 2026-08-02 (§13.6 — upload ack carries card state, origin echo
  suppressed):** the loyalty-card upload response
  (`loyalty-card/sync-offline-transaction`) now additively returns
  `listCardResult` — per touched card the FINAL post-batch state
  (`idLoyaltyCard`, `cardVersion`, `balance` = the snapshot wire field names).
  A client >= `ACK_APPLY_MIN_CLIENT_VERSION` (**2.2.0**) applies it through
  the unchanged rebase receiver (version gate + Σ still-sync=0 deltas +
  tripwire) while still holding the per-card (7301) upload locks, so
  `InboundLoyaltyCardTransactionManager::processBatch` passes the uploading
  NUC (the upload location's primary NUC, same resolution as the §10.9
  handshake) as `enqueue()`'s new `excludeIdNuc` param — CREATION of the
  redundant `SyncLoyaltyCard` echo row for the origin NUC is skipped.
  Creation only: an existing pending/retry row for that NUC (e.g. an online
  top-up) is untouched and still delivers. Old clients (< 2.2.0 or
  unreported) keep the full echo fan-out. Details in §13.6.
- **SHIPPED 2026-08-18 (NULL-origin producers fixed — cluster scoping actually
  engages for plays).** Prod-replica measurement (48 h): **88.6% of tier-1
  `SyncLoyaltyCard` deliveries (1.59M rows) carried `id_location_origin =
  NULL`**, so every Nayax/DW200/payment-terminal play processed on core fanned
  out realtime to the WHOLE fleet (~36 NUCs) instead of its own cluster
  (~2–5) — the §10.3 origin-less rule applied to events that DO have an
  origin, ~12x volume inflation and peak-hour per-NUC drain overload. Root
  cause: the six `LoyaltyCardTransactionEngine` enqueue sites (DW200/Nayax
  confirmations incl. free-game, `processPaymentWithLoyaltyCard`,
  `applyCharges`) passed the CARD's home location — NULL for fleet-wide
  cards — not the play's location (the §11.2 "engines pass their location"
  note was inaccurate). Fixed: those sites now pass the transaction's
  `id_location` (populated at sale-request from the Nayax POS / Coolcode
  device / GatewayAuth request location; card home location kept only as
  fallback), `EventManager::restampActiveCards` passes the reservation's
  location, and the inbound reservation deactivate path passes the uploading
  shop's location. Deliberately still NULL (one-line comment at each site):
  the 4 admin `LoyaltyCardController` edits, `LoyaltyCardTierManager`
  recalculation, `LoyaltyMembershipManager` and `LoyaltyCardPublicManager`
  web/admin actions (no on-site event; card home location when set), and
  `OnlineTopupManager` when the payment carries no location (§10.10 resolver
  still open). Wire payload, delivery path, dedupe keys and tier resolution
  untouched — ONLY the enqueue origin argument changed. **Old-client shops
  are unaffected in correctness**: they receive the exact same single-card
  POSTs, now cluster-scoped — realtime within the origin's automatic cluster,
  nightly batch (tier 2) for the rest; cross-cluster freshness intentionally
  moves to the §10.5 batch window per the §10.3 design.
- **SHIPPED 2026-08-19 (kick economics — per-play kicks OFF, tier-1 rides a
  10s cron sweep; transport hard timeout).** Prod-replica measurement: the
  post-enqueue kick forked a full PHP CLI (`SyncOutboundDrain <idNuc> 1`) per
  realtime target per enqueue — the engine path kicked its whole cluster per
  play, **~400 forks/min sustained**, each ~1-2s of CLI boot mostly reporting
  "delivered 0" (row already taken); the boot stampede saturated CPU and
  real tier-1 latency was **60-120s avg / p95 ~3min** (nuc 52). Changes:
  `OutboundSyncQueueManager::KICK_ON_ENQUEUE = false` gates the enqueue and
  flushKicks kick paths (suspend/flush stays structurally intact; the
  heartbeat-recovery hook and admin retry-now/requeue call `kickDrainNuc`
  directly and still kick unconditionally); the crontab tier-1 line became
  SIX per-minute lines at 10s sleep offsets (one PHP boot per 10s drains ALL
  due NUCs; expected 5-15s steady-state, measured 5.0-8.5s on the dev pair);
  the idle sweep is cheap (single indexed `getListDueIdNuc` query) and now
  skips writing its `cron_job_status` row when zero NUCs were due (8640
  no-op rows/day otherwise — explicit single-NUC invocations always record);
  and `OutboundSendRequestSapiensClient` gained
  `CURLOPT_TIMEOUT = TIMEOUT_TOTAL_SECONDS` (30s) after two prod incidents
  where a half-open connection hung a drain forever (an advisory lock held
  indefinitely; the nightly tier-2 sweep starving every NUC with id > 69 for
  10 days behind half-dead NUC 69). Details in §13.7.

---

## 13. Capacity model & batch delivery (SHIPPED 2026-08-02)

### 13.1 Why: per-card POST limits

The drain's single-card transport is one HTTP POST per `SyncLoyaltyCard` row
(`syncLoyaltyCardNuc` → `genericSyncNuc`). Measured on the dev pair
(core + client containers, localhost transport): **~24 ms per single-card
POST** end-to-end (522 deliveries in ~12.5 s of drain time, ~42/s). Over the
production VPN the per-request RTT dominates and the observed budget is
**~10–20 deliveries/s/NUC**. That caps a NUC's catch-up rate: a shop coming
back from a day offline with 15k dirty cards needs 12–25 min of serial
POSTs — per NUC, every night, and the drain process is busy the whole time.

### 13.2 The 100-shop scenario

§8's worked example (F = 100 NUCs, E = 100k card events/day, D = 15k distinct
cards, k = 5 cluster size) leaves ≤ 1.4M **tier-2** coalesced deliveries/night
(D × (F − k)). Per-card that is ~14k serial POSTs per NUC per night (D per
NUC) = 12–25 min/NUC at prod rates — workable but brittle (one slow NUC's
window overruns). Batched at ≤ 100 cards/POST it is **~150 POSTs per NUC per
night**; the dev measurement for an 87-card batch is **~1.1 s per POST**
(client applies each card through the unchanged per-card path, ~12 ms/card),
so a full 15k-card catch-up compresses to **~3 min/NUC** and the request
count drops 87–100×. Tier-1 realtime volume (E' × k) stays per-card by
design — its load control is CLUSTER SIZING (k), and single-card latency is
what realtime is for.

### 13.3 Design shipped

- **Client endpoint** `POST /api/v1/loyalty-card/sync-batch`
  (`LoyaltyCardController::syncBatch` → `InboundGatewayLoyaltyCardManager::
  syncLoyaltyCardBatch`, same machine-auth as the single sync). The per-card
  apply is the UNCHANGED `syncLoyaltyCard()` path — version gate, per-card
  upload advisory lock (7301), rebase — looped, never reimplemented. Response
  `data.listResult` = one `{idLoyaltyCard, status}` per card:
  `applied` / `skipped` (version-gate stale — success) map to done on core;
  `locked` (upload in flight) / `error` map to RETRY. One card's failure
  never aborts the rest.
- **Core transport** `OutboundLoyaltyCardManager::syncLoyaltyCardBatchNuc`
  (BATCH_SIZE_MAX 100, payload per card identical to the single wire shape,
  via `genericSyncNuc` — which now additively exposes the response `data`).
- **Drain integration** (`drainSnapshot`): on a NUC whose reported
  `clientVersion` >= `OutboundSyncQueueManager::BATCH_SYNC_MIN_CLIENT_VERSION`
  (**2.1.0** — the client release shipping the endpoint), claimed
  `SyncLoyaltyCard` rows of a pass are grouped (≤ 100) into batch POSTs and
  the per-card listResult maps back to per-row markDone/markRetry. Rows are
  still CLAIMED individually before inclusion, so a drain dying mid-batch
  leaves ordinary stale PROCESSING rows for the §12 lease recovery. Below the
  version (or unreported): the untouched single path — no row ever waits on
  this gate (unlike LIST_COMMAND_MIN_CLIENT_VERSION it only picks transport).
  Version reporting is now actually wired: the client image CMD runs
  `ReportClientVersion` failure-tolerantly at boot and the client crontab
  re-reports daily at 04:45.
- **Kick dedup** (`OutboundSyncQueueManager::suspendKicks/flushKicks`): a
  request-scoped producer batch (inbound LCT sync) collecting N cards used to
  fork one tier-1 drain per enqueue — 200 cards × 20 NUCs = 4000 forks, each
  paying full CLI boot just to lose the advisory lock. `processBatch` now
  suspends kicks around its card-save loop and flushes ONE kick per distinct
  NUC (finally-guarded). Measured: 20-card batch → 20 forks before, **1**
  after. All other callers keep the immediate per-enqueue kick.
- **Retry observability**: `markRetry` records the failure reason (HTTP
  status / curl error / exception / per-card batch status, e.g.
  `batch status locked`) in `last_error`, left-500.

### 13.4 Measurements (dev pair, 2026-08-02)

| Path | 522 rows (6×87 passes) | HTTP requests | Per-delivery |
|---|---|---|---|
| Single (batch force-disabled) | 13.2 s wall / ~12.5 s delivery | 522 | ~24 ms |
| Batched | 7.2 s wall / ~6.4 s delivery | **6** | ~12 ms |

Localhost speedup is ~1.9× (client-side apply dominates when RTT ≈ 0); the
request-count reduction (87×) is the number that matters over the VPN, where
per-request RTT is the §13.1 bottleneck.

### 13.5 Remaining levers & thresholds

- **Set-based enqueue fan-out (§11.4)**: enqueue is still one pg-function
  call per target NUC in the producer's request path. Fine at dev/pilot
  scale; flip to a single set-based pg call when fleets reach ~50+ NUCs or
  producer-path enqueue latency becomes visible (100 NUCs ≈ 100 sequential
  pg calls per card event today).
- **§6.3 tier-forcing capability rule** (`pda_balance_sync_v2` → batch-tier
  card delivery) — unchanged, still open.
- **Batching other snapshot families**: the drain grouping is card-specific
  (`command == 'SyncLoyaltyCard'`). Products/users/config are low-volume;
  extend the same pattern (list endpoint + per-row result mapping) only when
  a family's tier-2 volume actually shows up in the drain summaries.

### 13.6 Upload ack carries card state (SHIPPED 2026-08-02)

Every NUC play upload used to produce a `SyncLoyaltyCard` echo row back to
the SAME NUC that already knows the outcome — for the origin, tier-1
realtime, i.e. the most expensive lane. The upload ack now carries each
touched card's final state (`listCardResult`) and a >= 2.2.0 client applies
it via the unchanged rebase while still holding its upload locks;
`excludeIdNuc` skips creating the origin's echo row (creation only —
pending rows with other news still deliver). Effect on the §8 model: the
origin's share of the tier-1 card fan-out disappears — realtime volume per
card event drops from k to k−1 (−1/cluster-size). Bonus: the §9 ack race
(snapshot landing while its plays are still sync=0) is structurally removed
for new clients on the upload path — the state travels IN the ack, inside
the lock, after the acked rows flipped sync=1, so the rebase set is exactly
the mid-upload plays.

### 13.7 Kick economics — per-play kicks OFF, 10s sweep (SHIPPED 2026-08-19)

The §4/§10.7 post-enqueue kick assumed forks are rare. They stopped being
rare: with the engine producers migrated, every core-processed Nayax/PT play
kicked one `SyncOutboundDrain <idNuc> 1` CLI per realtime target — measured
on a prod replica 2026-08-19 at **~400 forks/min sustained**. Each fork pays
~1-2s of PHP boot, and because sibling kicks for the same NUC lose the
advisory lock (or find the row already claimed), most report "delivered 0".
Net effect: the boot stampede saturated CPU and the "realtime" path was
SLOWER than a dumb poll — **60-120s avg enqueue→processed, p95 ~3min**
(nuc 52).

Shipped design:

- **`OutboundSyncQueueManager::KICK_ON_ENQUEUE = false`** — `enqueue()` and
  `flushKicks()` only fork while it is true. The §13 suspend/flush dedup
  machinery is untouched (harmless no-op when off). `kickDrainNuc()` itself
  stays live for its direct callers: the §12.2 heartbeat-recovery hook (a NUC
  coming back online drains immediately, not after up to 10s — cheap and
  rare) and the admin retry-now / requeue-dead actions.
- **Tier-1 fleet sweep every 10s** (utility/docker/crontab): six `* * * * *`
  lines at `sleep 0/10/20/30/40/50 &&` offsets running
  `SyncOutboundDrain 0 1`. ONE PHP boot per tick drains ALL due NUCs —
  ~8640 boots/day replaces ~576k forks/day at the measured rate. Expected
  steady-state latency for cron-swept deliveries: 5-15s (dev pair 2026-08-19:
  6.99s and 4.98s single-card on consecutive offset ticks, 8.3-8.5s for a
  6-card set delivered in one batch POST). Overlap-safe: per-(NUC,tier) advisory
  locks serialize adjacent ticks; the stale-claim recovery covers a tick
  dying mid-delivery.
- **Idle ticks are free and silent**: `SyncOutbound::getListDueIdNuc(1)` is
  one indexed `SELECT DISTINCT id_nuc WHERE tier AND status IN (1,4) AND
  next_attempt_at <= NOW()`; with zero due NUCs the command exits
  boot-dominated (0.07s wall on the dev pair; ~1-2s cold prod boot) and —
  new — writes NO `cron_job_status` row (8640
  no-op rows/day otherwise, 30-day retention notwithstanding). A sweep with
  ≥1 due NUC always records, even if it delivers 0; an explicit single-NUC
  invocation always records.
- **Transport hard timeout**: `OutboundSendRequestSapiensClient` had
  `CURLOPT_CONNECTTIMEOUT 3` but no total timeout — a half-open VPN
  connection hung the calling drain forever. Two prod incidents: a hung
  drain holding its per-NUC advisory lock indefinitely, and the nightly
  tier-2 fleet sweep hanging on half-dead NUC 69 every night, starving every
  NUC with id > 69 for 10 days. Now `CURLOPT_TIMEOUT =
  TIMEOUT_TOTAL_SECONDS` (30s — generous vs the ~1.1s worst measured batch
  POST). Single and batch paths both funnel through `sendRequest` (the only
  `curl_init` in the Outbound namespace), so one constant covers all
  deliveries.
- **Latency taxonomy after this change**: migrated-origin shops (client >=
  2.2.0) get their own card state instantly via the §13.6 upload ack — the
  sweep only carries cross-NUC fan-out, admin edits and top-ups, where
  5-15s is comfortably "realtime". Down-NUC recovery keeps its instant kick.
