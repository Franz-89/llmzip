---
type: ADR
title: "ADR 0008: Register CLI Commands in Application Settings"
description: "Decision to centralize CLI command registration in Slim application settings."
tags: [adr, cli, configuration]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0008: Register CLI Commands in Application Settings

## Status

Accepted in code.

## Context

`src/settings.php` contains a large `commands` array mapping command names to classes under `App\Command\...`. `src/middleware.php` registers `adrianfalleiro\SlimCLIRunner`.

## Decision

Register application CLI commands in Slim settings.

## Consequences

Command availability is centralized in `src/settings.php`. CLI/cron workflows can address command classes by configured names.
