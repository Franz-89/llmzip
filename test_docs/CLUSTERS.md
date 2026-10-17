# Clusters — location grouping (source of truth)

Design locked 2026-07 (extends `DYNAMIC_PRICING.md` §5.1, which remains the pricing-scope
view). Clusters started as a pricing scoping primitive and are now a standalone module:
selection vocabulary, sync batching, and user picker presets.

## 1. Types

`cluster` ( `id_cluster`, `owner`, `id_user` nullable, `name`, `type`, `visibility`,
`status`, `detail` ) + membership `cluster_location` ( `id_cluster`, `id_location`, `status` ).

| Type | Membership | Editable by | Usable as selector? | Semantics |
|---|---|---|---|---|
| `AUTOMATIC` | location ∈ exactly 1 (partition, see §2) | **Sys only, period** | No — sync batching only | n/a |
| `INSTITUTIONAL` | location ∈ ≤1 per owner; flat | owner admins (membership changes are heavyweight, §4) | **Yes — only type** | **by-reference (live)** |
| `PERSONAL` | unlimited, overlapping | creator + Sys | No — picker preset only | **by-value (explodes at pick time)** |

## 2. AUTOMATIC clusters — partition invariant

- Every location with a NUC belongs to **exactly one** AUTOMATIC cluster, always.
- A per-owner **default AUTOMATIC cluster** is the catch-all. It has **no `cluster_location`
  rows** — its membership is **implicit**: all NUC locations of the owner not assigned to
  another AUTOMATIC cluster. New locations therefore need zero bookkeeping; the invariant
  holds by construction.
- Never used to ship configuration. Purpose: split sync fan-out (immediate push inside the
  relevant cluster, nightly drain for the rest — see §7, deferred).
- Seeded by an idempotent command (add-if-not-exists per owner, anagraphic row only) that
  iterates `LIST_OWNER` via `OwnerManager`. Safe to run on every deploy.

## 3. INSTITUTIONAL clusters — the only live reference

- A config stores the token **`cluster:N`** inside `listLocationCountry` (see §5); the
  resolver expands membership **live at every resolve**. Nothing ever copies the member list
  core-side, so membership changes require **zero config cleanup** on core.
- The only stale copy lives on the NUC (exploded snapshot at the sync boundary, §6).

## 4. Membership changes — allowed, but heavyweight

Removing/moving a location in an INSTITUTIONAL cluster is allowed (real-world reorgs and
day-one mistakes must stay fixable) but treated as a heavyweight operation:

- Confirmation dialog spelling out what will re-sync.
- Automatic re-push of the affected location's NUC config slice (vouchers, packages, promos).
- Audit log entry.

Coverage is a **nudge, not a wall**: an uncovered location just falls outside cluster-scoped
configs (visible support ticket, not corruption). Location detail shows in/out-of-cluster only
when the owner has ≥1 institutional membership; cluster pages show a coverage indicator
("N locations not in any cluster"). AUTOMATIC coverage is enforced structurally (§2) instead.

## 5. `listLocationCountry` integration — `cluster:N` token

The existing mixed vocabulary (int = location id, string = country ISO) gains a third entry
type: the string token `cluster:N` (institutional clusters only). **Zero data migration** —
old stored lists stay valid byte-for-byte; the token can't collide with ISO codes (contains
`:`, not 2 letters) nor with ids (not numeric). Un-updated read paths degrade safely: the
token matches no country and is silently ignored, never misinterpreted.

All type dispatch moves into **one resolver** (today it's duplicated `is_numeric` checks in
`Voucher::isValidFor`, `MarketingPromo` filtering, `OutboundNucManager` package filter,
`Location::getListApiSync`, `Location::resolveCountryFilterToListId`, render templates):

- `expandToListIdLocation(array $list)` — int as-is, ISO → country's locations,
  `cluster:N` → live institutional membership.
- `matchesLocation(array $list, $idLocation)` — replaces the scattered two-way `in_array`.

**Two resolution contexts, never mixed:**

- **System resolution** (voucher validity, promo matching, sync fan-out): no user filter —
  an org config is valid at its locations regardless of who looks.
- **User-facing expansion** (pickers, personal-cluster explosion, back-office filter,
  analysis/report filters): filtered by the current user's location access **at resolve
  time**. This context also resolves **PERSONAL** cluster tokens (visibility-checked:
  own / Sys / public of a reachable owner) — reports store nothing, resolution is
  per-request, so by-value semantics are preserved. The system context never does:
  a personal token in a stored config expands to nothing by construction.

## 6. Cross-repo boundary — clusters stay core-side

The NUC never learns about clusters. Outbound sync managers explode `cluster:N` into concrete
location ids before shipping, so the sapiensclient wire contract and its local matching are
untouched (no client release). The snapshot goes stale on membership change → §4's automatic
re-push is the compensation. AUTOMATIC clusters exist only in core routing logic and are never
part of any payload.

## 7. Sync split by AUTOMATIC cluster (designed, NOT yet built)

Today every loyalty-card update fans out to the whole network. Target design:

1. Change originates at a location → resolve its AUTOMATIC cluster → immediate push to that
   cluster's NUCs only.
2. All other NUCs: write `sync_tracking_nuc` rows with a new `STATUS_PENDING` instead of
   pushing. The existing UNIQUE `(id_nuc, action, id_action)` collapses repeated changes into
   one pending row per NUC — free coalescing.
3. Nightly command drains pending rows, batched per NUC.

Build only after the cluster system itself is live.

## 8. PERSONAL clusters

- Picker presets, nothing more: the UI explodes them into location ids at selection time;
  no config ever references a personal cluster, so editing/deleting one can never break
  anything. "You are not selecting the cluster."
- `visibility` public/private: private = creator only; public = visible/usable by all
  same-owner users (still by-value, still harmless). Edit rights: creator + Sys.
- Sys can **transfer ownership** (`id_user` update, small Sys UI action) — the fired-user case.
- **Access loss**: when a user loses access to a location/organization, personal clusters are
  NOT physically pruned. The resolver filters expansion by current access at resolve time
  (§5 user-facing context) — no fragile hooks on every permission mutation, self-healing if
  access returns, and public clusters resolve per-viewer correctly. The profile tab greys out
  currently-inaccessible entries so the state is visible.
- Managed by the user in a new **profile tab**.

## 9. Implementation order

1. Schema (`cluster`, `cluster_location`) + models + seed command for default AUTOMATIC
   cluster per owner.
2. Central resolver + funnel the existing `listLocationCountry` read paths through it.
3. Sys CRUD (AUTOMATIC + INSTITUTIONAL incl. heavyweight membership flow) + profile tab
   (PERSONAL) + picker/badge rendering for the `cluster:N` token.
4. NUC boundary explosion + membership-change re-push.
5. Later: sync split (§7); pricing `SELECTOR_CLUSTER` (Phase 2 of `DYNAMIC_PRICING_PLAN.md`).
