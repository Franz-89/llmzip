---
type: ADR
title: "ADR 0006: Embed a React Reporting Dashboard Into Admin Public Assets"
description: "Decision to build the React reporting dashboard into the PHP application's administrative public assets."
tags: [adr, react, reporting]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0006: Embed a React Reporting Dashboard Into Admin Public Assets

## Status

Accepted in code.

## Context

The `react/` package is named `reporting-dashboard`. `react/webpack.config.js` builds `bundle.js` into `public/assets/adminlte/js/analysis/react/dist/`. React services call backend APIs at `/local/api/v1`.

## Decision

Build the React reporting dashboard as a separate package and emit its bundle into the PHP admin public assets.

## Consequences

The PHP application serves the built dashboard bundle. React development uses Webpack dev server port `3000` and proxies `/local/api/v1` to `http://core.local`.
