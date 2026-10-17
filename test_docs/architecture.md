---
type: Architecture Note
title: Architecture
description: "Overview of application startup, domain-selected routing, services, templates, and runtime architecture."
tags: [architecture, slim, routing]
status: active
source_kind: hand-written
timestamp: "2026-06-30T06:51:14Z"
---

# Architecture

## Runtime Shape

The main HTTP application starts in `public/index.php`.

Startup sequence visible in that file:

1. Sets CORS headers and PHP memory/error options.
2. Loads Composer autoload.
3. Loads `.env` values through `src/env.php`, converting environment keys to PHP constants.
4. Defines `AUTODB_ALLOW_PG_COMPOSITE_PK`.
5. Opens the PostgreSQL connection through `App\InstanceCollector\IC::pgFirstConnect()`.
6. Starts the PHP session.
7. Initializes login state, language, paths, and common configuration.
8. Loads domain/theme-specific config files from `includes/`.
9. Instantiates `Slim\App` with `src/settings.php`.
10. Registers dependencies, middleware, and public routes.
11. Selects additional route files from the current `Domain` record.
12. Applies global login protection when configured by the current domain.
13. Runs the Slim app.

Specialized public entry points under `public/` repeat the Slim bootstrapping pattern for narrower surfaces:

- `public/nayax.php` denies access unless the current domain is Nayax.
- `public/pax.php` denies access unless the current domain is Pax.
- `public/pulse.php` denies access unless the current domain is Pulse.
- `public/workstation.php` denies access unless the current domain is Workstation.
- `public/device.php` also checks `Domain::currentDomain()->isWorkstation()` before loading route files.

These files load route files from the current domain record after the surface check.

## Domain-Selected Routing

`App\Model\Domain::currentDomain()` resolves the active domain from `$_SERVER['HTTP_HOST']`, a cached CLI host, or `REQUEST_URI_FORCE`. Domain rows contain `theme`, `route_file`, `route_file_logged`, and protection flags. `public/index.php` loads route files named in those database fields.

The initial SQL creates domains for:

- Backoffice: theme `adminlte`, routes `routesAdmin routesAdminApi`.
- Vitrine: theme `stack`, routes `routesStack`.
- Nayax API: theme `nayax`, routes `routesNayaxApi`.
- Auth: theme `gatewayAuth`, routes `routesAuth`.

Later SQL migrations add additional domain rows:

- Workstation: theme `workstation`, routes `routesWorkstationApi` in `sqlinstall00103.sql`.
- Device Coolcode: theme `device`, routes `routesDeviceCoolcodeApi` in `sqlinstall00171.sql`.
- Pax/payment terminal: theme `pax`, routes `routesPaymentTerminalApi` in `sqlinstall00215.sql`.

## Layers

- `App/Controller/`: Slim controllers grouped by surface and feature.
- `App/Manager/`: service/business logic and integration managers.
- `App/Model/`: AutoDb-backed models and `NoDb` constant/configuration models.
- `App/DTO/`: data transfer objects used across controllers, managers, and integrations.
- `App/View/`: PHP template render helpers.
- `templates/`: PHP view templates for themes and email.
- `src/routes*.php`: route definitions.
- `src/settings.php`: Slim settings and CLI command registry.
- `App/Command/`: command classes registered in settings and used by CLI/cron workflows.

## Shared Services

`App\InstanceCollector\IC` is the central service locator for:

- PostgreSQL connection. `IC::pgFirstConnect()` hardcodes `host=database` and reads port, password, user, and database name from env constants.
- AutoDb instance.
- Redis connection to host `cache` on port `6379`.
- Transaction helpers.

`src/dependencies.php` registers:

- `renderer`: `Slim\Views\PhpRenderer` pointed at `templates/`.
- `logger`: Monolog stream handler writing to `logs/app.log`.

`src/middleware.php` registers `adrianfalleiro\SlimCLIRunner`.

## CLI Command Runner

`command/v2/index.php` runs only under `PHP_SAPI == 'cli'`. It loads `.env`, sets the CLI host cache from `CLI_DOMAIN`, connects to PostgreSQL, sets the current user to `SYS`, loads `src/routesAdmin.php`, and lets Slim CLI runner dispatch registered commands. Command classes expose a `command($argv)` method and are registered by name in `src/settings.php`.

## Frontend Architecture

The React project in `react/` is a separate package named `reporting-dashboard`. Its Webpack build emits `bundle.js` into `public/assets/adminlte/js/analysis/react/dist/`.

The React code uses:

- React and React DOM.
- Material UI.
- Highcharts.
- Axios client with base URL `/local/api/v1`.
- Reporting and issue services under `react/src/services/`.
