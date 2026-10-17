---
type: Runbook
title: Deployment
description: "Operational guidance for Docker Compose services, environment configuration, assets, and database setup."
tags: [deployment, docker, configuration]
status: active
source_kind: hand-written
timestamp: "2026-06-30T06:51:14Z"
---

# Deployment

## Docker Compose

The repository contains `docker-compose.yaml` and `docker-compose.example.yaml`.

Services in the main compose file:

- `tailscale`: `tailscale/tailscale:latest`, privileged, attached to `tailscale_net`.
- `core-nginx`: `salvatorecampanella/core-nginx:latest`, maps host port `80` to container port `80`, mounts the repository, and depends on `sapienscore`.
- `sapienscore`: `salvatorecampanella/core-php:latest`, mounts the repository and migration state volume, receives PostgreSQL/Redis/domain/Tailscale environment variables.
- `database`: `timescale/timescaledb:2.16.1-pg16`, exposes `5432`, stores data in `postgres_data`, and has a `pg_isready` healthcheck.
- `cache`: `redis:latest`, stores data in `redis_data`.

Compose networks include `public_net`, `internal_net`, `tailscale_net`, and an external `shared_docker_net`.

`docker-compose.example.yaml` is similar, but does not define a separate `tailscale` service. Instead, it passes Tailscale-related environment variables into the `sapienscore` service.

## Environment

`.env.example` documents configuration for:

- Server role and domains.
- PostgreSQL and Redis.
- Tailscale.
- Login, email, notifications, translations, owners, and module selection.
- Sapiens accounting and Sapiens client integration.
- Nayax, Vendus, AWS, Odoo, FCM, Cloudflare, and documentation API values.

Cloudflare-related code under `App/Service/Storage/Cloudflare/` uses environment values for Stream, Images, and R2 storage. Issue attachments use those services and fall back to local storage when the Cloudflare services are not configured.

`src/env.php` reads `.env`, converts values to PHP constants, and can generate `env_constants.php` when `ENV_HELPER=true`.

## Assets

The React reporting dashboard builds from `react/` into:

`public/assets/adminlte/js/analysis/react/dist/bundle.js`

Available React scripts:

- `npm start`
- `npm run build`
- `npm run build:dev`
- `npm test`
- `npm run lint`

## Database Setup

The database initialization script documents this usage:

`cd utility/ && php initDatabase.php init backoffice.domain vitrine.domain`

The same script also reads `$argv[4]` as `$nayaxDomain` and replaces `{{nayax.domain}}` in the first SQL file. The usage string in the script does not list that argument, but the code expects it when initializing the seeded Nayax domain.

The update script documents this usage:

`cd utility/ && php updateDatabase.php update`

`utility/updateDatabase.php` also optionally reads a backoffice domain and workstation domain from `$argv[2]` and `$argv[3]` for migrations containing workstation, device, and Pax domain placeholders.
