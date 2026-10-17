# Architecture Decisions

- [ADR 0001: Use Slim as the PHP HTTP Framework](0001-use-slim-php-framework.md) — selects Slim and Slim PHP View.
- [ADR 0002: Select Route Sets by Domain Records](0002-domain-selected-route-sets.md) — makes route and theme selection domain-driven.
- [ADR 0003: Use AutoDb with PostgreSQL Through a Shared Instance Collector](0003-autodb-postgresql-instance-collector.md) — centralizes database access through `IC`.
- [ADR 0004: Manage Schema With Ordered SQL Install Files](0004-ordered-sql-migrations.md) — defines custom ordered SQL migrations.
- [ADR 0005: Run the Application With Docker Compose Services](0005-docker-compose-runtime.md) — defines service-based runtime infrastructure.
- [ADR 0006: Embed a React Reporting Dashboard Into Admin Public Assets](0006-react-reporting-dashboard-bundle.md) — places the React bundle in PHP public assets.
- [ADR 0007: Use Redis as Shared Cache/Runtime Store](0007-redis-cache-service.md) — defines shared Redis use.
- [ADR 0008: Register CLI Commands in Application Settings](0008-command-registry-in-settings.md) — centralizes command registration.
- [ADR 0009: Use Materialized Views and Timescale Retention for Reporting/Logs](0009-materialized-views-timescale-retention.md) — defines reporting and log-retention database features.
- [ADR 0010: Use Readonly/Admin Permission Levels](0010-use-readonly-admin-permission-levels.md) — separates read and mutation authorization.

The preserved [generated ADR catalog](README.md) provides the earlier index.
