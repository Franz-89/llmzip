---
type: ADR
title: "ADR 0007: Use Redis as Shared Cache/Runtime Store"
description: "Decision to use Redis as the shared application cache and runtime store."
tags: [adr, redis, cache]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0007: Use Redis as Shared Cache/Runtime Store

## Status

Accepted in code.

## Context

Docker Compose defines a `cache` service using `redis:latest`. `App\InstanceCollector\IC::redis()` instantiates `Redis` and connects to host `cache` on port `6379`.

## Decision

Use Redis as a shared runtime/cache service.

## Consequences

Code that calls `IC::redis()` requires the `cache` service to be reachable. Redis key scans are centralized through `IC::redisGetAllOpt()`.
