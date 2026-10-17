# Handoff — Cloud Trace orchestration for `game_location_operation` (revised)

**Status:** design agreed with Salvatore (2026-07-02). Supersedes the previous version of this file.
**Sibling brief:** `sapiensclient/docs/trace-operational-block-handoff.md` — the NUC side. **Key inversion vs the earlier draft: the NUC blocks/unblocks payment terminals locally and autonomously. The cloud never signals block intent** — no `operational_hint` in the sync response, no cloud→NUC push channel. The cloud's job is Traces + a visibility mirror of the block state.
**Read first:** `sapienscore/CLAUDE.md`. There is also a canonical design doc on disk: `/pda-game-location-operation.md` — still the source of truth for schema and orchestration rules, **except where this brief corrects the wire shape (§4.1)**.

---

## 1. Why this exists

Every PDA-driven write can carry `needs_trace = 1` today; nothing consumes it. Remediations sync up from the NUC into cloud's `game_location_operation` table and `id_trace` is never populated; the admin "Trace link" panel renders empty. This brief builds the missing pipe:

1. **Sync receiver** — accepts `game_location_operation` rows from the NUC, persists idempotently, runs the Trace decision.
2. **Real-time orchestrator** — per operation: no Trace / append to open Trace / create new Trace, with aggregation rules that can force a Trace even when `needs_trace = 0`.
3. **Nightly batch command** — same aggregation swept over the last N days for slow-burn patterns.
4. **Response to the NUC** — per-row `idTrace` + `traceAction` for the local back-patch.
5. **Block mirror** — when an operation carries the operational assertion, reflect the NUC's local PT block on the cloud PT record so admin UIs and cloud-generated configs agree with the site (§4.6).

## 2. Prereqs — SHIPPED (do not re-build)

| Piece | Where |
| --- | --- |
| Cloud `game_location_operation` table | `utility/sql/sqlinstall00358.sql` |
| Cloud Model | `App/Model/Pda/GameLocationOperation.php` |
| NoDb enums | `App/Model/NoDb/Game/GameLocationOperationType.php`, `GameLocationOperationStatus.php`, `GameLocationOperationTechSubType.php` |
| Tech-op write path (cloud-native rows: `id_source = NULL`) | `App/Manager/Pda/Tech/PdaTechOperationManager.php` + `App/Controller/Pda/V1/Tech/TechOperationController.php` |
| Photo pipeline | `FileUpload::CATEGORY_PDA_PHOTO_REMEDIATION` + `CATEGORY_PDA_PHOTO_TECH_OPERATION` |
| Trace subsystem | `TraceManager`, `Trace`, `TraceUpdate`, NoDb `TraceScope/TraceType/TracePriority` |
| PT config pipeline | `PaymentTerminal::getTerminalLocalConfig()` (builders + `resolveDeviceStatus`), `OutboundPaymentTerminalManager::syncPaymentTerminalIfChanged`, `DeviceConfigSyncManager` |

## 3. Pattern reminders (mandatory)

- Controllers are thin pipes; the orchestrator lives in a Manager (`App/Manager/Pda/Trace/TraceOrchestrator.php`). Models own queries + `getStoreArray`.
- PHP 8.3, `array()` long form, braces, `T::t()` for every human string (Trace titles/descriptions/update messages included — keys under `game_location_operation.*` and `trace.*`).
- Auth for the sync endpoint: the existing NUC→cloud machine auth — the NUC sends `token` (= `SAPIENS_CORE_TOKEN` shared secret), `role`, `owner`, `idLocation` in the JSON body via `OutboundSendRequestSapiensCore`. Match whatever the existing SapiensClient inbound endpoints verify (`InboundAuthSapiensClientManager` area). **Don't invent a scheme.**

## 4. Scope

### 4.1 Sync receiver — match the SHIPPED client wire shape

The earlier draft specified a snake_case batch (`{list_operation: [...]}` → `{list_result: [...]}`). **The shipped NUC code does neither.** `OutboundGameLocationOperationManager::syncGameLocationOperation` (client repo) POSTs **one operation per request**, camelCase, to URL path `pda/game-location-operation/sync`, and back-patches from a camelCase response. Implement the receiver to match the client, not the old spec:

**Request** (per the client's payload builder — verify field-for-field against `OutboundGameLocationOperationManager` before coding): `idSource` (= NUC PK), `idGameLocation`, `idLocation`, `idUser`, `operationType`, `subType`, `comment`, `action`, `idAction`, `resolutionType`, `resolutionTargetType`, `idResolutionTarget`, amounts + currencies, `needsTrace`, `status`, `detail` (object), `sourceCreatedAt` — plus the auth fields (`token`, `role`, `owner`, `idLocation`).

**Response:**
```jsonc
{ "synced": true, "idTrace": 8123, "traceAction": 1, "syncedAt": "2026-07-02T14:32:11+02:00" }
```
`idTrace` null / `traceAction = SKIPPED` when orchestration decided no Trace.

- **Route**: wherever the existing SapiensClient→cloud inbound endpoints are registered (grep the existing inbound sync controllers and match — the client will hit `<base>/pda/game-location-operation/sync`).
- **Idempotency**: unique `(id_location, id_source)`. Duplicate resend → return the existing `idTrace` + `traceAction`, do **not** re-run orchestration. Update (e.g. status PENDING→CONFIRMED, or a `detail` change like the restore flag) → update the row; re-run orchestration only if it never ran; run the operational transition check (§4.6) always.
- Rows with `id_source` missing/null → reject (cloud-native rows never come through here).
- Stale FKs → persist with `detail.warning`, return `synced: true, traceAction: SKIPPED`. Sync must never 4xx on a dangling NUC pointer.
- **Don't run orchestration inside the write transaction.** Persist first, orchestrate after.

### 4.2 Real-time orchestrator

`TraceOrchestrator::orchestrate(GameLocationOperation $op): array` → `['idTrace' => ?int, 'traceAction' => int]`. Per row:

1. **Orchestrate at all?** `needs_trace = 1` OR aggregation fires (§4.3) OR the operational assertion is present (§4.5). Else `[null, SKIPPED]`.
2. **Find open Trace** for the game location: `Trace::getListByScope(TraceScope::GAME_LOCATION, $idGameLocation)` filtered to open-family statuses, `type = INCIDENT`. Found → `TraceUpdate::createMessage(...)` with a rendered summary → `APPENDED`. Not found → `TraceManager::createTrace(...)` → `CREATED`.
3. **Persist** `id_trace` + `trace_action` on the row before returning.

Title/description/update-message construction in `App/Helper/GameLocationOperation/OperationTraceRenderer.php`, shared by real-time, nightly and any backfill. All via `T::t`.

### 4.3 Aggregation rule (auto-escalation)

Trace even when `needs_trace = 0` if `COUNT(confirmed ops, same game location + type + sub_type, within window) >= threshold`. Settings via the existing location-setting cascade (org fallback): `pda_operation_aggregation_count` (default 3), `pda_operation_aggregation_window_days` (default 3). When fired, the Trace description says so explicitly, and priority is HIGH.

### 4.4 Nightly batch command

Same aggregation swept across the last N days (`App/Command/Pda/Trace/OrchestrateAggregatedTraces.php` or similar, cron-registered, low-traffic hour, idempotent on same-day re-run, uses the `WHERE trace_action IS NULL` partial index).

### 4.5 The operational assertion

Decided (proposed by the NUC brief, same field both sides): **`detail.operational`** on the operation. `0` = "game is not operational" (the NUC has already blocked the PT locally by the time this row arrives — `detail.ptBlocked: true` + `idPaymentTerminal` ride along). `1` = restore ("game works again"; the NUC has already unblocked). Absent = no signal.

When `operational = 0`:
- Orchestration is forced (never SKIPPED): create or append.
- Title/description/update message state the assertion and the local block ("PT blocked on site at HH:MM by <operator>") so the tech team reading the Trace knows why money stopped.
- Apply the block mirror (§4.6).

When `operational = 1` (restore row, or an update flipping the flag):
- Append the restore message to the open Trace and **resolve it** (normal Trace close path).
- Clear the block mirror (§4.6).

### 4.6 Block mirror (replaces the old push-channel section)

The NUC enforces the block; the cloud **mirrors** it so both sides agree:

- Store the mirrored state on the cloud PT record (recommended: a flag in the PT `detail` / config source read by the config builders — **not** `status = MAINTENANCE`, which is a human-managed state with its own semantics).
- The config builders (`buildSingleGlConfig` etc.) must emit `status: 'wait_for_service'` while the mirror is set — so a config regenerated for any reason (price change) is pushed down already-blocked, byte-consistent with the NUC's serve-time overlay. (The NUC overlay makes this non-load-bearing for safety — but the two sides should agree.)
- Clear the mirror on the restore transition; the next config push returns `status` to normal derivation.
- **Never send block/unblock commands toward the NUC.** No push endpoint exists; the NUC does not accept block instructions from cloud by design.

## 5. Don't do

- Don't create a new Trace subsystem — reuse `trace`/`trace_update`/`trace_member`/`trace_attachment`.
- Don't touch write-side PDA controllers.
- Don't emit `operational_hint` or build a cloud→NUC push/poll channel — dropped from the design.
- Don't hardcode enum values or English strings.
- Don't run orchestration inside the sync insert transaction.
- Don't 4xx on stale FKs.

## 6. Acceptance checklist

- [ ] Receiver matches the shipped client wire shape exactly (per-row, camelCase, `pda/game-location-operation/sync`); auth matches the existing NUC→cloud pattern.
- [ ] Idempotent on `(id_location, id_source)`; re-post returns existing `idTrace`/`traceAction` unchanged; updates re-check the operational transition.
- [ ] `id_source` null → rejected; stale FKs → persisted with `detail.warning`, `traceAction: SKIPPED`.
- [ ] Orchestration cascade: `needs_trace` OR aggregation OR `detail.operational` present; open-Trace dedup (never a duplicate Trace per game location).
- [ ] `OperationTraceRenderer` builds all human text via `T::t`.
- [ ] Two aggregation settings registered with defaults + org fallback.
- [ ] Nightly batch command, cron-registered, idempotent.
- [ ] `operational = 0` → forced orchestration + block mirror set + Trace text states the local block.
- [ ] `operational = 1` → Trace appended + resolved + mirror cleared.
- [ ] Config builders emit `wait_for_service` while the mirror is set; no push toward the NUC anywhere.
- [ ] PHP lint clean; layering per CLAUDE.md.
