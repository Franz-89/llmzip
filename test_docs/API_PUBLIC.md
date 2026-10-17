# Public API — v1 contract (NUC plane)

Partner/integration API for venue operators who run their own systems (POS, membership software, hotel PMS) and integrate loyalty-card operations against **their own NUC** (the sapiensclient on-premise server). This document is the wire contract; it lives in sapienscore's docs because the API will eventually exist on both planes (NUC + core cloud), with identical shapes. **v1 ships on the NUC only.**

- **Audience:** the operator's integration developer. They receive a token from us (or from the operator's admin UI, later), call the NUC over the venue LAN (or the NUC's tunnel hostname), and never see sapienscore internals.
- **Runtime target:** sapiensclient (`../sapiensclient`), Slim 3, same app the kiosk/PDA/payment-terminal APIs run on.
- **Business case driving v1:** operator's POS sells a top-up → POS calls the NUC → balance applies locally in real time → existing sync machinery pushes the sale + card state to core. Card lookup, balance, history, and package catalog support that flow.

Design decisions in this document are **locked**: separate route file, per-integrator token + scopes, thin controllers over existing managers, dedicated DTOs, house vocabulary on the wire, v2 response envelope, `Idempotency-Key` header, ISO-8601 timestamps, decimal-string money, additive-only versioning.

**How to read the kiosk/PDA references in this doc.** Nothing in the kiosk/PDA/payment-terminal APIs is modified. References come in three kinds:
1. **Shared services the new endpoints call** (`LoyaltyCardDataService`, `PaymentLocationService`, `SellerLoyaltyCardManager`, `PdaLoyaltyCardHelper::resolveCard`/`validateForUse`) — generic loyalty/payment machinery that kiosk/seller flows also use; the public API is one more caller, so POS and kiosk top-ups share one write path.
2. **Patterns to imitate against new public-API-owned tables** (`KioskOperation::getOneByTransactionRef` → idempotency lookup-first; kiosk `CardController::timeline` → core-preferred/local-fallback; `PdaSessionManager::validateToken` → token hashing).
3. **Anti-examples, named so they are not reused** (device response builders, per-method `protectAccess()`).

Everything new is public-API-owned: `src/routesPublicApi.php`, `App/Controller/PublicApi/V1/`, `App/DTO/PublicApi/`, the `api_integrator` + `public_api_request` tables, the middleware.

---

## 1. Authentication

### Token model (to be built — no per-integrator mechanism exists today)

There is **no per-consumer token system on the client today**; it must be built for this API. Existing precedents, closest first:

| Mechanism | Where | Pattern |
|---|---|---|
| Per-device token | `App/Manager/API/Kiosk/KioskAuthManager.php`, `PaymentTerminalAuthManager` | device row in DB holds a token; request carries `deviceName` + token; compared per request |
| Per-user session token | `App/Manager/API/Pda/PdaSessionManager.php` (`validateToken`, `hash_equals`) | opaque random token, validated against a session table |
| Install-wide shared secret | `App/Manager/API/GatewayAuth/Inbound/InboundGatewayAuthManager.php` | `OWNER`/`DEVICE_NAME`/`DEVICE_TOKEN` env constants — core→client sync auth. **Not usable** for integrators (one secret per install, no revocation, no scoping) |

**v1 mechanism:** a new `api_integrator` table on the client (snake_case, singular, PK `id_api_integrator` per `/CODING_STANDARDS.md`):

- `name` — the integrator ("Venue POS — Vendus bridge").
- `token_hash` — SHA-256 of an opaque random token. The plaintext is shown once at issuance; validation is `hash_equals(hash('sha256', $presented), $tokenHash)` — same discipline as `PdaSessionManager::validateToken`.
- `list_scope` (jsonb) — granted scopes, see below.
- `status` (active/disabled) + audit fields (`created_at`, `created_by`, `last_used_at`).

Issuance is operator-side admin work (v1: created by us/support via a CLI command or admin page on the NUC; self-service UI is out of scope). Tokens are revoked by flipping `status` — no expiry in v1.

### Header

```
Authorization: Bearer <token>
```

Header-based (not body params like the device APIs) — integrators expect standard Bearer auth, and it keeps credentials out of request logs/bodies.

### Scopes

| Scope | Grants |
|---|---|
| `loyaltyCard.read` | card lookup, balances, timeline |
| `loyaltyCard.topup` | top-up execution |
| `package.read` | package catalog |
| `customer.read` | linked-customer lookup |

Every endpoint declares its required scope. A valid token without the scope → HTTP 403, error envelope with `message`. Scopes are an allowlist: the middleware maps route → scope explicitly; an endpoint not in the map is unreachable through this stack regardless of token.

### Middleware stack

The public API gets its **own middleware**, attached to the Slim route group (not the per-method `protectAccess()` calls the device controllers use — that pattern predates group middleware and shouldn't be extended):

1. `PublicApiAuthMiddleware` — resolves Bearer token → `ApiIntegrator`, checks status + scope for the matched route, sets `Login::setCurrentUser(Cache::getUser(API))` (same as `public/index.php` does for device APIs), stamps `last_used_at`.
2. `PublicApiJsonMiddleware` — guarantees JSON error envelopes for uncaught exceptions (no HTML error pages leaking to integrators).

Failures: missing/invalid token → 401; disabled integrator → 401; missing scope → 403. All with the error envelope.

**Wiring note:** route files load per-domain via `Domain::currentDomain()->getListRoutFile()` (see `sapiensclient/public/index.php`); the new `src/routesPublicApi.php` must be added to the domain's route-file list, and `public/index.php` needs a `/public-api` branch that skips the browser-session bootstrap (same treatment as the `api/kiosk` / `api/v1/pda` branches at line ~128).

---

## 2. Conventions

### Base path and versioning

```
/public-api/v1/...
```

Versioned path. **Within v1, changes are additive only** — new endpoints, new optional request fields, new response fields. Field removal or meaning change requires `/public-api/v2/...`. Integrators must ignore unknown response fields.

### Vocabulary (house rules — the wire speaks them too)

- IDs: `idLoyaltyCard`, `idLoyaltyCardPackage`, `idUser`, `idPaymentLocation` — never `cardId`/`userId`.
- Lists: `listPackage`, `listEntry`, `listTransaction` — never `packages`/`entries`.
- Single items: `loyaltyCard`, `package`, `customer`.

### Response envelope

**Reads (GET):** plain payload — a single object or a list. No wrapper.

**Writes (POST), success:**

```json
{ "status": "success", "idPaymentLocation": 9241, "...": "..." }
```

**Errors (reads and writes):**

```json
{
  "status": "error",
  "errors": { "idLoyaltyCardPackage": "not_found" },
  "message": "Package not found or not sellable on this channel"
}
```

- `errors` is field-keyed with short machine codes (`required`, `invalid`, `not_found`, `mismatch`, `insufficient`); present when the error maps to request fields.
- `message` is an optional human-readable summary (English in v1; not for end-customer display).
- Always `status: 'success' | 'error'` — never `ok: true/false`, never the internal `{success, data, message}` device-API shape (`PaymentTerminalResponseBuilder` / `InboundGatewayResponseBuilder` are **not reused** here — they emit `success` booleans and `exit`; the public API returns proper PSR responses).

### HTTP status codes

| Code | When |
|---|---|
| 200 | success (reads and writes, including idempotent replays) |
| 400 | malformed request / validation failure |
| 401 | missing/invalid/disabled token |
| 403 | valid token, missing scope |
| 404 | resource not found (card, package) |
| 409 | `Idempotency-Key` reuse with a **different** payload |
| 500 | unexpected server error (JSON envelope, no HTML) |

### Money

```json
{ "amount": "12.50", "currency": "EUR" }
```

- `amount` is a **decimal string**, two decimals, dot separator — never a float (JSON floats corrupt cents).
- `currency` is the ISO code. Per `/CURRENCY.md` rules 1–3 and 8: the deployment has exactly one currency; the client reads it from the **synced `system_setting`** (pushed by core at initNuc), never from a request. Request money objects (top-up `price`) must therefore **match** the install currency or the write is rejected with `errors: {"price": "currency_mismatch"}` — the field exists on the wire for explicitness and receipt-grade auditability, not for selection.
- Non-money balances are not money objects: `timeSecond` is an integer (seconds), `ticket` is a number.

> **Dependency:** the client-side `system_setting` table + currency accessor is CURRENCY.md slice 5, being built separately. Until it lands, implementation would have to fall back to EUR — ship this API after (or together with) that slice.

### Timestamps

ISO-8601 with offset: `"2026-07-04T11:02:33+02:00"`. (Internal models store epoch/DB timestamps; DTOs format at the edge.)

### Idempotency (writes)

Every write requires the header:

```
Idempotency-Key: <caller-generated unique string, max 100 chars>
```

- **Header, not a request field** — recommended because the existing dedup machinery is a caller-supplied unique string persisted on the operation record and looked up first (`KioskOperation::getOneByTransactionRef` in `App/Controller/GatewayAuth/API/Kiosk/V1/TransactionController::submit`; `LoyaltyCardTransaction::getOneByTransactionIdNAction` on the game side). The transport of that string is free — a header keeps the body a pure domain payload and matches integrator expectations (Stripe-style).
- Semantics: first request executes and the result is stored keyed by `(idApiIntegrator, idempotencyKey)`; a retry with the same key and same payload returns the **original result** (HTTP 200, same body) and **never double-applies**; the same key with a different payload → 409.
- Missing header on a write → 400 `errors: {"idempotencyKey": "required"}`.
- Keys are scoped per integrator and retained ≥ 7 days.

### Pagination

List reads use `page` (1-based) + `limit` query params and return `page`, `limit`, `hasMore` alongside the list — the exact shape `LoyaltyCardDataService::getHistory` / `getUnifiedTimeline` already produce. No cursors in v1.

### Controllers, managers, DTOs

- Controllers under `App/Controller/PublicApi/V1/...` are **passing points**: parse → manager/service → DTO → response. No business logic.
- Business logic stays in the existing managers/services named per endpoint below — the public API adds **no parallel write path**.
- External shapes are built by dedicated DTOs under `App/DTO/PublicApi/...` — never raw `getStoreArray()`, never the internal service arrays as-is (they leak floats and internal fields). DTOs are where money becomes decimal strings and timestamps become ISO-8601.

---

## 3. Endpoints

### 3.1 Card lookup — `GET /public-api/v1/loyalty-card/lookup`

Scope: `loyaltyCard.read`

Resolve a physical card to its identity + balances. Exactly one identifier strategy per call, resolved in this priority (mirrors `PdaLoyaltyCardHelper::resolveCard` + the seller track path):

| Query param(s) | Resolution |
|---|---|
| `uid` | NFC UID as hex (e.g. `F77284C4`); server does `hexdec` → `LoyaltyCard::getOneByUidDecimal` |
| `cardNumber` + `track` | track → context (`LoyaltyCardContext::getByTrackNOwner`) → `LoyaltyCard::getOneByCardNumberNContext` |
| `cardNumber` | `LoyaltyCard::getOneByCardNumber` |

**Response 200** (plain payload):

```json
{
  "idLoyaltyCard": 100234,
  "cardNumber": "104211",
  "uid": "F77284C4",
  "track": "0017",
  "status": "active",
  "registered": true,
  "isService": false,
  "balance": {
    "credit": { "amount": "23.50", "currency": "EUR" },
    "bonus": { "amount": "4.00", "currency": "EUR" },
    "courtesy": { "amount": "0.00", "currency": "EUR" },
    "timeSecond": 0,
    "ticket": 120
  },
  "tier": {
    "current": "gold",
    "currentLabel": "Gold",
    "next": "platinum",
    "nextLabel": "Platinum",
    "remaining": { "amount": "76.50", "currency": "EUR" }
  },
  "lastUserActionAt": "2026-07-03T19:41:07+02:00"
}
```

- `status` is a string key (`active`, `available`, `disabled`, `cancelled`) mapped from `LoyaltyCard::STATUS_*` — integrators never see raw enum ints. Cards in internal states (`STATUS_MAP`, `STATUS_DELETED`) resolve as 404 — they don't exist as far as an integrator is concerned.
- `balance.credit` is the **combined** spendable credit (regular + VAT-postponed, i.e. `getBalanceCredit()` default) — the VAT split is internal accounting, not an integrator concern.

**Errors:** 400 when no identifier param given (`errors: {"uid": "required"}`); 404 when nothing resolves (`errors: {"loyaltyCard": "not_found"}`).

**Implementation notes**
- Lookup: `sapiensclient/App/Helper/Pda/PdaLoyaltyCardHelper.php` (`resolveCard`), `sapiensclient/App/Manager/Seller/SellerCardManager.php` (`getCardDetail` — the cardNumber+track path).
- Payload source: `sapiensclient/App/Service/LoyaltyCard/LoyaltyCardDataService.php` (`getInfo`) — built exactly for "any future consumer"; the public DTO reshapes its array (floats → money objects, status int → key, drop `email`/`phone`/`totalCreditUsed`).

### 3.2 Card timeline — `GET /public-api/v1/loyalty-card/{idLoyaltyCard}/timeline`

Scope: `loyaltyCard.read`

Unified history: game plays, top-ups, card operations, merged and sorted desc. Query: `page` (default 1), `limit` (default 30, max 100).

**Response 200:**

```json
{
  "idLoyaltyCard": 100234,
  "listEntry": [
    {
      "category": "topup",
      "operationAt": "2026-07-03T18:22:10+02:00",
      "label": "Gold 50",
      "amount": { "amount": "50.00", "currency": "EUR" },
      "balanceType": "credit"
    },
    {
      "category": "game_play",
      "operationAt": "2026-07-03T18:35:44+02:00",
      "label": "Air Hockey 2",
      "amount": { "amount": "-1.50", "currency": "EUR" },
      "balanceType": "credit"
    },
    {
      "category": "card_operation",
      "operationAt": "2026-07-03T18:20:02+02:00",
      "label": "Activation",
      "amount": null,
      "balanceType": ""
    }
  ],
  "page": 1,
  "limit": 30,
  "hasMore": true,
  "isComplete": true
}
```

- `category`: `game_play` | `topup` | `card_operation` (existing vocabulary of `getUnifiedTimeline`).
- Signed decimal strings for money movements; `null` amount for non-monetary operations. `balanceType: "ticket"` entries carry plain-number amounts (`"amount": null`, plus a `ticket` field) — tickets aren't money.
- **Served locally, core-preferred:** the kiosk precedent (`Kiosk/V1/CardController::timeline`) asks core first (`OutboundLoyaltyCardManager::cardTimeline`) because core is the source of truth across locations, and falls back to the NUC's own `getUnifiedTimeline` when offline. The public endpoint does the same; `isComplete: false` flags the local-fallback response (offline NUC = local-only history). The internal `isOffline` flag is renamed — integrators care about data completeness, not our topology.
- The per-entry internal `detail` blob (balance before/after, internal ids) is **not** exposed in v1 — additive later if a real integrator needs it.

**Implementation notes**
- `sapiensclient/App/Service/LoyaltyCard/LoyaltyCardDataService.php` (`getUnifiedTimeline`), `sapiensclient/App/Manager/API/Admin/Outbound/OutboundLoyaltyCardManager.php` (`cardTimeline` — client→core call), pattern reference `sapiensclient/App/Controller/GatewayAuth/API/Kiosk/V1/CardController.php` (`timeline`).

### 3.3 Package catalog — `GET /public-api/v1/package`

Scope: `package.read`

Top-up packages sellable through this integration channel.

**Response 200:**

```json
{
  "listPackage": [
    {
      "idLoyaltyCardPackage": 12,
      "name": "Gold 50",
      "price": { "amount": "50.00", "currency": "EUR" },
      "perk": {
        "credit": { "amount": "50.00", "currency": "EUR" },
        "bonus": { "amount": "10.00", "currency": "EUR" },
        "courtesy": { "amount": "0.00", "currency": "EUR" },
        "ticket": 0,
        "timeSecond": 0
      },
      "isRequiredNewActivation": false
    }
  ]
}
```

- Only `LIVE` packages, sorted by price (existing `LoyaltyCardPackage::getList()` behavior).
- **Channel filter:** the list is filtered to packages allowed on the partner channel. **The channel system exists** (July 2026): `LoyaltyPackageChannel` (`shop` / `kiosk` / `online` / `partner`) on both repos, `listChannel` stored in the package detail, admin form multi-select, synced core→client (resolved — the legacy default of "everything except online" is applied core-side, the client never needs the fallback rule). Filter with `$package->isAvailableOnChannel(LoyaltyPackageChannel::PARTNER)` on the synced mirror.
- `design` (kiosk display colors/emoji) is intentionally omitted — presentation belongs to the integrator.

**Implementation notes**
- `sapiensclient/App/Service/LoyaltyCard/LoyaltyCardDataService.php` (`getListTopupPackage`), model `sapiensclient/App/Model/Loyalty/LoyaltyCardPackage.php` (`getList`, `getSettingDTO`). The DTO must not copy the service's `'currency' => $setting->getCurrency() ?: 'EUR'` fallback — currency comes from the synced system_setting accessor (CURRENCY.md rules 2/7/8).

### 3.4 Top-up execution — `POST /public-api/v1/loyalty-card/{idLoyaltyCard}/topup`

Scope: `loyaltyCard.topup` · Requires `Idempotency-Key`

The integrator has **already collected payment on their POS**; this call applies the purchased package to the card and records the sale on the NUC (which then syncs it to core). This is the same post-payment position the kiosk flow occupies after EMV approval.

**Request:**

```http
POST /public-api/v1/loyalty-card/100234/topup
Authorization: Bearer pk_live_9f2…
Idempotency-Key: pos-2026-07-04-000117
Content-Type: application/json

{
  "idLoyaltyCardPackage": 12,
  "price": { "amount": "50.00", "currency": "EUR" },
  "reference": "POS ticket 000117"
}
```

- `price` must equal the current package price (stale-catalog guard) → mismatch is 400 `errors: {"price": "mismatch"}`; wrong currency → `errors: {"price": "currency_mismatch"}`.
- `reference` (optional, ≤120 chars) is the integrator's own receipt/order id, stored in the payment detail for reconciliation — distinct from the idempotency key.
- `quantity` is intentionally absent in v1 (always 1); additive later.

**Response 200 (first execution and idempotent replays):**

```json
{
  "status": "success",
  "idPaymentLocation": 9241,
  "idLoyaltyCard": 100234,
  "applied": {
    "credit": { "amount": "50.00", "currency": "EUR" },
    "bonus": { "amount": "10.00", "currency": "EUR" },
    "courtesy": { "amount": "0.00", "currency": "EUR" },
    "ticket": 0,
    "timeSecond": 0,
    "justActivated": true
  },
  "balance": {
    "credit": { "amount": "73.50", "currency": "EUR" },
    "bonus": { "amount": "14.00", "currency": "EUR" },
    "courtesy": { "amount": "0.00", "currency": "EUR" },
    "timeSecond": 0,
    "ticket": 120
  }
}
```

- `justActivated: true` when the top-up activated an `available` card (existing `canBeSold()` → `STATUS_ACTIVE` behavior).
- **Error cases:** 404 card or package not found; 400 card not in a top-uppable state (`errors: {"loyaltyCard": "invalid_status"}` — reuse `PdaLoyaltyCardHelper::validateForUse`, the same validator the payment-terminal top-up trusts); 400 price mismatch; 409 idempotency-key payload conflict.

**Write path (all existing machinery, nothing new below the controller):**
1. `PaymentLocationService::createSale(...)` — `sapiensclient/App/Service/Payment/PaymentLocationService.php` — creates `PaymentLocation` + `PaymentLocationTransaction`. New `Source` enum value for this channel (e.g. `Source::PUBLIC_API`) and a payment-method mapping for "paid externally at partner POS" (precedent: `SellerPaymentMethodLocation::PAYMENT_TERMINAL` in `PaymentTerminalTopUpManager`).
2. `PaymentLocationService::addLoyaltyCardPackageItem(...)` — creates the `PaymentLocationItem` with the package `setting` snapshot in `detail`.
3. `SellerLoyaltyCardManager::topUpCard($card, [$item])` — `sapiensclient/App/Manager/Seller/SellerLoyaltyCardManager.php` — applies balances (incl. VAT-postponed split), activates if eligible, `store()`s the card.
4. `CommandManager::runPhpCommand('SellerSync', [], true)` — async push to core via `OutboundSellerManager::syncAnySell()` (payment rows) and, on activation, `LoyaltyCardSync` (card state) — `sapiensclient/App/Command/Seller/SellerSync.php`, `sapiensclient/App/Manager/API/Admin/Outbound/OutboundSellerManager.php`.
- Idempotency storage: a new `public_api_request` table — `id_api_integrator`, `idempotency_key`, `payload_hash`, `response` (jsonb), `created_at`, with a **unique index on (id_api_integrator, idempotency_key)** so concurrent duplicates collapse at the DB, `payload_hash` mismatch → 409, stored `response` replayed verbatim on retry. (A `transaction_ref`-style column on `PaymentLocation` was considered and rejected: it can't store the response body for replay nor detect payload conflicts.) Lookup-first pattern modeled on `KioskOperation::getOneByTransactionRef` in `sapiensclient/App/Controller/GatewayAuth/API/Kiosk/V1/TransactionController.php` (lines ~89–101). Kiosk EMV top-up flow as the end-to-end reference: `sapiensclient/App/Service/Kiosk/KioskCartProcessingService.php` (`processTopUpItem`).

### 3.5 Linked customer — `GET /public-api/v1/loyalty-card/{idLoyaltyCard}/customer`

Scope: `customer.read`

Name-level identity of the card's linked user — what a printed receipt would show, nothing more (no email, no phone, no address).

**Response 200:**

```json
{ "idUser": 2125, "name": "Maria G.", "registered": true }
```

- When the card exists but has no linked user and no registration detail: `{ "idUser": null, "name": null, "registered": false }` (200 — an anonymous card is a normal state, not an error).
- Resolution order: `LoyaltyCard.id_user → Cache::getUser($idUser)->getName()`; fallback to the card's registration detail name (`$card->getDetailQuick('name')`) for cards registered without a user account.

**Implementation notes**
- `sapiensclient/App/Model/Loyalty/LoyaltyCard.php` (`getIdUser`, `getDetailQuick`), shape precedent `sapiensclient/App/Helper/Pda/PdaLoyaltyCardHelper.php` (`formatUser` — public DTO drops its `email` field).

---

## 4. Plane matrix

The same contract will later be served by core (cloud plane) for integrators without venue-LAN access or with multi-location needs. Shapes stay **identical**; only the base host differs.

| Endpoint | NUC v1 | Core (later) | Notes |
|---|---|---|---|
| `GET /loyalty-card/lookup` | yes | yes | core resolves against the full card registry (all locations) |
| `GET /loyalty-card/{id}/timeline` | yes (core-preferred, local fallback) | yes | core is the natural source of truth; NUC version exists for offline resilience |
| `GET /package` | yes | yes | core owns packages; NUC serves the synced mirror |
| `POST /loyalty-card/{id}/topup` | yes | later, maybe | on core it becomes an online/remote top-up — different payment position, same wire shape |
| `GET /loyalty-card/{id}/customer` | yes | yes | core has the full user registry |

Core-plane auth will reuse the same `api_integrator` concept (token issued per plane; a NUC token is not valid on core and vice versa in v1).

## 5. Out of scope (v1)

Explicitly **not** in this contract — do not build, do not promise:

- Card creation, activation of blank/new cards, card replace/join/dismiss (seller + kiosk flows).
- Refunds / balance debits / charge operations (game charging stays on the internal device APIs).
- Ticket redeem, redeem catalog, ticket-payout resolution.
- Reservations, products, tabs, vouchers, discounts.
- Receipt/fiscal document generation (the operator's POS is the fiscal system of record for the partner sale; the NUC's PaymentLocation record is operational, `reference` links the two).
- Webhooks / push notifications / daemon-core exposure to integrators (poll the timeline in v1).
- Customer PII beyond name (email/phone/GDPR surface needs its own decision).
- Rate limiting tiers, token self-service UI, token expiry/rotation (operationally revoke via `status`).
- Multi-location aggregation (a NUC is one location by definition).

## 6. Conflicts and risks found during research

1. **No per-integrator token mechanism exists** — the whole §1 token model (`api_integrator` table, Bearer middleware, scopes) is net-new. Closest precedents: kiosk per-device tokens and `PdaSessionManager` (both validate an opaque token against a DB row).
2. **Currency source doesn't exist on the client yet** — `system_setting` (CURRENCY.md rule 8, slice 5) is not in the sapiensclient codebase (no `SystemSetting` model found). The money contract depends on it; sequence this API after that slice.
3. **`LoyaltyCardPackage` has no channel field** — §3.3 channel filtering is a declared dependency; contract is forward-compatible.
4. **Internal response builders are incompatible with the locked envelope** — `PaymentTerminalResponseBuilder`/`InboundGatewayResponseBuilder` emit `{success: bool, data}` and `exit`. The public API needs its own thin response DTO layer; do not bend the device builders.
5. **Existing service arrays leak floats and `?: 'EUR'` fallbacks** (`LoyaltyCardDataService`) — the DTO layer is mandatory, not cosmetic; it is where float→decimal-string and env-currency stamping happen.
6. **Auth today is per-method, not middleware** — device APIs call `protectAccess()` inside every controller method. The locked "own middleware stack" is a deliberate divergence; Slim 3 group middleware supports it cleanly.
7. **Route-file loading is DB-driven** (`Domain::getListRoutFile()`) — shipping the route file alone isn't enough; the domain row must list `routesPublicApi`, and `public/index.php` needs the `/public-api` bootstrap branch.
