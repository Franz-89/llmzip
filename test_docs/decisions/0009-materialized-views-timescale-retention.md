---
type: ADR
title: "ADR 0009: Use Materialized Views and Timescale Retention for Reporting/Logs"
description: "Decision to use materialized views for reporting and Timescale retention policies for selected logs."
tags: [adr, reporting, timescaledb]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0009: Use Materialized Views and Timescale Retention for Reporting/Logs

## Status

Accepted in code.

## Context

SQL migrations create materialized views for reporting domains such as payment transactions, subscriptions, mailbox, payment location, game performance, Nayax performance, EMV performance, and payment-location-item daily data. Docker Compose uses TimescaleDB. `sqlinstall00312.sql` adds retention policies for `sys_log` and `debug_log`.

## Decision

Use database-level materialized views for reporting data and Timescale retention policies for selected log hypertables.

## Consequences

Reporting logic depends partly on database objects created by migrations. Log retention is managed in the database for at least `sys_log` and `debug_log`.
