---
type: ADR
title: "ADR 0001: Use Slim as the PHP HTTP Framework"
description: "Decision to use Slim and Slim PHP View as the application's HTTP and template framework."
tags: [adr, slim, php]
status: active
source_kind: generated
timestamp: "2026-06-30T06:51:14Z"
---

# ADR 0001: Use Slim as the PHP HTTP Framework

## Status

Accepted in code.

## Context

`composer.json` requires `salvosav/slim-php8`, `slim/php-view`, and `adrianfalleiro/slim-cli-runner`. `public/index.php` instantiates `new \Slim\App($settings)`. Route files under `src/` use Slim-style `$app->get`, `$app->post`, `$app->any`, and `$app->group`.

## Decision

Use Slim as the HTTP application framework and Slim PHP View for template rendering.

## Consequences

Controllers are referenced directly from route strings such as `App\Controller\Admin\HomeController:index`. Views are rendered from `templates/` through `Slim\Views\PhpRenderer`.
