# Guide — `game_location_operation` cloud receiver + Trace orchestration

**Audience:** sapienscore agent implementing the cloud side of a new PDA-driven feature.
**Counterpart:** sapiensclient (NUC) holds a local-first copy of the table for offline-capable operations and pushes them up. The cloud table is **canonical** — it also receives writes directly from cloud-only features (e.g. cash collection).

---

## 1. Context

A new table `game_location_operation` is being added in **both** systems:

- **Sapiensclient (NUC):** local-first for operations the PDA can perform offline.
- **Sapienscore (cloud):** canonical for the company. Receives sync from each NUC **and** is written directly by cloud-only features.

It records actionable events on a `game_location`:

- **v1 (NUC + cloud):** `CUSTOMER_ISSUE` — customer paid but the game failed; operator remediates via REVERT or REENABLE.
- **Reserved for later (cloud-only):** `CASH_COLLECTION` (deliberately cloud-only — too complex offline), `TECH_OPERATION`.

So the cloud table is **not just a sync mirror** — it's also the source of truth for cloud-originated operations. Schema reflects both origins (see `id_source` nullability in §2.2).

A background command on sapiensclient batches operations and POSTs them to sapienscore. The cloud is responsible for:

1. **Receive sync** — persist rows that originated on a NUC, idempotent on resend.
2. **Own cloud-originated rows** — `CASH_COLLECTION` and future cloud-only operations insert directly into the same table (`id_source` and `source_created_at` left NULL).
3. **Trace orchestration** — for **both** origins: decide whether to open a new Trace, append a comment to an existing one, or do nothing. Includes **aggregation rules** (e.g. "3 same-type operations in 3 days → force Trace even if `needs_trace=0`").
4. **Report back** — per-operation outcome so sapiensclient can set `synced_at`, `id_trace` (sync path only).

The PDA operator never interacts with Trace directly. The cloud is the brain.

> **Future note (not v1):** a cloud-PDA may eventually need to perform `CASH_COLLECTION` while the venue is offline. That'll require a small local SQLite/file cache on the cloud-PDA side that buffers writes and replays them on reconnect. Schema below is already shaped to accommodate that — origin columns are nullable and the cloud PK is independent of the NUC PK.

---

## 2. Naming (canonical — do not invent variants)

### 2.1 Table

Name: **`game_location_operation`** (same name as the local sapiensclient table; this is the canonical cloud copy and also the home for cloud-originated rows).

### 2.2 Columns

| Column                              | Type      | Notes                                                                  |
| ----------------------------------- | --------- | ---------------------------------------------------------------------- |
| `id_game_location_operation`        | int PK    | Cloud-side PK, independent of any NUC PK                               |
| `id_source`  | int NULL  | The PK from the originating NUC. NULL for cloud-originated rows. Combined with `id_location` forms the idempotency key |
| `id_game_location`                  | int FK    | Indexed                                                                |
| `id_location`                       | int FK    | Indexed                                                                |
| `id_user`                           | int FK    | Operator who performed it                                              |
| `operation_type`                    | int       | See enum below                                                         |
| `sub_type`                          | int       | Per `operation_type`                                                   |
| `comment`                           | text NULL | Mandatory when `sub_type = OTHER`                                      |
| `action`                            | int       | What kind of entity is the source (LOYALTY_CARD_TRANSACTION, etc.)     |
| `id_action`                         | int       | PK in that entity's table                                              |
| `resolution_type`                   | int       | NONE / REVERT / REENABLE                                               |
| `resolution_target_type`            | int NULL  | Per `resolution_type`                                                  |
| `id_resolution_target`              | int NULL  | PK in the target table                                                 |
| `original_amount`                   | decimal   |                                                                        |
| `original_currency`                 | varchar 3 |                                                                        |
| `resolution_amount`                 | decimal NULL |                                                                     |
| `resolution_currency`               | varchar 3 NULL |                                                                   |
| `needs_trace`                       | smallint  | 0/1 (never `bool` — we use smallint for query speed). Hint from sapiensclient; cloud may override via aggregation rules |
| `id_trace`                          | int NULL  | Set by cloud after orchestration                                       |
| `trace_action`                      | int NULL  | `NONE=0`, `CREATED=1`, `APPENDED=2`, `SKIPPED=3`                       |
| `detail`                            | jsonb     | Non-indexed extras                                                     |
| `status`                            | int       | PENDING=1, CONFIRMED=2, CANCELLED=3                                    |
| `source_created_at`                  | datetime NULL | When it was created on the NUC; NULL for cloud-originated rows     |
| `synced_at`                         | datetime NULL | When cloud accepted it; NULL for cloud-originated rows (never synced) |
| `created_at`, `created_by`, `modified_at`, `modified_by` | audit | Standard sapienscore audit columns                         |

**Unique key**: `(id_location, id_source)` — required for idempotent resend. Each location has exactly one NUC, so `id_location` is enough to disambiguate the source. `id_source` being NULL is allowed (cloud-originated rows); in Postgres NULLs are distinct by default so multiple cloud-originated rows on the same location won't collide. Same in MySQL (NULL ≠ NULL in unique indexes). If the deployment engine differs, use a partial unique index `WHERE id_source IS NOT NULL`.

**Indexes**:
- `(id_game_location, source_created_at)` — list per game-location
- `(action, id_action)` — "is this transaction already remediated?"
- `(operation_type, sub_type, id_game_location, source_created_at)` — aggregation queries
- `(id_trace)`
- `(id_location, source_created_at)` — per-location reporting

### 2.3 Enums (int values — must match sapiensclient exactly)

Place under `App/Model/NoDb/GameLocationOperation/` following the existing pattern (cf. `App/Model/NoDb/Trace/TraceType.php`).

**`OperationType`**
```
CUSTOMER_ISSUE    = 1
CASH_COLLECTION   = 2   // reserved
TECH_OPERATION    = 3   // reserved
OTHER             = 99
```

**`CustomerIssueSubType`** (used when `operation_type = CUSTOMER_ISSUE`)
```
GAME_DIDNT_START      = 1
GAME_STOPPED_MIDPLAY  = 2
WRONG_GAME_STARTED    = 3
OTHER                 = 99
```

**`OperationAction`** (the polymorphic FK type for `action` + `id_action`)
```
NONE                          = 0
LOYALTY_CARD_TRANSACTION      = 1
PAYMENT_TERMINAL_TRANSACTION  = 2
```

**`ResolutionType`**
```
NONE      = 0
REVERT    = 1
REENABLE  = 2
```

**`ResolutionTargetType`**
```
NONE                       = 0
LOYALTY_CARD_OPERATION     = 1   // when resolution_type = REVERT
GAME_LOCATION              = 2   // when resolution_type = REENABLE (the new game)
```

**`OperationStatus`**
```
PENDING    = 1
CONFIRMED  = 2
CANCELLED  = 3
```

**`TraceAction`** (cloud's record of what it did for this operation)
```
NONE      = 0
CREATED   = 1
APPENDED  = 2
SKIPPED   = 3
```

---

## 3. API endpoint to expose

### 3.1 Route

`POST /local/api/v1/pda/game-location-operation/sync`

Follow the existing routing pattern (cf. `src/routesAdminLocalApi.php`). Auth: the existing sapiensclient → sapienscore bearer used elsewhere (not `CLIENT_TRACE_BEARER_TOKEN`; this is its own service).

### 3.2 Request

```json
{
  "list_operation": [
    {
      "id_source": 42,
      "id_game_location": 880,
      "id_location": 12,
      "id_user": 305,
      "operation_type": 1,
      "sub_type": 1,
      "comment": null,
      "action": 2,
      "id_action": 99102,
      "resolution_type": 2,
      "resolution_target_type": 2,
      "id_resolution_target": 882,
      "original_amount": 4.00,
      "original_currency": "EUR",
      "resolution_amount": 4.00,
      "resolution_currency": "EUR",
      "needs_trace": 1,
      "status": 2,
      "detail": { "price_ratio_used": 1.5, "operator_note": "..." },
      "source_created_at": "2026-06-23T14:32:11+02:00"
    }
  ]
}
```

### 3.3 Response

```json
{
  "list_result": [
    {
      "id_source": 42,
      "synced": true,
      "id_trace": 8123,
      "trace_action": 1
    }
  ]
}
```

`trace_action` uses the `TraceAction` enum int. `id_trace` is null when `trace_action` is `NONE` or `SKIPPED`.

### 3.4 Idempotency

Applies to NUC-synced rows only (`id_source` is NOT NULL in the payload; `id_location` always is). Cloud-originated rows go through their own service path, not this endpoint.

If `(id_location, id_source)` already exists:

- If the existing row is identical: return its current `id_trace` + `trace_action` without re-running orchestration.
- If sapiensclient sent fields that changed (e.g. status moved PENDING→CONFIRMED): update, then re-run Trace orchestration only if it hasn't been run yet.

Never throw 4xx on a duplicate — that's the happy path of a retry.

---

## 4. Trace orchestration

Run after persisting each operation in the request batch.

### 4.1 Should we orchestrate at all?

Orchestrate when **either** condition is true:
- `needs_trace = 1` from sapiensclient, **or**
- Aggregation rule fires (see 4.3).

Otherwise: `trace_action = SKIPPED`, `id_trace = null`.

### 4.2 Find existing open Trace

```
Trace::getListByScope(
    scope = TraceScope::GAME_LOCATION,
    idScope = $operation->id_game_location
)
```

Filter to `status ∈ {OPEN, IN_PROGRESS, WAITING}` and `type = INCIDENT`.

- **Found** → append `TraceUpdate::createMessage(...)` with a rendered summary (operator name, sub_type, resolution_type, amounts).
  Set `id_trace`, `trace_action = APPENDED`.
- **Not found** → continue to 4.3.

### 4.3 Aggregation rule (auto-escalation)

Even if `needs_trace = 0`, **create** a Trace when:

```
COUNT(operations) >= aggregation_count
WHERE id_game_location = X
  AND operation_type = Y
  AND sub_type = Z
  AND source_created_at >= NOW() - aggregation_window_days
  AND status IN (CONFIRMED)
```

Settings (location-level, organization fallback — see §6):
- `pda_operation_aggregation_count` (default 3)
- `pda_operation_aggregation_window_days` (default 3)

When the rule fires, the Trace `description` should mention the aggregation count + window so the human reading it understands why it was opened automatically.

### 4.4 Create new Trace (when no open one + either `needs_trace=true` or aggregation fired)

Use `TraceManager::createTrace(...)` with:
- `scope = GAME_LOCATION`
- `id_scope = id_game_location`
- `id_location = id_location`
- `type = INCIDENT`
- `title` = rendered summary (e.g. "Game didn't start — operator remediated REENABLE")
- `description` = full breakdown + aggregation reason if applicable
- `id_reporter` = operation's `id_user`
- `priority` = derive from sub_type (MEDIUM by default; HIGH when aggregation rule fired)
- `operational_status` = follow existing GameLocation incident defaults

Set `id_trace`, `trace_action = CREATED`.

### 4.5 What goes in the Trace message / description

Render once in PHP, server-side (don't dump JSON). Suggested format:

> *Operator: Jane Smith • Sub-type: GAME_DIDNT_START*
> *Resolution: REENABLE → Game-location #882 (4.00 EUR)*
> *Source transaction: PAYMENT_TERMINAL_TRANSACTION #99102 (4.00 EUR)*

Helper class suggestion: `App/Helper/GameLocationOperation/OperationTraceRenderer.php`.

---

## 5. What to reuse — do not reinvent

- **`App/Manager/Trace/TraceManager.php`** — `createTrace()`, `addMessage()`.
- **`App/Model/Trace/Trace.php`** — `getListByScope()` is the existing scope query.
- **`App/Model/NoDb/Trace/TraceScope.php`** — `GAME_LOCATION` constant.
- **`App/Model/NoDb/Trace/TraceType.php`** — `INCIDENT` constant.
- **`App/Model/NoDb/Trace/TraceStatus.php`** — active-status helpers.
- **`Login::currentUser()` / `Login::currentLocation()`** — for context.
- **Settings cascade pattern** — `Location::getSettingByType()` already merges Organization → Location (see `App/Model/Location/Location.php`). Extend the same pattern to pull our new keys.

---

## 6. Settings

Add the following keys to the existing `location_setting` system (Organization fallback already wired). For v1, **Owner-level cascade is not required** — Organization-level is enough; we can add Owner later when needed.

| Key                                           | Type   | Default | Used by      |
| --------------------------------------------- | ------ | ------- | ------------ |
| `pda_remediation_window_hours`                | int    | 1       | sapiensclient (gates which transactions are actionable) |
| `pda_reenable_price_ratio_max`                | float  | 1.0     | sapiensclient (EMV reenable rule) |
| `pda_loyalty_revert_lock_buckets`             | smallint | 1     | sapiensclient (REVERT must restore same buckets — 0/1) |
| `pda_loyalty_allow_reenable`                  | smallint | 0     | sapiensclient (whether REENABLE option is shown for loyalty — 0/1) |
| `pda_operation_aggregation_count`             | int    | 3       | **cloud** (Trace auto-escalation) |
| `pda_operation_aggregation_window_days`       | int    | 3       | **cloud** (Trace auto-escalation) |

Sapiensclient resolves its own settings and ships the **resolved values inline with the action** in the PDA API response. The cloud only consumes its own two aggregation settings.

---

## 7. Edge cases

- **Replay of an already-orchestrated operation:** return the existing `id_trace`/`trace_action` unchanged. Do NOT post a second `trace_update`.
- **Operation arrives with `status = CANCELLED`:** still mirror, but skip Trace orchestration. If a Trace was already created on a previous sync, post a `trace_update` saying the operation was cancelled.
- **Operation references a non-existent `id_game_location`:** persist with a flag in `detail.warning`, return `synced = true`, `trace_action = SKIPPED`. Do not 4xx (a NUC sync should never fail because of stale FKs).
- **Out-of-order arrival** (a CANCELLED arrives before the CONFIRMED): apply the latest by `modified_at_local` (sapiensclient should send it; add the field to the request shape if needed).

---

## 8. Acceptance checklist

- [ ] Migration creates `game_location_operation` with the columns and indexes above; `id_source`, `source_created_at`, `synced_at` all NULLABLE
- [ ] Unique constraint on `(id_location, id_source)` permits multiple NULL `id_source` per location (cloud-originated rows)
- [ ] NoDb enum classes for every enum in §2.3
- [ ] Route + controller `POST /local/api/v1/pda/game-location-operation/sync`
- [ ] Idempotent insert/update keyed on `(id_location, id_source)` for sync path
- [ ] Service-layer write path for cloud-originated rows (NULL `id_source`) — used by the future cash-collection feature; shape now even if no caller in v1
- [ ] Trace orchestration logic runs for both origins (existing-open lookup → aggregation rule → create or append)
- [ ] `OperationTraceRenderer` helper for the message/description text
- [ ] Two new keys in `LocationSetting` cascade: `pda_operation_aggregation_count`, `pda_operation_aggregation_window_days`
- [ ] Response shape exactly as in §3.3 (sapiensclient parses by these names)
- [ ] Replay of an already-orchestrated operation does not create duplicate `trace_update` rows
- [ ] PHP lint clean (`php -l`)

---

## 9. What sapiensclient does (for your awareness)

Not your scope to implement, but useful context:

1. PDA → sapiensclient creates a local `game_location_operation` row in a transaction (`status = CONFIRMED`, `needs_trace` set based on sub_type + setting), and for REVERT also writes a compensating `loyalty_card_operation`.
2. After the local commit, a **fire-and-forget call** to the sync command runs.
3. A cron also runs the sync command every N minutes as a fallback for offline periods.
4. The sync command POSTs all rows with `synced_at IS NULL` (or `id_trace IS NULL AND needs_trace = TRUE`) to your endpoint, then updates each local row from the response.
