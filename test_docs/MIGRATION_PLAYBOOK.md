# v2 Migration Playbook — hands-on recipe for one page

**Audience:** an agent (or dev) handed **one small v1 admin page** to migrate to the v2 stack
(Tabler / Bootstrap 5 / Alpine / HTMX, no jQuery). This is the *do-this-in-order, copy-this-code*
companion to `/MIGRATION.md`.

Read order before you touch anything:

1. **`/CLAUDE.md`** — the hard rules. They win over everything. Non-negotiable.
2. **`/MIGRATION.md`** — the target architecture and the *why*.
3. **This file** — the concrete recipe + worked examples.
4. **`/MIGRATION_V1_INVENTORY.md`** — pick your page from here; tick it only when *every* v1
   feature exists in v2.

The single most important rule, repeated because it is the one most often broken:

> **Port, don't improve.** A migration reproduces exactly what the v1 page does — same fields, same
> actions, same behaviour — in the new shell. You never add a feature the user didn't ask for, and
> you never silently drop one that exists. Cleanup and new features are *separate* commits.

If in doubt about whether something is in scope: it's in scope if v1 does it, out of scope if v1
doesn't. That's the whole test.

---

## 0. Reference pages to copy from

Don't invent structure — clone one of these known-good pages and adapt:

| You're building… | Canonical example | Files |
|---|---|---|
| A **read-only list** (row → detail page) | `LoyaltyCard` | `templates/adminlte/v2/loyaltyCard/{index,module/_list,module/_row}.phtml`, `LoyaltyCardController::renderIndex` |
| A **list + edit-modal + new-modal CRUD** | `Period` | `templates/adminlte/v2/period/{index,module/_row,module/_editForm,module/_newForm}.phtml`, `PeriodController::{index,renderEditForm,create,update}` |
| A **tabbed detail page** (htmx fragments) | `Customer` / `Location` detail | `templates/adminlte/v2/customer/detail.phtml`, `templates/adminlte/v2/location/detail.phtml` |
| A **Vue island** (only if truly needed) | `Trace`, `Mailbox` | `public/assets/adminlte/v2/js/islands/{trace,mailbox}/` |

**99% of pages are the first two rows.** Vue is almost never the answer — see §9.

---

## 1. Understand the v1 page first (do not skip)

1. Find the controller method and its route. In `src/routesAdmin.php`, grep the URL; the method is
   usually `index` / `renderIndex` / `renderDetail`.
2. **Read the v1 PHTML top to bottom.** Write down *every* feature: each column, each button, each
   filter, each modal, each AJAX action, each permission gate. This list is your definition of done.
3. **Read the model before calling getters.** Don't assume `$x->getName()` exists — open the model,
   find the real accessor. (Hard rule in CLAUDE.md.)
4. Note where the page is *also* rendered (e.g. tickets appear inside customer detail). Migrating the
   standalone page must not regress the embedded one.

Only once you have the feature list do you write any v2 code.

---

## 2. The render trio (every full page)

A v2 SSR page renders **header → page → footer**, all under `v2/`. The controller method keeps its
name and URL; it just flips which templates it renders. HTMX fragment requests return **only** the
inner block.

```php
use App\Helper\TemplatePathHelper as TP;
use App\Helper\ControllerHelper;

public function renderIndex(Request $request, Response $response, $args = [])
{
    $pn  = max(1, (int) ($request->getParam('pn') ?? 1));
    $rpp = max(1, (int) ($request->getParam('rpp') ?? DEFAULT_SERVER_PAGINATION));

    $args['currentPage']     = ControllerHelper::getCurrentPage('common.system.loyalty_card', 'main-loyaltyCardList');
    $args['listLoyaltyCard'] = LoyaltyCard::getList($pn, $rpp);
    $args['nrLoyaltyCard']   = LoyaltyCard::getListNrResult();
    $args['pn']              = $pn;
    $args['rpp']             = $rpp;

    // HTMX paginates/filters the list block in place — return ONLY the fragment.
    if ($request->getHeaderLine('HX-Request')) {
        return $this->ci->renderer->render($response, TP::p('v2/loyaltyCard/module/_list'), $args);
    }

    $this->ci->renderer->render($response, TP::p('v2/include/header'), $args);
    $this->ci->renderer->render($response, TP::p('v2/loyaltyCard/index'), $args);
    return $this->ci->renderer->render($response, TP::p('v2/include/footer'), $args);
}
```

### The `$args` contract for the shell

| Key | Set with | Purpose |
|---|---|---|
| `$args['currentPage']` | `ControllerHelper::getCurrentPage($titleKey, $menuShort)` | Page title + active sidebar item. **Always set it.** |
| `$args['backOfficeHeader']` | a rendered partial string | Optional page-level chrome injected into the navbar (date pickers, filters). Replaces v1's `JsHelper::addMoveToBackOfficeHeader`. |
| `$args['pageModule']` | e.g. `'mailbox'` | **Vue islands only.** `footer.phtml` then loads `dist/{pageModule}.js`. Omit for Alpine/htmx pages. |

The header injects `Zero.*` (lang, currency config, daemon-core token) and loads `dist/app.css`.
The footer loads `dist/app.js` (Alpine, htmx, `list.js`, Tom Select) + the daemon bridge. You don't
touch those — they're the shared runtime.

**No invented page chrome.** No `<h1>` page title, no back arrow, no top-of-page "New" heading —
the title lives in the navbar. The "New" action is a small button in the card header (§4) or a menu
item. (See `feedback_no_invented_page_chrome`.)

---

## 3. Backend layering (where code goes)

```
routes ──► Controller (passing point) ──► Manager / Service (logic) ──► Model / DTO (persistence + shape)
```

- **Controller = parse request → call Manager/Service → return Response.** No DB queries, no business
  logic, no shape-shifting. A 3-line pipe is correct. >~30 lines means something belongs elsewhere.
- **Model owns finders + array shape.** `getList($pn,$rpp)`, `getListNrResult()`, `getOneById()`,
  `getOneByX()`, `getListByX()`, `getStoreArray()`. **Never raw SQL** — AutoDb/AutoRecord only
  (`/CODING_STANDARDS.md`). `create()` returns unsaved; caller calls `->store()`.
- **DTO only when transformation is real** (aggregation, computed fields, external contract). Not for
  a 1:1 mirror of one model.
- **One controller per domain**, method names = the action (`list`, `one`, `update`, `create`,
  `delete`, `renderEditForm`) — **no `api` prefix**, no page-shaped controllers.

### Routes

SSR pages go in `src/routesAdmin.php`. JSON endpoints for the v2 frontend go in
`src/routesAdminApi.php` (or `routesAdminLocalApi.php` for Trace/local + reverse-proxy). Same
Manager/Service powers both surfaces — never duplicate logic across them.

```php
$app->group('/period', function () use ($app) {
    $app->get('',                     'App\Controller\Admin\PeriodController:index');           // page
    $app->get('/detail/{idPeriod}',   'App\Controller\Admin\PeriodController:renderEditForm');  // modal body fragment
    $app->post('/create',             'App\Controller\Admin\PeriodController:create');          // JSON envelope
    $app->post('/update/{idPeriod}',  'App\Controller\Admin\PeriodController:update');          // JSON envelope
});
```

### JSON response shape (locked — never `ok:true/false`)

- **Read/list:** the plain payload (an array, or one item). No envelope.
- **Write/create/update:** the row-swap envelope, rendered **server-side** so the row design lives in
  one place:
  ```php
  return ControllerHelper::jsonResponse($response, array(
      'status'  => 'success',
      'message' => T::t('common.label.saved_correctly'),
      'id'      => $period->getId(),
      'row'     => $this->ci->renderer->fetch(TP::p('v2/period/module/_row'), array('period' => $period)),
  ));
  ```
- **Error:** `{'status':'error', 'errors':{'field':'code'}, 'message':'optional'}` — field-keyed errors
  render as Bootstrap 5 `.is-invalid` + `.invalid-feedback`; the modal stays open, values preserved.
  In practice you throw and let the helpers build it:
  `ExceptionHelper::throwEssentialInformationMissing(...)`, `throwAlreadyExistObj(...)`,
  `throwDoesNotExistObj(...)` → caught → `jsonResponse(['status'=>'error','message'=>$e->getMessage()])`.

---

## 4. Worked example — list page (the default shape)

Three template files under `templates/adminlte/v2/<feature>/`.

### `index.phtml` — page entry (card + table + modals)

```php
<?php
use App\Model\Translation\T;
/** @var \App\Model\Period\Period[] $listPeriod */
?>
<div id="periodList" class="card">
    <div class="card-header">
        <h3 class="card-title"><?php echo T::t('common.label.list'); ?></h3>
        <div class="card-actions">
            <input type="search" class="form-control form-control-sm"
                   placeholder="<?php echo T::t('common.label.search'); ?>" data-list-filter="#periodList">
            <button type="button" class="btn btn-primary btn-sm ms-2"
                    data-bs-toggle="modal" data-bs-target="#periodNewModal">
                <i class="ti ti-plus me-1"></i><?php echo T::t('common.label.new'); ?>
            </button>
        </div>
    </div>
    <div class="table-responsive list-scroll">
        <table class="table table-vcenter table-hover card-table">
            <thead>
            <tr>
                <th data-sort data-sort-as="number"><?php echo T::t('common.label.id'); ?></th>
                <th data-sort><?php echo T::t('common.label.name'); ?></th>
                <th><?php echo T::t('common.label.status'); ?></th>
                <th data-sort><?php echo T::t('common.label.from_date'); ?></th>
            </tr>
            </thead>
            <tbody>
            <?php
            foreach ($listPeriod as $period) {
                include __DIR__ . '/module/_row.phtml';
            }
            ?>
            </tbody>
        </table>
    </div>
</div>

<!-- Edit modal: body fetched from data-list-edit-url on row click -->
<div class="modal modal-blur fade" id="periodModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title"><?php echo T::t('common.label.edit'); ?></h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div class="text-center text-secondary p-4"><?php echo T::t('common.label.loading'); ?>…</div>
            </div>
        </div>
    </div>
</div>

<!-- New modal: body embedded inline (no fetch needed) -->
<div class="modal modal-blur fade" id="periodNewModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title"><?php echo T::t('common.label.new'); ?></h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body"><?php include __DIR__ . '/module/_newForm.phtml'; ?></div>
        </div>
    </div>
</div>
```

> If the list must be HTMX-swappable for pagination, split the `<div id="…List">…</div>` block into a
> `module/_list.phtml` and `include` it from `index.phtml` — that fragment is what the controller
> returns on `HX-Request` and what pagination targets. LoyaltyCard does exactly this. Add the footer
> pager with `InnerTemplateRender::renderServerPaginationV2(['route'=>'/loyalty-card','nrResult'=>$n,'pn'=>$pn,'rpp'=>$rpp,'target'=>'#loyaltyCardList'])`.

### `module/_row.phtml` — the ONE place a row's design lives

```php
<?php
use App\Helper\DateHelper;
use App\Manager\OwnerManager;
use App\Model\Period\Period;
/** @var Period $period */
?>
<tr id="row-<?php echo $period->getId(); ?>"
    data-list-edit-url="/period/detail/<?php echo $period->getId(); ?>"
    data-list-edit-modal="#periodModal">
    <td><?php echo $period->getId(); ?></td>
    <td><?php echo htmlspecialchars($period->getName()); ?></td>
    <td><?php echo $period->renderStatus(); ?></td>
    <td data-sort-value="<?php echo $period->getFromDate(); ?>"><?php echo DateHelper::pgsqlToHumanDate($period->getFromDate()); ?></td>
</tr>
```

Two row-interaction styles — pick one:
- **Row opens an edit modal:** `data-list-edit-url="…"` + `data-list-edit-modal="#xModal"` (fetches
  the fragment into the modal body, opens it). Use `id 0`/a `/detail/0` route to reuse the same modal
  for "create" if you prefer that over a separate new-modal.
- **Row navigates to a detail page:** `data-list-row-link="/x/detail/{id}"` (cmd/middle-click opens a
  new tab). Put action buttons in a `<td data-list-row-no-link>` so they don't trigger navigation.

The `row` returned by `update`/`create` is this exact template — `list.js` swaps `#row-{id}` on
success. **Never build row HTML in JS.**

### `module/_editForm.phtml` — the modal form body

```php
<form action="/period/update/<?php echo $period->getId(); ?>" method="post"
      data-list-submit data-list-close-modal="#periodModal">
    <div class="row mb-3">
        <label class="col-sm-3 col-form-label"><?php echo T::t('common.label.name'); ?></label>
        <div class="col-sm-9">
            <input type="text" class="form-control" name="name"
                   value="<?php echo htmlspecialchars($period->getName()); ?>" required>
        </div>
    </div>
    <div class="row mb-3">
        <label class="col-sm-3 col-form-label"><?php echo T::t('common.label.status'); ?></label>
        <div class="col-sm-9">
            <select class="form-select" name="status" required>
                <?php echo InnerTemplateRender::renderGenericStatusOption(array(
                    'listStatus' => Period::getListStatus(),
                    'selected'   => $period->getStatus(),
                )); ?>
            </select>
        </div>
    </div>
    <div class="row">
        <div class="col-sm-9 offset-sm-3">
            <button type="submit" class="btn btn-primary">
                <i class="ti ti-device-floppy me-1"></i><?php echo T::t('common.btn.save'); ?>
            </button>
        </div>
    </div>
</form>
```

`data-list-submit` makes `list.js` submit via fetch, expect the JSON envelope, swap the row on
success and render field errors on failure. `data-list-close-modal="#periodModal"` closes the modal
on success. **One save button per form/tab** (see `feedback_form_coherence`).

---

## 5. `list.js` data-attribute reference (authoritative)

`public/assets/adminlte/v2/js/list.js` auto-wires these — you never write the JS:

| Attribute | On | Behaviour |
|---|---|---|
| `data-list-filter="#listId"` | search input | filters rows by `tr.textContent.includes(query)` within the current chunk |
| `data-list-edit-url="…"` + `data-list-edit-modal="#m"` | `<tr>` | click fetches the URL, drops HTML into the modal body, opens it |
| `data-list-row-link="…"` | `<tr>` | click navigates (cmd/middle-click = new tab); interactive children auto-excluded |
| `data-list-row-no-link` | child/`<td>` | excludes that subtree from row-link navigation |
| `data-list-submit` | `<form>` | fetch-submit, JSON envelope, swap `#row-{id}`, render field errors |
| `data-list-close-modal="#m"` | `<form>` | close the named modal on success |
| `data-sort` | `<th>` | click-to-sort (asc→desc). `data-sort-as="number"` for numeric |
| `data-sort-value="…"` | `<td>` | custom sort key for that cell (e.g. raw date behind a formatted one) |
| `data-select-search` | `<select>` | *(legacy opt-in — not needed; see §7 Tom Select)* |

Sort helpers exist too (`data-list-append-table`, `data-list-edit-append-table`) for append-on-scroll
cases — rare; ignore unless you're copying a page that uses them.

---

## 6. List-page shape (locked)

- **Server chunk = 500 rows** (`DEFAULT_SERVER_PAGINATION`). Most tables fit in 1–2 chunks. Cross-chunk
  search → paginate or use `/finder`.
- Table body inside `<div class="table-responsive list-scroll">` (`max-height: 65vh; overflow-y:auto`,
  sticky `<thead>`). Page chrome stays put while rows scroll.
- **No DataTables. No JS-generated rows. No `setInterval` polling of server data** (push via
  daemon-core instead).

---

## 7. Frontend rules (Tabler + Alpine + htmx, no jQuery)

- **No jQuery.** Tabler is jQuery-free. Don't port `$(...)`.
- **Icons are Tabler (`ti ti-<name>`), not FontAwesome.** v2 does **not** load FontAwesome, so a raw `<i class="fa fa-*">` renders as a blank/invisible glyph — a classic "why is nothing showing?" bug. Port every `fa fa-x` to its `ti ti-x` equivalent. Shared v1 helpers that emit fa icons are the trap: `Helper::linkDetail()` now emits **both** `fa` and `ti` classes so it works in v1 and v2 (only one icon font is ever loaded, so only one shows) — safe to use as-is. If you write a *new* inline icon, use `ti`.
- **Single-Bootstrap rule (hard):** never load Tabler's bundled `tabler.min.js` *and* `import bootstrap`
  — they double-register data-API handlers and every dropdown/modal opens-then-instantly-closes. The
  runtime already provides Bootstrap 5 JS via `app.js`; you just write markup with `data-bs-*`.
- **Every `<select>` is auto-upgraded to Tom Select** by the runtime. Don't add opt-in attributes,
  don't leave one styled raw, don't hand-roll a searchable dropdown. (`feedback_v2_all_selects_tomselect`.)
- **Reuse the option renderers** — don't re-roll `<option>` loops. `InnerTemplateRender::renderGenericListKeyOption`,
  `renderGenericStatusOption`, `renderYesNoOption`, etc. emit clean framework-agnostic `<option>`s.
- **Status badges:** for a migrated model, flip `renderStatus()` from v1's `DesignHelper::renderLabel()`
  (BS3) to **`DesignHelper::renderBadge($color, $label)`** (Tabler soft pill). Tabler tokens only:
  `green/lime/yellow/red/orange/teal/blue/azure/purple/pink/secondary/dark` — no `olive`/`gray`/`black`
  (map to `lime`/`secondary`/`dark`). Only flip the helper call when *all* consumers of that model are
  v2; otherwise add a separate badge method. Reference: `LoyaltyCard::renderGenericStatus()`.
- **No `window.*` app state.** Small UI helpers (`window.v2List`, `window.DaemonCore`) are fine; state
  goes in Alpine stores.

### Alpine for page-level reactivity

The default for toggles, small state machines, conditional blocks. Put a tiny inline `<script>` at the
bottom of `index.phtml` only if `list.js` doesn't already cover it; keep it presentational and under
one `window.<page>Page` namespace. Example of the common conditional-block pattern:

```html
<div x-data="{ mode: 'flat' }">
    <select class="form-select" x-model="mode">
        <option value="flat">Flat</option>
        <option value="percent">Percent</option>
    </select>

    <!-- A required field inside a hidden block blocks native submit — bind required to the same condition -->
    <input type="number" name="percent" class="form-control mt-2"
           x-show="mode === 'percent'" x-bind:required="mode === 'percent'">
</div>
```

> **Gotcha (`feedback_v2_conditional_required`):** a `required` field inside an `x-show`-hidden block
> still blocks native form submission. Always bind `x-bind:required` to the same visibility condition.

For a store that reflects a live external source (daemon-core), **seed from the cached state on
`alpine:init`, then listen for updates** — the bridge may have fired before your store attached:

```js
document.addEventListener('alpine:init', () => {
    const initial = window.DaemonCore?.getConnectionState?.() ?? 'connecting';
    window.Alpine.store('daemonCore', { state: initial });
});
window.addEventListener('daemon:connected',    () => window.Alpine?.store('daemonCore') && (window.Alpine.store('daemonCore').state = 'connected'));
window.addEventListener('daemon:disconnected', () => window.Alpine?.store('daemonCore') && (window.Alpine.store('daemonCore').state = 'disconnected'));
```

### htmx for server-driven fragments

Two common uses:

1. **Pagination / list refresh** — the pager (`renderServerPaginationV2`) issues an `HX-Request` GET;
   the controller returns the `_list.phtml` fragment; htmx swaps it into `target`. Already wired by
   the helper — you just provide the fragment branch in the controller (§2).
2. **Tabbed detail pages** — each tab is a server fragment fetched on demand:

   ```html
   <ul class="nav nav-tabs" role="tablist">
       <li class="nav-item">
           <a class="nav-link active" data-bs-toggle="tab" href="#tab-info">Info</a>
       </li>
       <li class="nav-item">
           <a class="nav-link" data-bs-toggle="tab" href="#tab-loyalty"
              hx-get="/customer/detail/<?php echo $idUser; ?>/loyalty"
              hx-target="#tab-loyalty" hx-trigger="load once">Loyalty</a>
       </li>
   </ul>
   <div class="tab-content">
       <div class="tab-pane active" id="tab-info"><?php /* eager content */ ?></div>
       <div class="tab-pane" id="tab-loyalty"><div class="text-secondary p-3">Loading…</div></div>
   </div>
   ```

   The controller has one `renderX` method per tab returning that tab's partial. Reference:
   `templates/adminlte/v2/customer/detail.phtml` + `CustomerController`.

---

## 8. Multi-value form fields — `name="field[]"` (hard rule)

Every `<select multiple>` (and any repeated input) uses `name="field[]"`, and the controller reads it
as an **array** — never `explode(',', …)`.

- v2 `list.js` submits via `FormData` (repeated keys). PHP keeps only the *last* value for a name
  **without** `[]`, so a no-`[]` multi-select through `explode(',')` silently drops all but the last.
  `[]` + `explode` is the inverse crash (`TypeError`). One rule avoids both.
- Controller: `$list = $request->getParam('field', []);` — already an array. Pure-id lists rely on the
  model setter's `array_map('intval', …)`; mixed id/ISO lists use `Helper::normalizeMixedTypeList($list)`.
- **Empty-select gotcha:** an empty multi-select arrives as `['']`, not `[]`. Filter where an empty
  entry is harmful: `array_values(array_filter($list, static fn ($v) => $v !== '' && $v !== null))`.
- Migrating a shared controller: flip the `explode` → array read in the *same* commit that flips the
  template to `[]`. If a method must transiently accept both, guard with `is_array()`.

---

## 9. When to use Vue (almost never)

Default is **Alpine + htmx**. Vue earns a page only when it carries heavy, multi-entity, optimistic
client state that exceeds Alpine's component model — today that's **Trace** and **Mailbox** (both need
realtime daemon-core patching of an in-memory board/thread). A new Vue island is an explicit decision,
not a default. If you're migrating a list, a form, or a tabbed detail page, it is **not** Vue.

If (and only if) a page is genuinely a realtime island, the pattern is: Pinia store with **optimistic +
in-place updates** (never refetch on mutation), daemon-core as a peer that patches the same store
methods, a Vite entry in `vite.config.js`, and `$args['pageModule']` so the footer loads `dist/<x>.js`.
Copy `public/assets/adminlte/v2/js/islands/mailbox/` wholesale and adapt.

---

## 10. PHP / template style (enforced)

- **Braces, never `endif`/`endforeach`** — in `.php` and `.phtml`. Hard rule.
- **Write HTML in template mode** (close `?>`, write markup, reopen `<?php`) — don't `echo "<tr>…"`
  strings, even in loops. (`feedback_no_echo_html_in_templates`.)
- **Partials via `InnerTemplateRender::renderX($args)`** for shared widgets (explicit scoping);
  same-folder row/list partials via `include __DIR__ . '/module/_row.phtml'` is fine and idiomatic.
- **`==` for DB-int / JSON-transited values** (status, role, id — Postgres returns strings). `===` only
  for bool sentinels (`curl_exec() === false`, `$x === null`, `stripos(...) === 0`).
- **No inline `\App\…` FQNs** — add a `use` at the top, reference the short name.
- **Human-facing text through `T::t('block.key')`** — never English literals in responses. Translation
  files are **incremental**: add a *new numbered file* per language, never edit old ones. Per-call
  placeholders use **`{{var}}`** (double braces) — single `{var}` leaks through.
- **IDs are `idLocation`, not `locationId`; lists are `listUser`, not `users`** — applies to JSON keys
  too, so the JS store doesn't translate.
- `foreach` over `array_map(fn…)` for list transforms. Blank line before a meaningful `return`.
  Long-form `<?php echo ?>` in PHTML, not `<?= ?>`. `array()` vs `[]` — match the file you're in.
- **Comments only when the WHY is non-obvious.** No narration, no ticket numbers, no "removed because"
  rot. Delete dead code (git is the rollback) — no compat shims or feature flags.

---

## 11. Definition of done

Tick every box before you call it migrated:

- [ ] Every v1 feature from your §1 list exists in v2 (ported, not improved; nothing dropped).
- [ ] Same URL; the controller method flipped its render path (no parallel method, route, or flag).
- [ ] Controller is a passing point; logic is in a Manager/Service; model has the finders.
- [ ] `index.phtml` + `module/_row.phtml` (+ `_editForm`/`_newForm` if CRUD) under
      `templates/adminlte/v2/<feature>/`. Row design lives only in `_row.phtml`.
- [ ] Write endpoints return `{status, id, row}` (row rendered server-side) / `{status:'error', errors}`.
- [ ] Multi-selects use `name="field[]"` + array read. Conditional-required bound to visibility.
- [ ] `renderStatus()` → `renderBadge()` (Tabler token) *if all consumers are v2*.
- [ ] No jQuery, no invented page chrome, no raw `<select>`, no DataTables, no `setInterval` polling.
- [ ] All human text via `T::t`; new translation keys in a new numbered file.
- [ ] Verified: `php -l` clean on every touched PHP file; `node --check` clean on any JS; page loads,
      list filters/sorts, modal opens, save swaps the row, errors show inline.
- [ ] v1 PHTML left on disk as a dead artifact (don't delete until the slice is production-stable).
- [ ] `/MIGRATION_V1_INVENTORY.md` checkbox ticked (only if *every* feature is present).

---

## 12. Pointers

- `/CLAUDE.md` — hard rules (source of truth).
- `/MIGRATION.md` — target architecture + why.
- `/MIGRATION_V1_INVENTORY.md` — the remaining-pages campaign board.
- `/CODING_STANDARDS.md` — model + controller + AutoDb/AutoRecord patterns.
- Canonical code: `LoyaltyCard` (read-only list), `Period` (CRUD + modals), `Customer`/`Location`
  (tabbed detail), `Trace`/`Mailbox` (Vue islands — the exception, not the rule).
