---
type: Project Overview
title: SapiensCore LLM Wiki
description: "Legacy overview and page map for documentation generated from repository evidence."
tags: [project, documentation, navigation]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# SapiensCore LLM Wiki

This wiki is generated from the repository contents. It intentionally records only facts visible in code, configuration, SQL, and package metadata.

## Pages

- [Project overview](project-overview.md)
- [Architecture](architecture.md)
- [Modules](modules.md)
- [Database](database.md)
- [APIs](apis.md)
- [Deployment](deployment.md)
- [Testing](testing.md)
- [Readonly/Admin permission refactor](permissions-readonly-admin.md)
- [AdminLTE UI template map](ui/template-map.md)
- [Tabler, HTMX, and Alpine migration](tabler-htmx-alpine-migration.md)
- [Skills](skills/README.md)
- [Architecture decisions](decisions/README.md)

## Repository Signals Used

- PHP application entry point: `public/index.php`
- Slim route files: `src/routes*.php`
- Dependency and command configuration: `composer.json`, `src/settings.php`, `src/dependencies.php`, `src/middleware.php`
- Environment loading: `src/env.php`, `.env.example`
- Docker configuration: `docker-compose.yaml`, `docker-compose.example.yaml`
- Database migrations and utilities: `utility/sql/`, `utility/initDatabase.php`, `utility/updateDatabase.php`, `utility/migrationStatus.php`
- React dashboard package: `react/package.json`, `react/webpack.config.js`, `react/src/`
- Repository skills: `.agents/skills/*/SKILL.md`
