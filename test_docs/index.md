# SapiensCore Knowledge Bundle

Start here when navigating project knowledge. This folder is an OKF-light knowledge bundle using the [OKF-light standard](OKF-STANDARD.md); navigation and history files are exempt from concept frontmatter. Agents may also inspect generated `knowledge-graph.json` for machine-readable discovery, then read linked Markdown as the source of truth.

## Project and Architecture

- [Project overview](project-overview.md) — capabilities, technology stack, and entry points.
- [Architecture](architecture.md) — runtime startup, routing, services, and templates.
- [Modules](modules.md) — application modules, route surfaces, and integrations.
- [Architecture decisions](decisions/index.md) — accepted architectural choices and consequences.

## Interfaces and Data

- [API reference](apis.md) — public, administrative, authentication, device, and integration APIs.
- [Database](database.md) — database access, migrations, and schema areas.
- [Readonly/Admin permissions](permissions-readonly-admin.md) — authorization model and migration status.
- [Product import matching](product-import-matching.md) — how imported rows bind to existing products and how conflicts are resolved.
- [UI knowledge](ui/index.md) — template relationships and UI impact mapping.

## Development and Operations

- [Deployment](deployment.md) — runtime services, configuration, assets, and database setup.
- [Testing](testing.md) — available automated and manual checks.
- [Tabler, HTMX, and Alpine migration](tabler-htmx-alpine-migration.md) — migrated-template tracker.
- [Skills](skills/index.md) — repository skill catalog.

## Bundle Maintenance

- [OKF-light standard](OKF-STANDARD.md) — metadata, classification, navigation, and history rules.
- `knowledge-graph.json` — generated machine-navigation graph built by `python3 docs/build_okf_graph.py`.
- [Knowledge-base log](log.md) — significant documentation changes in reverse chronological order.
- [Legacy wiki overview](README.md) — preserved original generated wiki map.
