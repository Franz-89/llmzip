---
type: ADR
title: "ADR 0005: Run the Application With Docker Compose Services"
description: "Decision to run application infrastructure through Docker Compose service names and configuration."
tags: [adr, docker, runtime]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0005: Run the Application With Docker Compose Services

## Status

Accepted in code.

## Context

`docker-compose.yaml` defines services for nginx, PHP, TimescaleDB/PostgreSQL, Redis, and Tailscale. The PHP code connects to PostgreSQL using host `database` and Redis using host `cache`, matching service names. `docker-compose.example.yaml` passes Tailscale settings into the PHP service instead of defining the separate `tailscale` service used in the main compose file.

## Decision

Run the local/application stack with Docker Compose service names as runtime infrastructure addresses.

## Consequences

Application runtime depends on compose-provided services and environment variables. Volumes preserve PostgreSQL, Redis, migration state, user-stored assets, and Tailscale state.
