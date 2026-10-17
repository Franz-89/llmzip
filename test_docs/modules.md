---
type: Architecture Note
title: Modules
description: "Map of application modules, route surfaces, integrations, and the React reporting dashboard."
tags: [modules, architecture, routing]
status: active
source_kind: hand-written
timestamp: "2026-07-01T01:00:00Z"
---

# Modules

This module map is based on top-level directories, route groups, controllers, models, managers, and package metadata.

## PHP Application Modules

- `App/AI`: AI-related code, including WhatsApp-specific code.
- `App/Abstracted`: abstract base types for modules, plans, users, notifications, PDFs, email generators, merchant providers, and voicemail providers.
- `App/Command`: CLI command classes for notifications, sync, translations, Odoo allocation, SII, monitoring, Nayax, NfcPayment, workstation, migrations, and materialized view refresh.
- `App/Controller`: Slim controller layer. Major surfaces include `Admin`, `Common`, `CookieTracker`, `Device`, `GatewayAuth`, `InteractiveTranslation`, `Nayax`, `PaymentTerminal`, `Porto`, `PulseBox`, `Stack`, `Vendor`, and `Workstation`.
- `App/Counter`: counters for payments, reservations, subscriptions, loyalty transactions, Nayax transactions, mailbox, and marketing ads.
- `App/DTO`: typed data transfer objects grouped by feature.
- `App/Engine`: engines such as loyalty card transaction processing.
- `App/Factory`: factories for activity settings.
- `App/Helper`: shared formatting, controller, template, date, number, SQL, payment, policy, path, and UI helpers.
- `App/InstanceCollector`: shared access to PostgreSQL, AutoDb, Redis, and transactions.
- `App/Manager`: business logic and integration managers.
- `App/Medium`: external communication mediums such as Telegram.
- `App/Model`: persistence models and non-database constants/configuration objects.
- `App/Module`: application module implementations.
- `App/Notification`: notification medium abstractions and implementations.
- `App/PDF`: PDF generators for invoices, QR labels, and vouchers.
- `App/Repository`: repository classes for issue search.
- `App/Rosetta`: mapping/translation classes for external data formats.
- `App/Service`: services, including APIs, analysis, documentation, and storage.
- `App/Service/Storage/Cloudflare`: Cloudflare Stream, Images, and R2 storage services.
- `App/Utility`: utility classes such as CSV and translation utilities.
- `App/View`: template rendering helpers.
- `App/Wrapper`: wrapper classes.

## Route Surfaces

- Admin/backoffice: `src/routesAdmin.php`, `src/routesAdminApi.php`, `src/routesAdminLocalApi.php`.
- Public/common webhooks: `src/routesCommonPublic.php`.
- Gateway/auth APIs: `src/routesAuth.php`.
- Front themes: `src/routesPorto.php`, `src/routesGlass.php`, `src/routesGlassLogged.php`, `src/routesStack.php`.
- Device APIs: `src/routesDeviceCoolcodeApi.php`, `src/routesPulseApi.php`, `src/routesPaymentTerminalApi.php`, `src/routesWorkstationApi.php`.
- Vendor/API integrations: `src/routesNayaxApi.php`, `src/routesTelegram.php`.
- Developer tools: `src/routesDev.php`.
- Interactive translations: `src/routesInteractiveTranslation.php`.
- Cookie tracker: `src/routesCookieTracker.php`.
- Documentation proxy: admin `/documentation` routes in `src/routesAdmin.php` call the documentation controller and `App\Manager\API\Admin\SapienscoreTechnologies\Outbound\OutboundDocumentationManager`.

## React Reporting Dashboard

`react/src/` contains dashboard pages, components, API services, types, styles, and utilities. Services call `/local/api/v1`, matching backend local API route files.

Visible pages include reporting, game report, game location report, individual staff report, staff performance, loyalty card, product analysis, accounting report, sales comparison, and issue dashboard.
