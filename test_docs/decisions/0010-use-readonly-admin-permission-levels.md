---
type: ADR
title: "ADR 0010: Use Readonly/Admin Permission Levels"
description: "Decision to separate viewing and mutation capabilities into readonly and administrative permission levels."
tags: [adr, permissions, authorization]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0010: Use Readonly/Admin Permission Levels

## Status

Accepted; partially implemented.

## Context

`App/Model/NoDb/Permission.php` currently contains a mix of menu container permissions, feature permissions, operational permissions, and a few read-only/full pairs. Sidebar menu entries, controllers, API controllers, and templates all reference these permissions directly.

The target authorization behavior needs separate access levels for reading/viewing data and for mutating records.

## Decision

Use two permission levels for each migrated functional category:

- `*_readonly` for viewing, listing, lookup, preview, and reporting actions.
- `*_admin` for creating, updating, deleting, importing, mutable exporting, syncing with mutation, command execution, and status/order changes.

Each `*_admin` permission implies the matching `*_readonly` permission.

Use broad permission groups for role-based access. For example, `location_admin` implies section admin permissions such as `opening_hour_admin`, and `location_readonly` implies section readonly permissions such as `opening_hour_readonly`.

Controllers and templates should enforce the most specific section permission available, not only the broad group permission.

Categories and current migration status are documented in `../permissions-readonly-admin.md`.

Migrate incrementally by category instead of applying a one-pass refactor across the full codebase.

## Consequences

Old permission names do not need compatibility aliases during this refactor. User roles should be updated to grant the new broad groups or section permissions.

Legacy constants may remain temporarily while a category still has controller, API, template, or menu references to the old names. They should be deleted after references are migrated, not kept as permanent aliases.

Each category migration must update controller requirements and template rendering together so readonly users cannot reach mutating UI or mutating endpoints.
