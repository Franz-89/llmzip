# Task: gate Product Import behind a real permission (replace `canAdminH()`)

## Problem

The Product → Import menu entry is visible to anyone with product-admin permission, but every
endpoint of the feature is hard-gated to HQ accounts. A normal product admin sees the link and
gets "Access denied" on click.

- Menu gate: `App/View/Menu/MenuConfig.php:103` — `visible => $c->can(PermissionArea::PRODUCT, PermissionLevel::ADMIN)`
- Endpoint gate: `App/Controller/Admin/Product/ProductImportController.php` — six methods each start with
  `if (!Login::currentUser()->canAdminH()) { … deny … }` (lines 47, 74, 101, 132, 176, 223).
  `canAdminH()` = Sapiens ∨ Sys ∨ Api (`App/Model/User/User.php`).

Decision (Salvatore, 2026-08-24): the import must be governed by a **dedicated permission token**,
so operators can grant it per person instead of it being HQ-only, and the menu and the endpoints
agree with each other.

## Target design

1. **New flat token** `product_import` in `App/Model/NoDb/Permission.php`:
   ```php
   const PRODUCT_IMPORT = 'product_import';
   ```
   Follow the file's existing layout (constants block + any `$listName`-style metadata the file
   keeps per token). Precedent for a "capability that isn't an area×level pair":
   `Permission::VOUCHER_BULK_GENERATION` (`App/Model/NoDb/Permission.php:42`, hierarchy entry at line ~206).

2. **No implication chain.** `product_import` implies nothing and is implied by nothing.
   Do NOT hang it under the `product` area's ADMIN token — the whole point is that product-admin
   alone must not grant it. Do not add it to `Permission::$listPermissionHierarchy`.

3. **Type defaults** (`Permission::$listPermissionByType` in the same file):
   add `Permission::PRODUCT_IMPORT` to the `UserType::TYPE_SAPIENS` bundle (array starts at
   `App/Model/NoDb/Permission.php:450`). Sys and API are automatic superusers
   (`UserPermission::hasPermission()` short-circuits for them), so this exactly preserves today's
   effective access — Sapiens/Sys/Api — while making it grantable to anyone else per person.
   Do NOT add it to `TYPE_MANAGER` or any other type's defaults.

4. **Catalog entry** so the permission tab and the recap render it readably:
   `App/Model/NoDb/PermissionCatalog.php` has a `private static array $standalone` (line ~101) for
   tokens that map to no area (see `NAYAX_GROUP`, `PULSE_LOG_STREAM` entries there). Add:
   - label: `Product import`
   - description: `Bulk product import: create/update products, warehouse stock movements and stock resets from CSV files.`
   Follow the file's `T::t(...)`-with-English-fallback pattern and register any new translation key
   in `translationKeys()` like its neighbours.

5. **Route gating via middleware**, not per-method checks.
   In `src/routesAdmin.php` the import group is at lines 980–989 (`$app->group('/import', …)`
   inside the `/product` group). Attach:
   ```php
   })->add(PermissionMiddleware::token(Permission::PRODUCT_IMPORT));
   ```
   `PermissionMiddleware::token(...)` already exists — see its own doc block
   (`App/Middleware/PermissionMiddleware.php:19`) and the group-level precedent
   `->add(PermissionMiddleware::area(PermissionArea::USER, PermissionLevel::ADMIN))` at
   `src/routesAdmin.php:182`. The middleware already returns a 403 JSON envelope for
   HTMX/XHR/JSON callers and a 302 redirect for plain GETs — the import page is htmx-heavy,
   so this behaviour is what we want.

6. **Remove the six `canAdminH()` guards** from `ProductImportController`
   (the `if (!Login::currentUser()->canAdminH()) …` blocks at lines 47, 74, 101, 132, 176, 223).
   The middleware is now the single gate. Remove any `use` imports that become unused.

7. **Menu**: change `App/View/Menu/MenuConfig.php:103` from
   `$c->can(PermissionArea::PRODUCT, PermissionLevel::ADMIN)` to a token check on
   `Permission::PRODUCT_IMPORT`. Look at how `MenuContext` exposes token checks (other entries in
   the same file use `$c->can(...)`, `$c->adminH()`, `$c->sys()`; if `MenuContext` has no
   token-level helper yet, add one mirroring how `Permission`/`UserPermission` checks flat tokens —
   keep it consistent with whatever `NAYAX_GROUP`-gated menu entries use, see
   `App/View/Menu/MenuConfig.php` around the Nayax group).

## Conventions that apply (do not skip)

- **Read the models before calling getters** — don't guess method names on `Login::currentUser()`,
  `MenuContext`, `PermissionMiddleware`.
- **Never hard-code the token string** at call sites — always `Permission::PRODUCT_IMPORT`.
- `==` for DB/JSON-transited values; `===` only for bool sentinels. Braces always, no
  alternative PHP syntax. No inline `\App\…` FQNs — `use` statements.
- **Translation keys**: any new human-facing string goes through `T::t()` with keys added in
  **new numbered files** `translation/translation_utility/adminlte/{en,es,pt}/` —
  current heads: `en_00207`, `es_00199`, `pt_00186` → create `en_00208`, `es_00200`, `pt_00187`.
  Never edit an existing numbered file (the importer skips already-imported files).
  Import on dev with:
  `docker exec core-dev-sapienscore-1 sh -c 'cd /var/www/html/sapienscore/command/v2 && php index.php ImportTranslationToRedis adminlte <lang>'`
- **Owner defaults**: no action needed. `owner_permission_default` rows override the static
  bundles per (owner, type); owners that never customized fall back to the static code, so the
  Sapiens-bundle addition takes effect everywhere by default. Do not write a migration for it.
  (`/PERMISSIONS.md` is the authoritative reference for the whole permission system —
  `/permissions-readonly-admin.md` is stale, ignore it.)
- **Scope**: this task is only the gating swap. Do not refactor other `canAdminH()` call sites,
  do not touch `ProductImportManager`, do not change the import feature itself.

## Acceptance checks

1. `Sys` user: menu entry visible, all `/product/import*` endpoints work (unchanged).
2. A `Manager` **without** the grant: menu entry hidden; direct `GET /product/import` redirects
   to `/`; htmx POSTs (e.g. `/product/import/preview`) return the middleware's 403 JSON envelope.
3. The same Manager **granted** `product_import` from the user detail → Permission tab
   (grant works because a Sys/Sapiens actor holds the token — remember the "can only grant what
   you hold" rule): menu entry appears, full import flow works end to end
   (upload → preview → edit row → save), including the process re-run path.
4. Revoking the grant returns them to state 2 without touching anything else.
5. The token renders with its label/description in: the user Permission tab (type bundle for a
   Sapiens user, personal grant for others), and `/permission/recap` (Sys).
6. `grep -n canAdminH App/Controller/Admin/Product/ProductImportController.php` → no matches.
7. No behaviour change for any other route in `src/routesAdmin.php`.
