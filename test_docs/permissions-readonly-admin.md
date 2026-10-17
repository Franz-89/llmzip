---
type: Domain Concept
title: Readonly/Admin Permission Refactor
description: "Defines the readonly and administrative permission model and tracks category migration status."
tags: [permissions, authorization, migration]
status: active
source_kind: hand-written
timestamp: "2026-06-30T06:51:14Z"
---

# Readonly/Admin Permission Refactor

## Objective

The target permission model has two levels for each functional category or section:

- `*_readonly`: access pages, lists, details, reports, lookup APIs, previews, and other non-mutating views.
- `*_admin`: create, update, delete, import, sync with mutation, execute commands, change status, or otherwise mutate records.

An `*_admin` permission must imply the matching `*_readonly` permission.

Broad permissions are permission groups for role-based access. For example, `inventory_admin` implies inventory section admin permissions, and `location_admin` implies location-owned section admin permissions such as `opening_hour_admin`. Individual permissions can still be granted or revoked for exceptional cases.

## Implementation Status

Permission constants and hierarchy live in `App/Model/NoDb/Permission.php`.

The menu-derived `*_readonly` and `*_admin` vocabulary has been introduced for the application sections below. Sidebar menu entries are being moved to those permissions so list/view/report pages use readonly permissions and new/import/admin-operation entries use admin permissions.

Legacy single-level permission constants remain in the code until each referenced category is fully migrated. They should be removed only after all controller, template, API, and menu references have moved to the new permission names.

### Migrated Categories

#### Inventory

- `organization_readonly` / `organization_admin` — `OrganizationController`. Templates: `organization/module/detail.phtml`.
- `warehouse_readonly` / `warehouse_admin` — `WarehouseController`. Templates: `warehouse/module/detail.phtml`.
- `game_catalog_readonly` / `game_catalog_admin` — `GameController`, `GamePriceController` (catalog-scope prices via `GamePriceManager::requirePermissionByGamePriceScope`). Templates: `game/module/detail.phtml`, `game/gamePrice/index.phtml`, `game/gamePrice/module/detail.phtml`, `game/gamePrice/module/list.phtml`.
- `game_acceptor_readonly` / `game_acceptor_admin` — `GameAcceptorController`. Constants and implication rules added to `Permission.php` in this batch. Templates: `game/acceptor/index.phtml`, `game/acceptor/module/detail.phtml`.
- `location_game_readonly` / `location_game_admin` — `GameAcceptorLocationController`, `GamePriceController` (game-location-scope prices). Templates: partially covered by game price templates above.
- `location_readonly`, `location_info_readonly/admin`, `location_user_readonly/admin`, `location_ticket_setting_readonly/admin`, `opening_hour_readonly/admin`, `location_workstation_readonly/admin`, `location_activity_readonly/admin`, `product_location_readonly/admin` — migrated in prior batches (see git history).
- `game_collection_readonly` / `game_collection_admin` — `GameAcceptorCollectionController` (collection read/list/totals actions use readonly; save/confirm/reopen actions use admin). Inline counter/cash visibility checks use `game_collection_counter_readonly` and `game_collection_cash_readonly`.
- `game_collection_accounting_readonly` / `game_collection_accounting_admin` — `GameAcceptorCollectionController` (accounting read/recalculate actions use readonly; saveAccounting/confirmAccounting/reopen actions use admin).

#### Settings

- `domain_readonly` / `domain_admin`, `domain_webhook_readonly` / `domain_webhook_admin` — `DomainController`.
- `finance_setting_readonly` / `finance_setting_admin` — `AdsAccountController`, `MerchantController`. Templates: `adsAccount/index.phtml`, `adsAccount/module/detail.phtml`, `merchant/index.phtml`, `merchant/module/detail.phtml`.
- `fiscal_year_readonly` / `fiscal_year_admin` — `FiscalYearController`.
- `holiday_readonly` / `holiday_admin` — `HolidayController` for global holiday settings. Location-specific holiday schedules remain guarded by `opening_hour_readonly` / `opening_hour_admin`. Templates: `holiday/index.phtml`, `holiday/module/detail.phtml`, `holiday/module/location/index.phtml`, `holiday/module/location/detail.phtml`, `holiday/module/location/list.phtml`.
- `period_readonly` / `period_admin` — `PeriodController`.
- `sapiens_system_readonly` / `sapiens_system_admin` — `SapiensDwController`, `SapiensPulseController`.
- `sapiens_workstation_readonly` / `sapiens_workstation_admin` — `SapiensWorkstationController`. Templates: `sapiensWorkstation/index.phtml`, `sapiensWorkstation/module/detail.phtml`, `sapiensWorkstation/module/detailRead.phtml`, `sapiensWorkstation/module/list.phtml`, `sapiensWorkstation/module/new.phtml`.
- `user_readonly` / `user_admin` — `UserController`.
- `vat_rate_readonly` / `vat_rate_admin` — `VatRateController`. Templates: `vatRate/index.phtml`, `vatRate/module/detail.phtml`, `vatRate/module/list.phtml`, `vatRate/module/new.phtml`, `vatRate/module/odooSection.phtml`.
- `qrcode_readonly` / `qrcode_admin` — `QrCodeController`, `QrCodeBulkController`, `QrCodeNfcController`.

#### Maintenance

- `email_readonly` / `email_admin` — `EmailController`, `EmailImporterController`.
- `file_upload_readonly` / `file_upload_admin` — `FileUploadController`.
- `log_readonly` — `CronJobStatusController` (all actions are read-only; no `log_admin` actions present in this controller).

#### Risk and Operations

- `abs_tracker_readonly` — `AbsTrackerController` (all actions are read-only; no `abs_tracker_admin` actions present yet).
- `risk_manager_readonly` / `risk_manager_admin` — `BankController`, `CookieWarningController`, `MerchantWarningController`.
- `ethoca_readonly` / `ethoca_admin` — `EthocaAlertController`, `EthocaRequestController`, `EthocaSettingController`.

#### Content

- `article_readonly` / `article_admin` — `ArticleController`.
- `faq_readonly` / `faq_admin` — `FaqController`.
- `html_template_readonly` / `html_template_admin` — `HtmlTemplateController`.

#### Language and AI

- `translation_readonly` / `translation_admin` — `TranslationController`, `TranslationGroupController`, `AutomaticTranslationController`.
- `semantic_detector_readonly` / `semantic_detector_admin` — `SemanticDetectorController`.

#### Devices

- `nuc_readonly` / `nuc_admin` — `Nuc/NucController`, `Nuc/NucCommandQueueController`, `Nuc/NucLogController`, `Nuc/NucLogRequestController`, `Nuc/NucSystemMetricController`.
- `pda_readonly` / `pda_admin` — `Pda/PdaController`.
- `payment_terminal_readonly` / `payment_terminal_admin` — `PaymentTerminal/PaymentTerminalController`, `PaymentTerminalConfigController`, `PaymentTerminalImageController`, `SkinVersionController`.
- `pulse_box_readonly` / `pulse_box_admin` — `PulseBoxController`, `PulseBox/PulseBoxGameDefaultController`.
- `device_coolcode_readonly` / `device_coolcode_admin` — `DeviceCoolcodeController`. Templates: `device/deviceCoolcode/index.phtml`, `device/deviceCoolcode/detail.phtml`, `device/deviceCoolcode/module/detail.phtml`, `device/deviceCoolcode/module/list.phtml`, `device/deviceCoolcode/module/listHeartbeat.phtml`, `device/deviceCoolcode/module/new.phtml`.
- `nayax_readonly` / `nayax_admin` — `NayaxOutboundController`, `NayaxPosController`.
- `planet_location_readonly` / `planet_location_admin` — `PlanetLocationController`.
- `pos_terminal_device_readonly` / `pos_terminal_device_admin` — `PosTerminalDeviceController`.
- `workstation_position_readonly` / `workstation_position_admin` — `WorkstationPositionController`.

#### Finance and Commerce

- `customer_readonly` / `customer_admin` — `CustomerController`. Templates: `customer/module/form/include/footer.phtml`.
- `payment_readonly` / `payment_admin` — `PaymentController`, `PaymentLinkController`, `PayoutController`, `PayoutPaidController`. Templates: `payment/link/index.phtml`, `payment/link/module/list.phtml`, `payment/link/module/new.phtml`.
- `payment_location_readonly` / `payment_location_admin` — `Payment/PaymentLocation/PaymentLocationController`.
- `subscription_readonly` / `subscription_admin` — `SubscriptionController`. Templates: `customer/module/form/subscription.phtml`.
- `invoice_readonly` / `invoice_admin` — `VendusInvoiceController`.
- `sii_readonly` / `sii_admin` — `Sii/SiiController`, `SiiLogController`, `SiiOdooReconciliationController`, `SiiScheduleController`, `API/Local/V1/Analysis/SiiOdooReconciliationApiController`.
- `odoo_readonly` / `odoo_admin` — `Odoo/OdooJournalEntryController`, `OdooOutboundController`.
- `discount_readonly` / `discount_admin` — `Discount/DiscountButtonController`.
- `voucher_readonly` / `voucher_admin` — `Voucher/VoucherBulkController`.
- `reservation_readonly` / `reservation_admin` — `Reservation/ReservationController`, `ReservationDataController`.
- `product_readonly` / `product_admin` — `Product/ProductController`, `ProductCountryController`, `ProductImportController`.
- `marketing_readonly` / `marketing_admin` — `Marketing/MarketingCampaignController`, `Marketing/Promo/MarketingPromoController`, `Marketing/Promo/MarketingPromoUsageController`, `MarketingAdsController`, `MarketingTrackerController`.
- `analysis_readonly` / `analysis_admin` — `Analysis/FollowUpController`, `Analysis/IndividualController`, `Analysis/ThemeController`, `Analysis/YtdController`, `Analysis/YtdChargebackController`. API: `ActivityApiController`, `ReservationApiController`, `SalesApiController`.
- `analysis_individual_range_readonly` / `analysis_individual_range_admin` — `Analysis/IndividualRangeController` (non-v2), `Analysis/v2/IndividualRangeController`. API: none directly.
- `analysis_game_report_readonly` / `analysis_game_report_admin` — `Analysis/v2/GameReportController`. API: `GamePerformanceApiController`.
- `analysis_loyalty_card_report_readonly` / `analysis_loyalty_card_report_admin` — `Analysis/v2/LoyaltyCardReportController`. API: `LoyaltyCardReportApiController`.
- `analysis_game_location_report_readonly` / `analysis_game_location_report_admin` — `Analysis/v2/GameLocationReportController`. API: `GameLocationPerformanceApiController`.
- `analysis_product_analysis_readonly` / `analysis_product_analysis_admin` — `Analysis/v2/ProductAnalysisController`. API: `ProductAnalysisApiController`, `ItemSalesApiController`.
- `staff_performance_report_readonly` / `staff_performance_report_admin` — `Analysis/v2/StaffPerformanceController`, `Analysis/v2/IndividualStaffReportController`. API: `StaffPerformanceApiController`, `IndividualStaffPerformanceApiController`.
- `accounting_report_readonly` / `accounting_report_admin` — `Analysis/v2/AccountingReportController`. API: `AccountingReportApiController`.
- `sales_comparison_dashboard_readonly` / `sales_comparison_dashboard_admin` — `Analysis/v2/SalesComparisonController`. API: `SalesComparisonApiController`.
- `loyalty_card_readonly` / `loyalty_card_admin` — `Loyalty/LoyaltyCardController` (read actions use readonly; assignUserAdmin/resetLoyaltyCard use admin).
- `loyalty_setting_readonly` / `loyalty_setting_admin` — `Loyalty/LoyaltyCardContextController`, `Loyalty/LoyaltyTierController` (list/detail/reload use readonly; create/update use admin).

### Partially Migrated

- None currently listed.

### Not Yet Migrated

The following controllers still use legacy single-level permission names. Migration order should follow the category groupings in this document.

#### Settings (remaining)

- None currently listed.

#### Devices (remaining)

- None currently listed.

#### Finance and Commerce (remaining)

- None currently listed.

### Templates Not Yet Migrated

Templates for all unmigrated categories above still need mutating-UI guards added (save/delete/create buttons, editable form controls) once their controllers are migrated.

## Category Rules

Categories should match durable business areas visible in the menu and controller structure.

Use categories that are:

- Broad enough to cover one coherent business area.
- Narrow enough to avoid unrelated record ownership.
- Stable across templates, controllers, and menu items.

Avoid categories named after a single route or screen, such as `location_list`.

## Permission Groups And Categories

### Inventory

Group permissions:

- `inventory_readonly`
- `inventory_admin`

Section permissions:

- `organization_readonly`, `organization_admin`
- `location_readonly`, `location_admin`
- `location_info_readonly`, `location_info_admin`
- `location_user_readonly`, `location_user_admin`
- `location_ticket_setting_readonly`, `location_ticket_setting_admin`
- `opening_hour_readonly`, `opening_hour_admin`
- `location_workstation_readonly`, `location_workstation_admin`
- `location_game_readonly`, `location_game_admin`
- `location_activity_readonly`, `location_activity_admin`
- `location_activity_package_readonly`, `location_activity_package_admin`
- `product_location_readonly`, `product_location_admin`
- `warehouse_readonly`, `warehouse_admin`
- `game_catalog_readonly`, `game_catalog_admin`
- `game_acceptor_readonly`, `game_acceptor_admin`
- `game_collection_readonly`, `game_collection_admin`
- `game_collection_accounting_readonly`, `game_collection_accounting_admin`
- `game_collection_counter_readonly`
- `game_collection_cash_readonly`

### Finance And Commerce

Group permissions:

- `finance_commerce_readonly`
- `finance_commerce_admin`

Section permissions:

- `analysis_readonly`, `analysis_admin`
- `analysis_individual_range_readonly`, `analysis_individual_range_admin`
- `analysis_game_report_readonly`, `analysis_game_report_admin`
- `analysis_loyalty_card_report_readonly`, `analysis_loyalty_card_report_admin`
- `analysis_game_location_report_readonly`, `analysis_game_location_report_admin`
- `analysis_product_analysis_readonly`, `analysis_product_analysis_admin`
- `staff_performance_report_readonly`, `staff_performance_report_admin`
- `accounting_report_readonly`, `accounting_report_admin`
- `sales_comparison_dashboard_readonly`, `sales_comparison_dashboard_admin`
- `vat_saving_readonly`, `vat_saving_admin`
- `customer_readonly`, `customer_admin`
- `loyalty_card_readonly`, `loyalty_card_admin`
- `loyalty_package_readonly`, `loyalty_package_admin`
- `invoice_readonly`, `invoice_admin`
- `sii_readonly`, `sii_admin`
- `odoo_readonly`, `odoo_admin`
- `reservation_readonly`, `reservation_admin`
- `payment_location_readonly`, `payment_location_admin`
- `activity_package_readonly`, `activity_package_admin`
- `product_readonly`, `product_admin`
- `payment_readonly`, `payment_admin`
- `subscription_readonly`, `subscription_admin`
- `marketing_readonly`, `marketing_admin`
- `voucher_readonly`, `voucher_admin`
- `loyalty_setting_readonly`, `loyalty_setting_admin`
- `voicemail_readonly`, `voicemail_admin`

### Devices

Group permissions:

- `device_readonly`
- `device_admin`

Section permissions:

- `nuc_readonly`, `nuc_admin`
- `pda_readonly`, `pda_admin`
- `nayax_readonly`, `nayax_admin`
- `workstation_position_readonly`, `workstation_position_admin`
- `pulse_box_readonly`, `pulse_box_admin`
- `device_coolcode_readonly`, `device_coolcode_admin`
- `pos_terminal_device_readonly`, `pos_terminal_device_admin`
- `payment_terminal_readonly`, `payment_terminal_admin`
- `planet_location_readonly`, `planet_location_admin`

### Content

Group permissions:

- `content_readonly`
- `content_admin`

Section permissions:

- `html_template_readonly`, `html_template_admin`
- `article_readonly`, `article_admin`
- `faq_readonly`, `faq_admin`

### Language And AI

Group permissions:

- `language_ai_readonly`
- `language_ai_admin`

Section permissions:

- `translation_readonly`, `translation_admin`
- `semantic_detector_readonly`, `semantic_detector_admin`

### Risk And Operations

Group permissions:

- `risk_operation_readonly`
- `risk_operation_admin`

Section permissions:

- `risk_manager_readonly`, `risk_manager_admin`
- `ethoca_readonly`, `ethoca_admin`
- `abs_tracker_readonly`, `abs_tracker_admin`

### Settings

Group permissions:

- `setting_readonly`
- `setting_admin`

Section permissions:

- `domain_readonly`, `domain_admin`
- `domain_webhook_readonly`, `domain_webhook_admin`
- `user_readonly`, `user_admin`
- `sapiens_system_readonly`, `sapiens_system_admin`
- `sapiens_workstation_readonly`, `sapiens_workstation_admin`
- `finance_setting_readonly`, `finance_setting_admin`
- `qrcode_readonly`, `qrcode_admin`
- `loyalty_setting_readonly`, `loyalty_setting_admin`
- `holiday_readonly`, `holiday_admin`
- `vat_rate_readonly`, `vat_rate_admin`
- `fiscal_year_readonly`, `fiscal_year_admin`
- `period_readonly`, `period_admin`

### Maintenance

Group permissions:

- `maintenance_readonly`
- `maintenance_admin`

Section permissions:

- `log_readonly`, `log_admin`
- `sys_log_readonly`, `sys_log_admin`
- `email_readonly`, `email_admin`
- `file_upload_readonly`, `file_upload_admin`
- `monitoring_readonly`, `monitoring_admin`

### Menu Permissions

Menu permissions are the remaining exception to the `*_readonly` / `*_admin` naming model. They should only compose menu access and should imply existing category permissions rather than gate controllers directly.

No controller should require a menu permission.

### Fine-Grained Workflow Permissions

Fine-grained workflow permissions still follow the readonly/admin naming model:

- `game_collection_counter_readonly` — controls whether a collection user can see counter values within the `GameAcceptorCollectionController` workflow.
- `game_collection_cash_readonly` — controls whether a collection user can see and edit cash values within the `GameAcceptorCollectionController` workflow; it implies `game_collection_counter_readonly`.

## Controller Enforcement

Use `*_readonly` for:

- Page rendering for list/detail/read-only screens.
- Lookup endpoints.
- Data reload endpoints.
- Report API endpoints.
- Preview and validation endpoints that do not write records.

Use `*_admin` for:

- `create`, `new` submission, `update`, `delete`, `remove`, `restore`, `archive`, `status`, `order`, `import`, and mutable `sync` actions.
- Command execution routes.
- Export routes only when export marks rows as exported, creates audit records, advances workflow state, or otherwise mutates data.

## Template Enforcement

Templates must hide or disable mutating UI for users without the relevant `*_admin` permission:

- New/create menu entries.
- Save buttons.
- Delete/remove buttons.
- Status-changing controls.
- Import/sync/execute command buttons.
- Editable form controls when the page is otherwise useful as read-only.

Readonly users may see details, tables, and read-only explanations. If a form cannot be made safely read-only, hide the form section and keep the containing tab only if the data still has read value.

## Menu Enforcement

Menu parent items should be rendered when the user has at least one visible child permission.

List/detail/report menu items should use `*_readonly`.

New/import/admin-operation menu items should use `*_admin`.

## Cross-Category Records

Records that naturally touch more than one category should use feature ownership rules.

- If the feature is exposed primarily under one menu area, require that area's permission.
- If the action mutates a bridge record from a detail tab, require the bridge category admin permission.
- If the action changes both parent records independently, require both admin permissions.
- If the action only reads a bridge record from one side, require the bridge readonly permission or the owning side readonly permission, depending on the route.

Recommended ownership for known bridge cases:

- `ProductLocation`: use `product_location_readonly` for reading product-location assignment/settings and `product_location_admin` for creating/updating/deleting those assignment/settings.
- `GameLocation`: use `location_game_readonly` and `location_game_admin`.
- `ActivityPackageLocation`: use `activity_package_readonly` and `activity_package_admin` when managed from the package area.
- `PeriodLocation` and location opening hours: use `opening_hour_readonly` and `opening_hour_admin`.
- Location user assignments: use `location_user_readonly` and `location_user_admin`.
- Location holiday schedules shown from the opening-hour tab: use `opening_hour_readonly` and `opening_hour_admin`.
- Payment terminal game-location configuration: use `payment_terminal_admin` because it is exposed as payment terminal configuration.

## Migration Strategy

Use an incremental migration.

1. Add new permission constants and implication rules category by category.
2. Add broad group permissions that imply section permissions.
3. Update menu entries for one category.
4. Update controllers for that category by separating read actions from mutating actions.
5. Update templates for that category so mutating UI requires admin.
6. Verify manually with one readonly user and one admin user for the category.
7. Repeat until all categories are migrated.
8. Remove old permission names after their references have been replaced.
