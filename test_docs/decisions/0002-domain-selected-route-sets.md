---
type: ADR
title: "ADR 0002: Select Route Sets by Domain Records"
description: "Decision to select route sets and theme behavior from the active domain record."
tags: [adr, routing, domain]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0002: Select Route Sets by Domain Records

## Status

Accepted in code.

## Context

`Domain::currentDomain()` resolves the active domain from the request host. The `domain` table stores `theme`, `route_file`, `route_file_logged`, and protection flags. `public/index.php` loads route files from those domain fields.

## Decision

Select application route sets and theme behavior dynamically from the current domain record.

## Consequences

One deployed codebase can expose different surfaces for admin, front themes, Nayax, gateway auth, trackers, workstation, and other domain types. Route availability depends on database domain configuration.
