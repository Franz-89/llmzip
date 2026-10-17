---
type: API Reference
title: APIs
description: "Reference to public, administrative, authentication, device, and integration APIs defined by the application."
tags: [api, routes, integrations]
status: active
source_kind: hand-written
timestamp: "2026-07-01T01:00:00Z"
---

# APIs

The repository defines APIs through Slim route files under `src/`. A simple route scan found more than 1,200 `$app->...` route declarations across these files, including web pages and API endpoints.

## Public and Webhook APIs

`src/routesCommonPublic.php` defines:

- Mailgun incoming email and webhook endpoints.
- Email unsubscribe endpoint.
- WhatsApp webhook endpoints.

`src/routesTelegram.php` defines a Telegram webhook under `/bot/telegram`.

## Admin APIs

`src/routesAdminApi.php` exposes `/api/v1` endpoints for:

- Organization sync.
- Location sync.
- Warehouse sync.
- Payment terminal provisioning.

`src/routesAdminLocalApi.php` exposes `/local/api/v1` endpoints used by local/admin frontend code. Visible route groups include:

- Location list.
- Translation blocks.
- Reporting APIs for sales, game performance, item sales, activity, reservation flow, staff performance, loyalty card, sales comparison, game location, individual staff, accounting, and product analysis.
- Issue APIs.

The React dashboard uses Axios with `baseURL: '/local/api/v1'`.

`src/routesAdmin.php` also exposes an admin `/documentation` group. The route comment identifies it as a proxy to `sapienscore-technologies`.

Outbound calls to `sapienscore-technologies` are organized under `App\Manager\API\Admin\SapienscoreTechnologies\Outbound\`, mirroring the `App\Manager\API\Admin\SapiensClient\` pattern used for the SapiensClient device integration (one namespace per remote party, generic sender + request builder, one manager per domain, called directly by controllers/helpers — no intermediate Service layer):

- `SapienscoreTechnologiesApiTarget` — picks a per-surface auth param and secret: `docs()` -> `/api/docs/...`, auth param `docsApiKey`, secret `DOCS_API_KEY`; `api()` -> `/api/v1/...`, auth param `officialToken`, secret `SAPIENSCORE_TECHNOLOGIES_API_KEY`. It also owns the two per-surface request shapes — `renderApiPath()` slots the tenant into the v1 path, and `usesEnvelope()` says whether the body is `{data:{…}}` (v1) or flat (docs, whose controller reads its params straight off the request).
- `OutboundRequestBuilder` / `OutboundSendRequestSapienscoreTechnologies` — generic request builder + curl sender, parameterized by target. The builder holds `idOperator` apart from the payload, because technologies takes the tenant in the path and never as a body field.
- `TechnologiesOperatorResolver` — owner -> `idOperator`, via `POST /api/v1/operator/resolve` on technologies and memoised only for the current request. This project only ever knew `owner` (`LIST_OWNER` / `OwnerManager`), and one deployment can serve several owners, so the id is discovered rather than configured. Each new request resolves it again, allowing operator changes on technologies to become visible without cache invalidation. Returns 0 — never throws — when the owner has no operator row or technologies is unreachable.
- `OutboundDocumentationManager` — docs surface; called by `DocumentationController` and `DocumentationHelper`. Not tenant-scoped: documentation is not customer data.
- `OutboundProductManager`, `OutboundProductRequestManager`, `OutboundShippingManager` — v1 surface; called by `ProductRequestController`. Every method takes `int $idOperator` first, and `owner` has left the payload entirely.

### Operator-scoped v1 calls

Technologies serves every tenant-scoped endpoint under `/api/v1/operator/{idOperator}/…` and
refuses a `product_request` / `shipping` that does not belong to that operator. Consequences on
this side:

- The v1 body is the `{data:{…}, officialToken}` envelope, matching what this project already
  receives from technologies on `/v1/technologies/*`. The docs surface stays flat.
- Inside that envelope, WRITES pack their whole payload into ONE named array instead of loose
  keys: `{data:{productRequest:{…}}}` / `{data:{shipping:{…}}}`, named after the object being
  written by `OutboundProductRequestManager` / `OutboundShippingManager`. So
  `create-draft`, `update-draft`, `submit`, `approve`, `reject`, `return-to-draft` and
  `shipping/issue` are nested. READS stay flat — `product/request/list`, `get`, `status-history`,
  `shipping/list`, and `product/list` / `product/get`. Technologies takes the same key back out in
  `APIProductRequestController` / `APIShippingController`, so the two sides must be deployed
  together — there is no flat-payload fallback. `idOperator` stays out of it, in the path.
- `product/request/list` no longer takes `owner`; the operator implies it.
- `product/request/shipping` is now `product/request/shipping/list`.
- The admin screens carry the operator in their OWN routes too
  (`/product-request/detail/{idOperator}/{idProductRequest}` and friends) — see
  `/ui/template-map.md`. List rows carry `owner`, so the id is resolved once at render time
  and travels forward in the links instead of being re-derived per click.

Each secret must match the corresponding constant on the `sapienscore-technologies` side: `DOCS_API_KEY` is checked by `APIDocumentationController`, and `SAPIENSCORE_TECHNOLOGIES_API_KEY` by `InboundAuthSapiensCoreManager::protectAccess()` — normally reached through `InboundOperatorContext`, which also validates the operator in the path — in `APIOperatorController`, `APIProductController`, `APIProductRequestController`, `APIShippingController`. Device provisioning (`APIKioskController`, `APIPaymentTerminalController`) uses the separate `InboundAuthProvisionManager` and `OFFICIAL_TOKEN_PROVISION` secret instead.

## Gateway/Auth APIs

`src/routesAuth.php` exposes `/v1` APIs for:

- NUC setup, token, SSD/private key, Tailscale, rolling time, logs, emergency scripts, and spare requests.
- Sapiens client sync and operations for seller sales, user PIN changes, loyalty cards, finder/search, company creation, vouchers, Vendus documents, receipts, ticket rewards, reservations, migration data, pulse requests, workstation printers, pulse box sync, and payment terminal transactions.
- PDA register, heartbeat, auth, game ticket payout, scan, and loyalty card operations.
- Provisioning payment terminals.

### Technologies read API (`/v1/technologies`)

**Read-only.** `sapienscore-technologies` calls these to pull reference data out of a
customer deployment; nothing under this group writes. Auth is `InboundAuthManager`
(the `token` must match `Domain::currentDomain()->getToken()`, the `role` must match
`SERVER_ROLE`) — the same credential the `/v1/provision/*` and `/v1/trace/*` webhooks use,
which on the caller's side is the operator row with scope `sapienscore`.

Every resource exposes the same two endpoints, `list` and `one`:

- `POST /v1/technologies/{resource}/list` — optional `data` filters `status`, `type`,
  `search`, `limit` (unset means every matching row — there is no cap), `offset`.
  Answers `data.list{Resource}` + `data.total` (the total *before* limit/offset).
- `POST /v1/technologies/{resource}/one` — `data.id{Resource}`. Answers `data.{resource}`.

Currently implemented: **location** (`one` also accepts `data.uuid`, and resolves deleted
locations so stale references held by technologies can still be named; `list` also accepts
`data.idOwner`, keeping only the locations whose organization belongs to that owner — used by
technologies' Semaphore automation launch form to offer one owner's locations).

Also implemented, **owner-scoped** (`data.idOwner` is mandatory — without it nothing
matches — and a NUC exists for the caller only when its location's organization has that
owner): **nuc** (`list` filters `type`, `status`, `idLocation`, `search`; `one` takes `idNuc`;
`POST /v1/technologies/nuc/option` returns `data.listType` for the caller's "new NUC" form),
and the per-NUC children, each needing `data.idNuc`: **nucLog** and **nucLogRequest** (`list`
only, paged in SQL — `limit` defaults to `DEFAULT_SERVER_PAGINATION`, max 500), **nucCommandQueue**
(`list` = the 200 most recent, `one` takes `idNucCommandQueue`) and **nucSystemMetric** (`list`
= the 50 most recent, `data.type` `glances` / `speedtest`; `one` takes `idNucSystemMetric`). Scope
is `NucVerifier::forOwner()`. The NUC endpoints are **not** `AbstractTechnologiesReadManager`
resources: `App\Controller\Admin\API\V1\Nuc\NucController` calls `NucActionManager` directly
(see *NUC single entry point* below) and answers through `TechnologiesResponder`. A NUC, metric or
queued command outside the owner answers `success:false` "… does not exist", on lists too.
`NucApiDTO` deliberately leaves out the
NUC token, nucos user/password/key and the USB key file (payload rule 1).

Both answer the `{success, message, data}` envelope that the caller's `OutboundResultDTO`
parses — **not** the v2 `{status: 'success'}` shape.

#### Payload rules

1. **Allow-list only.** Each resource's DTO enumerates what it sends. Settings blobs,
   module configuration, receipt counters, integration credentials and per-record `detail`
   are never on the wire. Never `return $model->getDetail()`.
2. **Opaque values travel rendered.** A bare `status => 1` means nothing to the caller: it
   holds no copy of our enums, and a hard-coded one there would rot the day we add a
   status. Every coded value ships as a pair via `AbstractTechnologiesDTO::addRenderedValue()`:

   ```json
   "status": 1,
   "statusRendered": "Opened"
   ```

   The raw value is there for the caller's own comparisons; the label is already translated
   on this side, by the project that owns the enum. The same applies to coded lists
   (`listIdModule` / `listIdModuleRendered`, parallel arrays). A value that is a relation
   rather than a code keeps its own name instead — `idOrganization` / `organizationName`.

   A status (and the NUC log `type`) is rendered by the model's own `renderStatus()` /
   `renderType()` badge, exactly as the back office shows it — no `*Tone` field, no DTO-side
   copy of the colours. The two projects' designs still differ, but technologies is meant to
   adopt this project's design, so the markup is shipped as-is and printed raw by the caller.

#### Technologies command API (`/v1/technologies-command`)

The **write** counterpart, kept in its own route group so `/v1/technologies` stays read-only.
Same credential (`InboundAuthManager`), same owner scope, same controller and responder as the
NUC reads (`TechnologiesResponder`: auth, envelope; refusals logged as `api-error-technologies`
and answered `success:false` with the domain's own translated message). The audit line is
`NucActionManager`'s `nuc-action`, naming `data.actor`, the technologies user.

- `POST /v1/technologies-command/nuc/create` — `idLocation` (must belong to `idOwner`), `name`,
  `macAddress`, `type`.
- `POST /v1/technologies-command/nuc/update` — `idNuc`, `name`; `isInNetwork`, `macAddress`,
  `loginType` are applied only when sent.
- `POST /v1/technologies-command/nuc/allow-installation`, `/nuc/init` — `idNuc`.
- `POST /v1/technologies-command/nuc/command-queue/create` — `idNuc`, `command`;
  `/nuc/command-queue/cancel` — `idNucCommandQueue` (its NUC must belong to `idOwner`).

The request runs as the API user, so `created_by` / `modified_by` and the installer recorded by
allow-installation are that user; the technologies user is named in the audit line.

#### NUC single entry point (`NucVerifier` + `NucActionManager`)

Every NUC read and command — from the back office (`App\Controller\Admin\Nuc\*`) and from
sapienscore-technologies (`App\Controller\Admin\API\V1\Nuc\NucController`) — goes through the
same two classes, so the action is exactly the same whoever asks:

- `App\Manager\Nuc\NucVerifier` — who is asking, and visibility. Reads call it directly:
  `NucVerifier::forCurrentUser()->verifyNuc($idNuc)` (also `verifyNucCommandQueue`,
  `verifyNucSystemMetric`) returns the row or throws; `buildWhereNuc()` is the list condition.
  The per-NUC rule lives on the model (`Nuc::userCanAccess(User)`, `Nuc::belongsToOwner(int)`).
- `App\Manager\Nuc\NucActionManager` — commands, each taking the verifier: validation, the write
  and the audit line (`sys_log` type `nuc-action`, e.g. `update by backoffice:user #3 {"idNuc":1}`
  or `update by technologies:Name <mail> #1 {...}`).

The verifier is the only per-channel input:

- `forCurrentUser()` — back office: the NUCs of the locations the logged-in user can access
  (sys everything, sapiens everything not deleted, managers / IT / tech support their
  locations), network fields (MAC, "in network") only for `canAdminH()`, an unreachable NUC is
  "access denied". `Nuc::getList()` uses the same verifier.
- `forOwner($idOwner, $actor)` — technologies: the NUCs whose location's organization belongs to
  the owner, network fields allowed (technologies gates them with its own `NUC_ADMIN`), an
  unreachable NUC is "does not exist".

The channel keeps only its authentication, its permission gate (`Permission::NUC_*` in the back
office, technologies' own tokens) and its response format (v2 HTML/JSON vs the `{success,
message, data}` envelope via `TechnologiesResponder`, with `NucController`'s request mapping and
the `Nuc*ApiDTO` payloads). Do not read or write NUC rows from a controller directly.

#### Adding a resource

Server side, three files:

1. A DTO extending `App\DTO\API\Technologies\AbstractTechnologiesDTO` — implement
   `getStoreArraySummary()` and `getStoreArrayDetail()`, and route every coded field
   through `addRenderedValue()`.
2. A manager extending `App\Manager\API\Admin\SapienscoreTechnologies\Inbound\AbstractTechnologiesReadManager`
   — implement `getResource()`, `getDtoClass()`, `buildWhere()`, `findList()` and
   `resolve()`. Filtering, limit defaulting, totals and slicing are inherited; build where
   clauses with the provided `whereInt()` / `whereSearch()` helpers so caller-supplied
   strings stay escaped. Add the resource's `common.system.<resource>` translation key —
   the inherited not-found message translates the resource name through it.
3. Two one-line methods on the resource's existing domain controller, delegating to
   `TechnologiesReadResponder::respondList/respondOne`, plus a route pair in
   `src/routesAuth.php` under the `/technologies` group.

`App\Model\Location\Location` + `TechnologiesLocationManager` + `LocationApiDTO` are the
worked example. One trap worth repeating: **do not reuse a model's `getListApi()`-style
finder.** Those branch on the logged-in user and typically have no `TYPE_API` branch — the
user `InboundAuthManager` logs in — so they silently return an empty array.

Caller side (`sapienscore-technologies`), two files: a DTO extending `AbstractRemoteDTO`
(named getters only — `initByArray()` / `initListByArray()` are inherited) and a manager
extending `AbstractOutboundReadManager` (just `getResource()` and `getDtoClass()`, plus
optional typed wrappers). URLs, payload keys,
the credential guard, the per-request memo and the unreachable-vs-empty result are all
inherited.

## Device APIs

- `src/routesDeviceCoolcodeApi.php`: `/api/v1` device auth, ticket, balance, heartbeat, version/download, and card charge endpoints.
- `src/routesPulseApi.php`: `/api/v1/request/handshake` and `/api/v1/request/update`.
- `src/routesPaymentTerminalApi.php`: `/api/v1/payment-terminal/handshake`, `/provision`, and `/update-status`.
- `src/routesWorkstationApi.php`: RFID, version, install/auth, download, and uninstall endpoints.

`public/pax.php` uses domain theme `pax` and loads the payment-terminal route file configured on the domain.

## Vendor/Integration APIs

- `src/routesNayaxApi.php`: Nayax `Cortina` session, prepaid sale, sale notification, void, authorization, and settlement endpoints.
- Admin legacy API routes under `/api/legacy` include payment, merchant warning, Ethoca, and cookie endpoints.

## Front Routes

`src/routesPorto.php` and `src/routesGlass*.php` define public/front pages and form endpoints such as contact, FAQ, login/reset, reservations, registration/payment, NFC payment, profile, tickets, and glass service calculators.
