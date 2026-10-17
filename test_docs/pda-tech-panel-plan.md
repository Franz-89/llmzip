# Plan (deferred) — PDA tech panel: device commands + real-time feed

**Status: NOT scheduled.** Studied 2026-07-11, deliberately deferred — the
open questions in §5 need answers from shop reality before building.
Everything below was verified against the code on that date; re-verify
entry points before implementing.

## 1. The idea

A technician scans a game's QR during maintenance and gets a tech-only
panel: send test commands (start game, pay N paper tickets, reboot /
block / unblock the payment terminal, handshake / status / restart the
pulse box) and optionally watch the device's real-time activity feed.
Value: the tech is physically at the machine with the PDA in hand.
Counter-argument (why deferred): planned maintenance usually comes with
a laptop, and `/pulse-box/monitor` (NUC) + `/device-monitoring` (cloud)
are richer tools that already exist.

## 2. What already exists (verified)

**Commands — every wished command has a proven implementation:**

| Command | Mechanism (NUC) |
|---|---|
| Start game | `PulseSenderManager::startGame($pulseBox, $payoutMode)` |
| Pay N paper tickets | `PulseSenderManager::payTicketPaper($pulseBox, $n)` |
| Reboot / block / unblock PT | `DeviceCommandManager::runPaymentTerminalCommand(mac, 'reboot'\|'block_device')` |
| Handshake / status / restart pulse box | `DeviceCommandManager::runPulseBoxCommand(mac, [...])` |

Whitelists live in `sapiensclient App/Controller/Admin/PulseBox/PulseBoxCommandController`
(`ALLOWED_PULSE_BOX_COMMAND`, `ALLOWED_TERMINAL_COMMAND`, `ALLOWED_DATA_KEY`)
— share these constants, don't duplicate.

**Cloud → device channel (fleet-wide, zero NUC changes):**
`DaemonCoreClient` (sapienscore) → daemon-core → persistent upstream
connection from every NUC's daemon-pulse → device.
- `sendCommand(mac, command)` → `POST /api/v1/send-command` (daemon-core
  resolves the device's location from its fleet device store).
- `getLocationDevice($idLocation)` → live device list + online status.
- Ack semantics: "delivered to the location's daemon", NOT "device
  executed". Good enough for plumbing buttons; the panel's status
  refresh shows the effect.

**Cloud → NUC PHP relay (synchronous, full result):**
`OutboundGenericRequestManager::genericSingleLocationRequest($owner, $builder, $idLocation)`
→ authenticated HTTP to the location's primary NUC.

**PDA entry point:** `ScanIdentifyManager` (sapiensclient) builds
per-userType action lists on scan — add a tech-gated action there.
Android `User.canAccessMaintenance()` (userType ≥ IT_SUPPORT_TECH)
mirrors the gate for UI purposes; the server check is authoritative.

## 3. Decided architecture (if/when built)

One cloud contract for the PDA — `/pda/tech/panel` + `/pda/tech/command`
in `routesPdaApi.php`, `Permission::TECH_SUPPORT` checked like
`TechOperationController:submit` — with a dispatcher that picks the
transport per command class:

- **Device plumbing** (reboot/block/unblock PT, handshake/status/restart
  pulse box): `DaemonCoreClient::sendCommand` — stateless toward the NUC
  DB, works fleet-wide today, and is the natural path for future no-NUC
  games (they will connect to daemon-core directly).
- **Business ops** (start game, pay tickets): MUST run through NUC PHP
  (`genericSingleLocationRequest` → small NUC receiver → the
  PulseSenderManager methods). NEVER send raw pulses from the cloud:
  `startGame` writes `start_game_history` + payout records BEFORE
  pulsing — a pulse without records is a phantom game that surfaces as a
  counter discrepancy. For no-NUC games these ops need a cloud-side
  executor (plugged into the same dispatcher) since there is no NUC DB.
- **Panel data**: `DaemonCoreClient::getLocationDevice`.

**Non-negotiable guardrails:** server-side permission check (never trust
the app), confirmation dialogs, a cap on paper-ticket count, and an
audit log of every command (user + device + command + result —
`DebugLog` scope or a GLO row; commands print real tickets and fire
real pulses).

## 4. Phase 2 — real-time feed on the PDA (even more deferred)

Content exists: `PulseActivityBroadcaster` (NUC) emits coin inserts,
EMV/loyalty payments, game start/end, ticket req/resp, errors per MAC;
daemon-pulse masters subscribe with per-event filters
(`subscribe: ['pulse_box_activity', ...]`).

Blocker to solve first: daemon auth is a single shared `TOKEN_DAEMON`
server secret — never embed it in the APK. Design sketch: a NUC/cloud
endpoint mints a short-lived scoped ticket; `verifyMasterToken` (daemon)
accepts tickets as receive-only masters with forced subscribe filters.
OkHttp (already in the app) does websockets natively. Cloud-side
alternative: daemon-core's monitor socket + `publishToUsers`.

## 5. Open questions — answer BEFORE building

1. **Do business ops belong on the PDA at all?** The cloud
   `/device-monitoring/location/{id}` page may be the better home for
   start-game/pay-tickets (bigger screen, already exists). If so the PDA
   panel shrinks to plumbing commands only — much smaller build.
2. **Block/unblock semantics**: today `block_device` is a NON-BLOCKING
   status toggle on the terminal. Define what a tech expects "block"
   to guarantee before exposing a button that implies more than it does.
3. **Demand**: does any tech actually ask for this? Ship nothing until a
   tech's real complaint defines the MVP (that also decides Phase 2).
