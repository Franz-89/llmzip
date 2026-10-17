# Migration plan — AdminLTE → Tabler / Alpine / HTMX (+ Vue for Trace)

This document describes the **target frontend architecture** for sapienscore and **how we get there**.

Companion to `/CLAUDE.md`. CLAUDE.md is the hard-rules layer loaded into every session; this file is the longer-form *why* and *in what order*. If anything here drifts from `/CLAUDE.md`, **CLAUDE.md wins** and this file needs updating.

Ported from sapiensclient's `/architecture.md` + `/migration-plan.md` (`../sapiensclient`), where the same migration is almost complete. Divergences from that upstream are called out inline as **[divergence]**.

Realtime / daemon-core integration is **deliberately out of scope here** — daemon-core is a separate project (`../daemon-core`), and how sapienscore talks to it is documented in CLAUDE.md ("Realtime — single daemon-core") and the daemon-core repo, not in this migration doc.

---

## Why migrate

The UI is AdminLTE 2.4 + jQuery + Bootstrap 3 — legacy from the original stack. We're retiring it for a jQuery-free Bootstrap 5 base so that:

- pages are server-rendered HTML with light client reactivity, not jQuery DOM-soup;
- sapienscore and sapiensclient share the same v2 utilities (`list.js`, `sapiensT.js`, pagination) and stay developer-fungible;
- complex islands (Trace) can be Vue without dragging the whole app into an SPA.

## Target stack

- **Tabler 1.x** (Bootstrap 5) — components **and** utility classes (`m-*`, `p-*`, `d-flex`, `gap-*`, `text-*`, `bg-*`). No jQuery.
- **Tabler Icons** (3.x, `ti ti-<name>`) — icon set.
- **Alpine.js 3** — **the default** for page-level reactivity (toggles, dropdowns, small state machines, status pills).
- **HTMX 2** — server-driven HTML fragment swaps (list filters, modals, paginated tables).
- **Vue 3 islands** — **only Trace** today, mounted into a specific PHTML root. No SPA router. No app-wide Vue. **[divergence]** sapiensclient reserves Vue for *cart + reservation*; sapienscore's single justified island is *Trace* (the Issue→Trace system).
- **Vite** — build pipeline (Vue SFCs, CSS bundling, ES modules). Output to `public/assets/adminlte/v2/dist/`.
- **No Tailwind.** Tabler/Bootstrap 5 already ship a usable utility set; a second utility vocabulary buys nothing here.
- **React on `/analysis` stays untouched** — its own webpack build under `react/`. The v2 migration does not touch it.

### Single-Bootstrap rule (hard rule)

Never load Tabler's bundled `tabler.min.js` **and** `import * as bootstrap from 'bootstrap'` together — Tabler 1.x bundles its own complete Bootstrap, so loading both double-registers the data-API handlers and every dropdown/modal opens-and-instantly-closes. Tabler CSS gives the look; if we ever need one Tabler JS plugin (`autosize`/`countup`/`IMask`), import that single module. See the load-bearing comment in `public/assets/adminlte/v2/js/app.js`.

### Where Vue (vs Alpine) is justified

Default is **Alpine + HTMX**. Vue earns its place only when a screen carries heavy multi-step client state that exceeds Alpine's component model.

| Screen | Why Vue is OK |
|--------|---------------|
| **Trace** (Issue→Trace) | Optimistic board/detail state, in-place mutations across many entity types (members, costs, links, comments, checkpoints), daemon-core broadcast patching later. Beyond Alpine's reach. |

**Everything else stays Alpine + HTMX.** Don't reach for Vue because it feels familiar — a new Vue island requires an explicit decision. The location editor is the only *possible* second island, and even that defaults to Alpine+htmx unless complexity proves otherwise.

---

## Backend layering (unchanged target — applies to every slice)

```
HTTP routes ──► Controllers ──► Managers / Services ──► Models / DTOs
```

- **Controllers are passing points.** Parse request → call a Manager/Service → return a Response. No DB queries, no business logic, no shape transformation. A 3-line pipe is correct.
- **Managers orchestrate; Services do one focused thing.** Business logic lives here. They call Models for persistence and return Models (or DTOs where transformation is real).
- **Models own their array shape** (`getStoreArray()`) and their static finders (`getList()`, `getOneById()`, `getOneByX()`, `getListByX()`). AutoDb/AutoRecord — never raw SQL. See `/CODING_STANDARDS.md`.
- **DTOs only when transformation is real** — aggregating models, computed fields, isolating an external contract. Not for 1:1 mirrors.
- **Same Manager/Service powers both surfaces.** When a screen has an SSR page and a JSON API, they share one business-logic layer — never duplicate logic across the two paths.

### Route surfaces

| Surface | Route file | Returns | Used by |
|---------|-----------|---------|---------|
| Admin SSR | `src/routesAdmin.php` | PHTML | Employee web UI |
| Admin JSON API | `src/routesAdminApi.php` | JSON | v2 frontend |
| Local API | `src/routesAdminLocalApi.php` | JSON | Local-network internal services — **Trace API lives here** (`/local/api/v1/trace/*`), also consumed by the sapiensclient reverse-proxy |

SSR routes: `index` (page), `renderX` (fragment). JSON routes use the action name directly — `list`, `one`, `update`, `create`, `delete`. **No `api` prefix** on method names; the route file already tells you the URL and shape.

### JSON response shape (v2 — locked)

- **Read/list:** plain payload — an array of items, or a single item.
- **Write/create/save:** `{ "status": "success", "id": 42, "row": "<tr id='row-42'>…</tr>" }` — `id`/`row` present when a list row should update in place. `row` is rendered server-side via `_row.phtml` so the row design lives in one place.
- **Error:** `{ "status": "error", "errors": { "field": "code" }, "message": "optional" }` — field-keyed, rendered with Bootstrap 5 `.is-invalid` + `.invalid-feedback`; modal stays open, values preserved.
- **Always `status: 'success'|'error'`.** Never `ok: true/false`. No v1 `{type, subType, data}` envelopes in v2.

---

## v2 folder convention

The `v2/` subfolders exist for **disk separation only — not runtime parallelism**. AdminLTE 2 (BS3/jQuery) and Tabler (BS5/no-jQuery) are structurally incompatible and coexist on disk during the migration, but **a given URL serves only one of them**, controlled by which PHTML the controller renders.

```
templates/adminlte/v2/
├── include/                 ← LAYOUT only (header/sidebar/footer)
│   └── module/              ← partials included BY include/ files
├── helper/module/           ← shared widgets used by any page
└── <feature>/               ← per-page templates
    ├── index.phtml          ← page entry (no underscore)
    └── module/              ← per-page partials, underscore-prefixed
        ├── _row.phtml
        └── _editDetail.phtml
```

- New PHTML: `templates/adminlte/v2/<page>/...` — **inside** `templates/adminlte/`, never a sibling. The template resolver root is `templates/adminlte/`; don't move or delete it.
- New assets: `public/assets/adminlte/v2/{js,css,dist}/...`.
- v1 files stay on disk as **dead artifacts** (git history is rollback), **not** a runtime fallback. Retire a v1 page file only after its v2 counterpart is production-stable.

---

## Migration discipline (hard rules)

**[divergence]** sapiensclient's dashboard slice shipped behind a *parallel route + feature flag* (`/dashboard-next`, flip `/` later). **sapienscore does not do this.** Here:

- **One controller method per action.** When a page is migrated, the existing controller method **flips its render path** — e.g. `TP::p('issue/index')` → `TP::p('v2/trace/index')`. The URL stays the same.
- **No parallel methods** (`renderTraceTabler`), **no parallel routes**, **no feature flags**. See `LoyaltyCardController::renderIndex` for the canonical flip.
- **Page-by-page, never bulk.** Don't speculatively migrate a page — wait for real feature work that touches it. Don't break working pages.
- **No mixed jQuery+Vue/Alpine in one page.** A URL is wholly v1 or wholly v2.

---

## Per-slice recipe

> **Handing a page to an agent?** `/MIGRATION_PLAYBOOK.md` is the concrete, copy-paste,
> do-this-in-order companion to this section — full worked examples (list page, edit/new modals,
> controller flip), the `list.js` attribute table, Alpine/htmx patterns, the gotcha checklist, and a
> definition-of-done. This file is the *why*; the playbook is the *how*.

For each screen migrated:

1. Pick the screen.
2. **Extract a Manager** (+ Service if needed) — pull any queries/logic out of the controller.
3. Add a **DTO** only if transformation is genuinely needed.
4. Add the **JSON route(s)** in `src/routesAdminApi.php` (or `routesAdminLocalApi.php` for Trace/local).
5. Add the **v2 PHTML** under `templates/adminlte/v2/<page>/` — `index.phtml` + `module/_row.phtml` + `module/_editDetail.phtml`.
6. **Flip the SSR controller method's render path** to the v2 template (same method, same URL).
7. Verify; leave the v1 PHTML on disk until the slice settles.

### The default screen shape — list page (CRUD + edit modal)

Use the playbook; don't reinvent it. Backend: `index()` renders the v2 page (embeds list inline), `renderEditForm($id)` returns the modal form body, `update($id)` returns the `{status, id, row}` envelope. Templates: `index.phtml` (Tabler card, `data-list-filter` search, `<table>` looping `_row.phtml`, modal scaffold), `module/_row.phtml` (the **single** place row design lives), `module/_editDetail.phtml` (`<form data-list-submit data-list-close-modal>`).

Auto-wiring is handled by `public/assets/adminlte/v2/js/list.js` via data attributes (`data-list-filter`, `data-list-edit-url`/`-modal`, `data-list-row-link`, `data-list-submit`, `data-sort`, etc.). Every `<select>` is auto-upgraded to Tom Select — never add opt-in attributes, never leave one raw. See CLAUDE.md "v2 list-page playbook" for the full attribute table.

### List-page shape (locked)

- **Server chunk = 500 rows** per page (`DEFAULT_SERVER_PAGINATION`). Most tables fit in 1–2 chunks.
- Table body in a `max-height: 65vh; overflow-y: auto` wrapper (`list-scroll`); `<thead>` is `position: sticky; top: 0`. Page chrome stays locked while rows scroll.
- `data-list-filter` searches within the current chunk; cross-chunk search → paginate or `/finder`.
- **No DataTables.** **No JS-generated rows** — row HTML always comes from `_row.phtml`. **No `setInterval` polling of server data.**

### Status badges

For a v2-migrated model, switch `renderStatus()` from v1's `DesignHelper::renderLabel()` (BS3 markup) to **`DesignHelper::renderBadge($color, $label)`** (Tabler soft pill). Use Tabler color tokens (`green`, `red`, `azure`, `secondary`, `dark`…; no `olive`/`gray`/`black`). `LoyaltyCard::renderGenericStatus()` is the reference. Don't migrate the helper itself — migrate per-model.

---

## What "ported, not improved" means

A v1→v2 migration **ports exactly what's there** — same features, same fields, same behavior, new shell. Never add features the user didn't ask for during a migration, and never silently drop ones that exist. Cleanup and new features are their own commits.

---

## Cross-project sync

Shared v2 utilities (`list.js`, `sapiensT.js`, pagination helper) are kept **identical** across sapienscore and sapiensclient by the user. A fix in one ports to the other — don't fork. If divergence is ever intentional, note it explicitly (as the **[divergence]** markers above do).

---

## Pointers

- `/CLAUDE.md` — the hard-rules layer (source of truth).
- `/MIGRATION_PLAYBOOK.md` — the hands-on per-page recipe (worked examples + checklist) to hand to an agent.
- `/MIGRATION_V1_INVENTORY.md` — the remaining-pages campaign board; pick a page from here.
- `/CODING_STANDARDS.md` — model + controller patterns, AutoDb/AutoRecord, table conventions.
- `../sapiensclient/docs/architecture.md` + `/migration-plan.md` — upstream pattern this file is ported from.
- `../daemon-core/` — the separate realtime project (integration covered in CLAUDE.md, not here).
