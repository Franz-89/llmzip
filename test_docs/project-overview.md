---
type: Project Overview
title: Project Overview
description: "Overview of SapiensCore capabilities, technology stack, entry points, and package structure."
tags: [project, architecture, technology]
status: active
source_kind: hand-written
timestamp: "2026-06-30T06:51:14Z"
---

# Project Overview

SapiensCore is a PHP 8.3 web application built on Slim. The repository contains a large server-rendered PHP application, domain-selected route surfaces, background command scripts, SQL migrations, and a React reporting dashboard that is built into the PHP public assets.

The Composer package name is `smartmonkey-sl/core`. Composer autoloads `App\` from `App/` and `Tests\` from `tests/`.

## Main Capabilities Visible In Code

- Admin backoffice routes and templates.
- Public/front routes for themes such as `porto`, `glass`, and `stack`.
- Gateway/auth APIs for NUC, Sapiens client, PDA, provisioning, and device integrations.
- Nayax, PulseBox, payment terminal, workstation, Telegram, WhatsApp, Mailgun, Ethoca, Odoo, SII, Vendus, Stripe, AWS, Google, Bing Ads, and Cloudflare-related integration code or configuration.
- Reporting and analytics, including materialized views and a React reporting dashboard.
- Database initialization and ordered SQL update scripts.
- Scheduled cron scripts and CLI commands.

## Technology Stack

- PHP 8.3, Slim, Slim PHP View, Monolog.
- PostgreSQL through `pg_*` functions and `salvosav/autodb`.
- Redis through the PHP Redis extension.
- TimescaleDB image in Docker Compose.
- React, TypeScript, Material UI, Highcharts, Axios, Webpack, Tailwind CSS for the reporting dashboard in `react/`.
- Docker Compose services for nginx, PHP, PostgreSQL/TimescaleDB, Redis, and Tailscale.

## Entry Points

- HTTP web entry: `public/index.php`.
- Specialized public PHP entry files: `public/device.php`, `public/nayax.php`, `public/pax.php`, `public/pulse.php`, `public/workstation.php`.
- CLI command runner entry point: `command/v2/index.php`.
- Cron scripts: files under `cron/`.
- Database utilities: `utility/initDatabase.php` and `utility/updateDatabase.php`.

The specialized public entry files follow the same Slim boot pattern as `public/index.php`, but add surface checks before loading domain route files. For example, `public/nayax.php` requires a Nayax domain, `public/pax.php` requires a Pax domain, `public/pulse.php` requires a Pulse domain, and `public/workstation.php` requires a Workstation domain.

## Package Notes

The repository root `package.json` declares only the `js-cookie` dependency and no npm scripts. The React dashboard has its own package metadata under `react/package.json`.
