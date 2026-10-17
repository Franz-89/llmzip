---
type: Data Model
title: Database
description: "Reference to database engines, access patterns, migrations, and major schema areas."
tags: [database, postgresql, migrations]
status: active
source_kind: hand-written
timestamp: "2026-06-30T06:51:14Z"
---

# Database

## Database Engine

Docker Compose uses `timescale/timescaledb:2.16.1-pg16` for the `database` service. Application code connects through PostgreSQL functions in `App\InstanceCollector\IC`.

Connection details are read from `.env` constants:

- `POSTGRES_PORT`
- `POSTGRES_PASSWORD`
- `POSTGRES_DATABASE`
- `POSTGRES_USER`

Although Docker Compose sets `POSTGRES_HOST=database` for the PHP container, `App\InstanceCollector\IC::pgFirstConnect()` does not read that variable; it hardcodes `host=database`.

Redis is also configured in Docker Compose as service `cache`; application code connects to Redis at host `cache`, port `6379`.

## Access Pattern

Models use `salvosav/autodb` through `IC::adb()` and `IC::adbNewInstance()`. The repository also uses direct `pg_query` in database utilities and transaction helpers.

## Migrations

SQL migrations live in `utility/sql/` and are named `sqlinstallNNNNN.sql`. At inspection time the repository contains migrations up to `sqlinstall00312.sql`.

Database utilities:

- `utility/initDatabase.php`: initializes a new database by executing ordered SQL files, replacing initial domain placeholders, initializing migration tracking, and seeding domain tokens/business info.
- `utility/updateDatabase.php`: executes missing SQL files after the last recorded migration.
- `utility/migrationStatus.php`: creates and reads the `db_migrations` migration tracker table and writes `db_init/dbSqlStatus.txt` for backward compatibility.

`db_init/` is mounted as the migration status directory in Docker Compose.

## Schema Themes Visible In SQL

The migrations define or alter tables for domains, users, translations, articles, sys/debug logs, subscriptions, tickets, files, payments, merchants, wallets, organizations, locations, loyalty cards, Nayax, Ethoca, Sapiens workstation, devices, games, reservations, vouchers, marketing, cron statuses, materialized views, Odoo, SII, payment terminals, PDA, monitoring, NFC payment, documentation, and more.

Documentation-related tables are introduced in `sqlinstall00311.sql`: `documentation_view`, `course_user_progress`, and `course_user_answer`.

SQL also defines:

- Timestamp trigger function `set_updated_timestamp()`.
- JSON history trigger function `log_changes_to_json()`.
- Materialized views such as mailbox, payment transaction, subscription, payment location, game performance, Nayax performance, EMV performance, and payment-location-item views.
- PostgreSQL extensions `pg_trgm` and `fuzzystrmatch` in `sqlinstall00216.sql`.
- Timescale retention policies for `sys_log` and `debug_log` in `sqlinstall00312.sql`.
