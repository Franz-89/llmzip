---
type: ADR
title: "ADR 0004: Manage Schema With Ordered SQL Install Files"
description: "Decision to manage schema changes with ordered SQL files and custom PHP migration utilities."
tags: [adr, database, migrations]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0004: Manage Schema With Ordered SQL Install Files

## Status

Accepted in code.

## Context

Database SQL lives in `utility/sql/sqlinstallNNNNN.sql`. `utility/initDatabase.php` executes all SQL files in sorted order. `utility/updateDatabase.php` executes missing files after the last recorded migration. Both use `MigrationStatus`, which creates/reads `db_migrations` and also writes `db_init/dbSqlStatus.txt` for backward compatibility.

## Decision

Manage schema changes with ordered SQL files and custom PHP init/update utilities.

## Consequences

The database schema is defined by SQL files rather than a framework migration DSL. Migration order is encoded in filenames and execution state is tracked in the database through the migration status utility, with a legacy text-file status write still present.
