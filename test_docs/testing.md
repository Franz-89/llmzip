---
type: Development Guide
title: Testing
description: "Reference to available PHP, React, and manual verification mechanisms."
tags: [testing, verification, development]
status: active
source_kind: hand-written
timestamp: "2026-06-30T06:51:14Z"
---

# Testing

## PHP Tests

Composer autoload maps `Tests\` to `tests/`. No PHPUnit dependency or Composer test script is declared in `composer.json`, so the repository ships its own minimal runner:

```bash
php tests/run.php                       # every test
php tests/run.php ProductImportMatch    # only the classes whose name matches
```

`tests/run.php` loads the Composer autoloader and hands over to `Tests\TestRunner`, which walks `tests/`, instantiates every `*Test.php` class and calls each public `test*` method. Assertions are `TestRunner::assertSame/assertTrue/assertFalse`; a failure is reported per method and the process exits non-zero.

The scope is deliberately narrow: decision logic that needs no AutoDb connection, no request and no translation. Anything touching a model belongs in manual/operational verification instead.

Current tests:

- `tests/Product/Import/ProductImportMatchTest.php` — product import row-to-product matching and manual conflict resolution (see [product import matching](product-import-matching.md)).

## React Tests

`react/package.json` declares:

- `npm test`: `jest`
- `npm run lint`: `eslint . --ext .ts,.tsx`

No Jest configuration file was found in the inspected top-level React package files. `react/package.json` declares the `jest` and `eslint` commands in scripts, but neither `jest` nor `eslint` appears in its listed dependencies or devDependencies.

## Manual/Operational Verification

Operational scripts exist for:

- Database init/update: `utility/initDatabase.php`, `utility/updateDatabase.php`.
- Cron jobs under `cron/`.
- CLI commands registered in `src/settings.php`.

The repository does not expose a single documented full test command in the files inspected.
