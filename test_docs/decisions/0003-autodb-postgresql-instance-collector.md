---
type: ADR
title: "ADR 0003: Use AutoDb with PostgreSQL Through a Shared Instance Collector"
description: "Decision to access PostgreSQL primarily through AutoDb instances managed by the shared instance collector."
tags: [adr, postgresql, autodb]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0003: Use AutoDb with PostgreSQL Through a Shared Instance Collector

## Status

Accepted in code.

## Context

`composer.json` requires `salvosav/autodb`. `App\InstanceCollector\IC` owns the PostgreSQL resource, initializes AutoDb, exposes `IC::adb()`, and provides transaction helpers. `IC::pgFirstConnect()` hardcodes PostgreSQL host `database` and reads the remaining connection values from environment constants.

## Decision

Use PostgreSQL as the database and access it primarily through AutoDb instances exposed by `App\InstanceCollector\IC`.

## Consequences

Models wrap AutoDb rows and frequently expose typed getters/setters over table columns. Shared connection state is centralized in `IC`; the PostgreSQL service name is coupled to the Docker Compose service name `database`.
