---
type: Reference
title: AdminLTE UI Relationship Map
description: "Maps AdminLTE routes, controllers, managers, renderers, templates, and client-side interactions."
tags: [adminlte, templates, routes]
status: active
source_kind: hand-written
timestamp: "2026-06-30T06:51:14Z"
---

# AdminLTE UI Relationship Map

This map groups AdminLTE UI relationships by feature/module for agent navigation and impact analysis. It maps route, controller, manager, renderer, template, AJAX, JavaScript, and customSender relationships.

## How To Read This Map

- Template root: `templates/adminlte` when the current domain theme resolves through `App/Helper/TemplatePathHelper.php`.
- Page routes commonly render through `App/Helper/ControllerHelper.php`, which wraps the page body with `include/header` and `include/footer`.
- AJAX routes usually return JSON containing rendered HTML from a View renderer or Manager renderer.
- `customSender` calls post to `/<directory>` through `public/assets/adminlte/js/src/sender.js`; listed customSender chains show the source file, endpoint, and returned template when mapped.
- Dynamic mechanisms are listed first because they can hide route-template relationships from static navigation.

## Dynamic Rendering Mechanisms

- `TP::p($route) from analysis templates`: Analysis templates can be selected by arguments; individual files remain unresolved unless a concrete caller supplies the template name.
- `TP::p($path) from filter controls`: Filter control templates can be selected dynamically.
- `TP::p('htmlTemplate/builderJs/resource/' . $templateType .'/'. $templateId .'/index')`: BuilderJS resource templates under htmlTemplate/builderJs/resource/*/*/index.phtml are route-addressable by path parameters.
- `$args['emailTemplate']['template'] via TP::email()`: Email templates are outside this AdminLTE map and can be database-selected.
- `Dynamic PHP patterns preventing further mapping`: TP::p($route) in App/View/AnalysisTemplateRender.php selects templates from arguments.
- `Dynamic PHP patterns preventing further mapping`: TP::p($path) in App/View/FilterTemplateRender.php selects filter controls from arguments.
- `Dynamic PHP patterns preventing further mapping`: Concatenated TP::p() paths in App/Controller/Admin/HtmlTemplateController.php select BuilderJS resource templates by route parameters.
- `Dynamic PHP patterns preventing further mapping`: Database-backed email template names use TP::email() and are outside the AdminLTE folder.
- `Dynamic PHP patterns preventing further mapping`: Activity setting classes can return rendered HTML through polymorphic methods such as $activityType->renderNew(); individual implementation resolution is not always statically provable.
- `JavaScript/customSender patterns preventing further mapping`: customSender.sendAsySingleRoute($(this).data('route')) in public/assets/adminlte/js/src/mainHelper.js uses runtime data-route values.
- `JavaScript/customSender patterns preventing further mapping`: Several customSender.sendAsyMultipleValue(data, ...) calls build data.directory from local JavaScript state or object literals that are not always statically connected to a parent template.
- `JavaScript/customSender patterns preventing further mapping`: Template inline JavaScript often concatenates PHP variables into routes; the static map records the matching Slim route only when the literal prefix is sufficient.
- `JavaScript/customSender patterns preventing further mapping`: Return handlers can reload additional AJAX content through response payload fields such as directory; those server-generated follow-up routes are not fully expanded unless the route is visible in code.

## Feature Modules

### absTracker

**Routes**
- `GET /abs-tracker`
- `POST /abs-tracker/info/{idAbsTracker}`
- `POST /abs-tracker/reload`
- `POST /customer/abs-tracker/{idUser}`
- `POST /risk-manager/cookie-warning/explain/{idCookieTracker}/{idCookieMatch}`

**Controllers**
- `App/Controller/Admin/AbsTrackerController.php`
- `App/Controller/Admin/Risk/CookieWarningController.php`

**Managers**
- `App/Manager/Tracker/AbsTrackerManager.php`

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/absTracker/index.phtml`
- `templates/adminlte/absTracker/module/info.phtml`
- `templates/adminlte/absTracker/module/list.phtml`

**AJAX templates**
- `templates/adminlte/absTracker/module/info.phtml` <= `POST /abs-tracker/info/{idAbsTracker}`
- `templates/adminlte/absTracker/module/list.phtml` <= `POST /abs-tracker/reload`, `POST /customer/abs-tracker/{idUser}`, `POST /risk-manager/cookie-warning/explain/{idCookieTracker}/{idCookieMatch}`

**JavaScript files**
- `templates/adminlte/absTracker/module/list.phtml`
- `templates/adminlte/dashboard.bck.phtml`
- `templates/adminlte/dashboard.phtml`
- `templates/adminlte/nuc/module/logRequest/list.phtml`
- `templates/adminlte/risk/cookieWarning/module/list.phtml`

**customSender chains**
- `templates/adminlte/absTracker/module/info.phtml`: templates/adminlte/absTracker/module/list.phtml -> POST /abs-tracker/info/{idAbsTracker} -> templates/adminlte/absTracker/module/info.phtml
- `templates/adminlte/absTracker/module/info.phtml`: templates/adminlte/dashboard.bck.phtml -> POST /abs-tracker/info/{idAbsTracker} -> templates/adminlte/absTracker/module/info.phtml
- `templates/adminlte/absTracker/module/info.phtml`: templates/adminlte/dashboard.phtml -> POST /abs-tracker/info/{idAbsTracker} -> templates/adminlte/absTracker/module/info.phtml
- `templates/adminlte/absTracker/module/info.phtml`: templates/adminlte/nuc/module/logRequest/list.phtml -> POST /abs-tracker/info/{idAbsTracker} -> templates/adminlte/absTracker/module/info.phtml
- `templates/adminlte/absTracker/module/list.phtml`: templates/adminlte/risk/cookieWarning/module/list.phtml -> POST /risk-manager/cookie-warning/explain/{idCookieTracker}/{idCookieMatch} -> templates/adminlte/absTracker/module/list.phtml

### action

**Routes**
- `GET /action/pt/{macAddress}/{serialNumber}`
- `GET /action/pulse-box/new/{macAddress}`
- `POST /pulse-box/create`

**Controllers**
- `App/Controller/Admin/PaymentTerminal/PaymentTerminalController.php`
- `App/Controller/Admin/PulseBoxController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/PulseBoxTemplateRender.php`

**Templates**
- `templates/adminlte/action/paymentTerminal/index.phtml`
- `templates/adminlte/action/pulseBox/alreadyRegistered.phtml`
- `templates/adminlte/action/pulseBox/index.phtml`
- `templates/adminlte/action/pulseBox/registrationSuccess.phtml`

**AJAX templates**
- `templates/adminlte/action/pulseBox/registrationSuccess.phtml` <= `POST /pulse-box/create`

**JavaScript files**
- `templates/adminlte/pulseBox/module/new.phtml`

**customSender chains**
- `templates/adminlte/action/pulseBox/registrationSuccess.phtml`: templates/adminlte/pulseBox/module/new.phtml -> POST /pulse-box/create -> templates/adminlte/action/pulseBox/registrationSuccess.phtml

### activity

**Routes**
- `GET /activity-package/detail/{idActivityPackage}`
- `GET /activity-package/list`
- `GET /activity-package/new`
- `POST /activity-package-location/detail/{idActivityPackageLocation}`
- `POST /activity-package-location/prepare/setting/{idActivityPackage}`
- `POST /activity-package-location/prepare/setting/{idActivityPackage}/{idPeriod}`
- `POST /activity-package-location/create/{idLocation}`
- `POST /activity-package-location/update/{idActivityPackageLocation}`
- `POST /activity/location/detail/{type}/{idLocation}`

**Controllers**
- `App/Controller/Admin/Activity/ActivityPackageController.php`
- `App/Controller/Admin/Activity/ActivityPackageLocationController.php`
- `App/Controller/Admin/Activity/ActivityLocationController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/ActivityTemplateRender.php`

**Templates**
- `templates/adminlte/activity/activityPackage/detail.phtml`
- `templates/adminlte/activity/activityPackage/list.phtml`
- `templates/adminlte/activity/activityPackage/module/detail.phtml`
- `templates/adminlte/activity/activityPackage/module/detailPeriod.phtml`
- `templates/adminlte/activity/activityPackage/module/list.phtml`
- `templates/adminlte/activity/activityPackage/module/new.phtml`
- `templates/adminlte/activity/activityPackage/module/newPeriod.phtml`
- `templates/adminlte/activity/activityPackage/module/weekBirthdayUpsert.phtml`
- `templates/adminlte/activity/activityPackage/module/weekIndividualBirthdayUpsert.phtml`
- `templates/adminlte/activity/activityPackage/module/weekIndividualUpsert.phtml`
- `templates/adminlte/activity/activityPackage/module/weekUpsert.phtml`
- `templates/adminlte/activity/activityPackage/new.phtml`
- `templates/adminlte/activity/activityPackageLocation/module/detail.phtml`
- `templates/adminlte/activity/activityPackageLocation/module/list.phtml`
- `templates/adminlte/activity/activityPackageLocation/module/new.phtml`
- `templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml`
- `templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml`
- `templates/adminlte/activity/module/location/new.phtml`
- `templates/adminlte/activity/module/location/newPeriod.phtml`
- `templates/adminlte/activity/module/renderActivityLocationGroup.phtml`

**AJAX templates**
- `templates/adminlte/activity/activityPackageLocation/module/detail.phtml` <= `POST /activity-package-location/detail/{idActivityPackageLocation}`
- `templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml` <= `POST /activity-package-location/prepare/setting/{idActivityPackage}`, `POST /activity-package-location/prepare/setting/{idActivityPackage}/{idPeriod}`
- `templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml` <= `POST /activity-package-location/create/{idLocation}`, `POST /activity-package-location/update/{idActivityPackageLocation}`
- `templates/adminlte/activity/module/location/newPeriod.phtml` <= `POST /activity/location/detail/{type}/{idLocation}`
- `templates/adminlte/activity/module/renderActivityLocationGroup.phtml` <= `POST /activity/location/detail/{type}/{idLocation}`

**JavaScript files**
- `templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml`
- `templates/adminlte/activity/activityPackageLocation/module/new.phtml`
- `templates/adminlte/activity/module/renderActivityLocationGroup.phtml`
- `templates/adminlte/activity/activityPackageLocation/module/detail.phtml`

**customSender chains**
- `templates/adminlte/activity/activityPackageLocation/module/detail.phtml`: templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml -> POST /activity-package-location/detail/{idActivityPackageLocation} -> templates/adminlte/activity/activityPackageLocation/module/detail.phtml
- `templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml`: templates/adminlte/activity/activityPackageLocation/module/new.phtml -> POST /activity-package-location/prepare/setting/{idActivityPackage} -> templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml
- `templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml`: templates/adminlte/activity/activityPackageLocation/module/new.phtml -> POST /activity-package-location/prepare/setting/{idActivityPackage}/{idPeriod} -> templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml
- `templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml`: templates/adminlte/activity/module/renderActivityLocationGroup.phtml -> POST /activity-package-location/prepare/setting/{idActivityPackage} -> templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml
- `templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml`: templates/adminlte/activity/module/renderActivityLocationGroup.phtml -> POST /activity-package-location/prepare/setting/{idActivityPackage}/{idPeriod} -> templates/adminlte/activity/activityPackageLocation/module/newSetting.phtml
- `templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml`: templates/adminlte/activity/activityPackageLocation/module/detail.phtml -> POST /activity-package-location/update/{idActivityPackageLocation} -> templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml
- `templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml`: templates/adminlte/activity/activityPackageLocation/module/new.phtml -> POST /activity-package-location/create/{idLocation} -> templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml
- `templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml`: templates/adminlte/activity/module/renderActivityLocationGroup.phtml -> POST /activity-package-location/create/{idLocation} -> templates/adminlte/activity/activityPackageLocation/module/oneAsBox.phtml

### adsAccount

**Routes**
- `GET /ads-account`
- `POST /ads-account/detail/{idAdsAccount}`
- `POST /ads-account/reload/list`

**Controllers**
- `App/Controller/Admin/AdsAccountController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/adsAccount/index.phtml`
- `templates/adminlte/adsAccount/module/detail.phtml`
- `templates/adminlte/adsAccount/module/list.phtml`
- `templates/adminlte/adsAccount/module/new.phtml`

**AJAX templates**
- `templates/adminlte/adsAccount/module/detail.phtml` <= `POST /ads-account/detail/{idAdsAccount}`
- `templates/adminlte/adsAccount/module/list.phtml` <= `POST /ads-account/reload/list`

**JavaScript files**
- `templates/adminlte/adsAccount/module/list.phtml`

**customSender chains**
- `templates/adminlte/adsAccount/module/detail.phtml`: templates/adminlte/adsAccount/module/list.phtml -> POST /ads-account/detail/{idAdsAccount} -> templates/adminlte/adsAccount/module/detail.phtml

### analysis

**Routes**
- `GET /analysis/follow-up`
- `POST /analysis/follow-up`
- `ANY /analysis/individual`
- `ANY /analysis/individualRange`
- `GET /analysis/theme`
- `POST /analysis/theme`
- `ANY /analysis/v2/accounting-report`
- `ANY /analysis/v2/game-location-report`
- `ANY /analysis/v2/game-report`
- `ANY /analysis/v2/individual-range`
- `ANY /analysis/v2/individual-staff-report`
- `ANY /analysis/v2/loyalty-card-report`
- `ANY /analysis/v2/product-analysis`
- `ANY /analysis/v2/sales-comparison`
- `ANY /analysis/v2/staff-performance`
- `GET /analysis/ytd`
- `POST /analysis/ytd`
- `GET /analysis/ytd-chargeback`
- `POST /analysis/ytd-chargeback`

**Controllers**
- `App/Controller/Admin/Analysis/FollowUpController.php`
- `App/Controller/Admin/Analysis/IndividualController.php`
- `App/Controller/Admin/Analysis/IndividualRangeController.php`
- `App/Controller/Admin/Analysis/ThemeController.php`
- `App/Controller/Admin/Analysis/v2/AccountingReportController.php`
- `App/Controller/Admin/Analysis/v2/GameLocationReportController.php`
- `App/Controller/Admin/Analysis/v2/GameReportController.php`
- `App/Controller/Admin/Analysis/v2/IndividualRangeController.php`
- `App/Controller/Admin/Analysis/v2/IndividualStaffReportController.php`
- `App/Controller/Admin/Analysis/v2/LoyaltyCardReportController.php`
- `App/Controller/Admin/Analysis/v2/ProductAnalysisController.php`
- `App/Controller/Admin/Analysis/v2/SalesComparisonController.php`
- `App/Controller/Admin/Analysis/v2/StaffPerformanceController.php`
- `App/Controller/Admin/Analysis/YtdController.php`
- `App/Controller/Admin/Analysis/YtdChargebackController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/AnalysisTemplateRender.php`

**Templates**
- `templates/adminlte/analysis/followup/index.phtml`
- `templates/adminlte/analysis/individual/index.phtml`
- `templates/adminlte/analysis/individualRange/index.phtml`
- `templates/adminlte/analysis/module/chargebackByBankTb.phtml`
- `templates/adminlte/analysis/module/estimationMultiCurrency.phtml`
- `templates/adminlte/analysis/theme/index.v4.phtml`
- `templates/adminlte/analysis/v2/accountingReport/index.phtml`
- `templates/adminlte/analysis/v2/gameLocationReport/index.phtml`
- `templates/adminlte/analysis/v2/gameReport/index.phtml`
- `templates/adminlte/analysis/v2/individualRange/index.phtml`
- `templates/adminlte/analysis/v2/individualStaffReport/index.phtml`
- `templates/adminlte/analysis/v2/loyaltyCardReport/index.phtml`
- `templates/adminlte/analysis/v2/productAnalysis/index.phtml`
- `templates/adminlte/analysis/v2/salesComparison/index.phtml`
- `templates/adminlte/analysis/v2/staffPerformance/index.phtml`
- `templates/adminlte/analysis/ytd/index.v2.phtml`
- `templates/adminlte/analysis/ytdChargeback/index.phtml`

**AJAX templates**
- `templates/adminlte/analysis/followup/index.phtml` <= `POST /analysis/follow-up`
- `templates/adminlte/analysis/individual/index.phtml` <= `ANY /analysis/individual`
- `templates/adminlte/analysis/individualRange/index.phtml` <= `ANY /analysis/individualRange`
- `templates/adminlte/analysis/theme/index.v4.phtml` <= `POST /analysis/theme`
- `templates/adminlte/analysis/v2/accountingReport/index.phtml` <= `ANY /analysis/v2/accounting-report`
- `templates/adminlte/analysis/v2/gameLocationReport/index.phtml` <= `ANY /analysis/v2/game-location-report`
- `templates/adminlte/analysis/v2/gameReport/index.phtml` <= `ANY /analysis/v2/game-report`
- `templates/adminlte/analysis/v2/individualRange/index.phtml` <= `ANY /analysis/v2/individual-range`
- `templates/adminlte/analysis/v2/individualStaffReport/index.phtml` <= `ANY /analysis/v2/individual-staff-report`
- `templates/adminlte/analysis/v2/loyaltyCardReport/index.phtml` <= `ANY /analysis/v2/loyalty-card-report`
- `templates/adminlte/analysis/v2/productAnalysis/index.phtml` <= `ANY /analysis/v2/product-analysis`
- `templates/adminlte/analysis/v2/salesComparison/index.phtml` <= `ANY /analysis/v2/sales-comparison`
- `templates/adminlte/analysis/v2/staffPerformance/index.phtml` <= `ANY /analysis/v2/staff-performance`
- `templates/adminlte/analysis/ytd/index.v2.phtml` <= `POST /analysis/ytd`
- `templates/adminlte/analysis/ytdChargeback/index.phtml` <= `POST /analysis/ytd-chargeback`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### apiRequest

**Routes**
- `POST /api/request/detail/{idApiRequest}`
- `POST /api/request/reload[/{action}]`

**Controllers**
- `App/Controller/Admin/API/APIRequestController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/APIRequestTemplateRender.php`

**Templates**
- `templates/adminlte/apiRequest/module/detail.phtml`
- `templates/adminlte/apiRequest/module/list.phtml`

**AJAX templates**
- `templates/adminlte/apiRequest/module/detail.phtml` <= `POST /api/request/detail/{idApiRequest}`
- `templates/adminlte/apiRequest/module/list.phtml` <= `POST /api/request/reload[/{action}]`

**JavaScript files**
- `templates/adminlte/apiRequest/module/list.phtml`
- `templates/adminlte/odoo/journalEntry/module/detail.phtml`

**customSender chains**
- `templates/adminlte/apiRequest/module/detail.phtml`: templates/adminlte/apiRequest/module/list.phtml -> POST /api/request/detail/{idApiRequest} -> templates/adminlte/apiRequest/module/detail.phtml
- `templates/adminlte/apiRequest/module/detail.phtml`: templates/adminlte/odoo/journalEntry/module/detail.phtml -> POST /api/request/detail/{idApiRequest} -> templates/adminlte/apiRequest/module/detail.phtml

### article

**Routes**
- `GET /article/detail/{idArticle}`
- `GET /article/list`
- `GET /article/new`

**Controllers**
- `App/Controller/Admin/ArticleController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/article/detail.phtml`
- `templates/adminlte/article/list.phtml`
- `templates/adminlte/article/module/listOption.phtml`
- `templates/adminlte/article/module/trList.phtml`
- `templates/adminlte/article/new.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### country

**Routes**
- None mapped

**Controllers**
- None mapped

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/country/module/listOption.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### cronJobStatus

**Routes**
- `GET /cron-job-status`
- `POST /cron-job-status/reload`

**Controllers**
- `App/Controller/Admin/CronJobStatusController.php`

**Managers**
- `App/Manager/CronJobStatusManager.php`

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/cronJobStatus/index.phtml`
- `templates/adminlte/cronJobStatus/module/list.phtml`

**AJAX templates**
- `templates/adminlte/cronJobStatus/module/list.phtml` <= `POST /cron-job-status/reload`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### customer

**Routes**
- `GET /customer/detail/-/{idUser}`
- `GET /customer/detail/{idUserEntry}`
- `GET /customer/list`
- `POST /customer/list/reload`
- `POST /customer/reservations/reload/{idUserEntry}`
- `POST /customer/reservations/{idUserEntry}`

**Controllers**
- `App/Controller/Admin/CustomerController.php`

**Managers**
- `App/Manager/CustomerManager.php`
- `App/Manager/Marketing/MarketingCampaignManager.php`
- `App/Manager/Tracker/MarketingTrackerManager.php`
- `App/Manager/PaymentManager.php`
- `App/Manager/SubscriptionManager.php`
- `App/Manager/WalletManager.php`

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/customer/detail.phtml`
- `templates/adminlte/customer/list.phtml`
- `templates/adminlte/customer/module/form/include/common.phtml`
- `templates/adminlte/customer/module/form/include/footer.phtml`
- `templates/adminlte/customer/module/form/include/header.phtml`
- `templates/adminlte/customer/module/form/marketingCampaign.phtml`
- `templates/adminlte/customer/module/form/marketingTracker.phtml`
- `templates/adminlte/customer/module/form/payment.phtml`
- `templates/adminlte/customer/module/form/subscription.phtml`
- `templates/adminlte/customer/module/form/wallet.phtml`
- `templates/adminlte/customer/module/listCustomer.phtml`
- `templates/adminlte/customer/module/listEmail.phtml`
- `templates/adminlte/customer/module/listReservation.phtml`

**AJAX templates**
- `templates/adminlte/customer/module/listCustomer.phtml` <= `POST /customer/list/reload`
- `templates/adminlte/customer/module/listReservation.phtml` <= `POST /customer/reservations/reload/{idUserEntry}`, `POST /customer/reservations/{idUserEntry}`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### dashboard

**Routes**
- `GET /`
- `POST /`

**Controllers**
- `App/Controller/Admin/HomeController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/dashboard.phtml`

**AJAX templates**
- `templates/adminlte/dashboard.phtml` <= `POST /`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### dashboardItSupport

**Routes**
- `GET /`
- `POST /`

**Controllers**
- `App/Controller/Admin/HomeController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/dashboardItSupport.phtml`

**AJAX templates**
- `templates/adminlte/dashboardItSupport.phtml` <= `POST /`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### dashboardLimited

**Routes**
- `GET /`
- `POST /`

**Controllers**
- `App/Controller/Admin/HomeController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/dashboardLimited.phtml`

**AJAX templates**
- `templates/adminlte/dashboardLimited.phtml` <= `POST /`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### dashboardSalesComparison

**Routes**
- `GET /`
- `POST /`

**Controllers**
- `App/Controller/Admin/HomeController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/dashboardSalesComparison.phtml`

**AJAX templates**
- `templates/adminlte/dashboardSalesComparison.phtml` <= `POST /`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### debugLog

**Routes**
- `ANY /debug-log`
- `POST /debug-log/reload`

**Controllers**
- `App/Controller/Admin/DebugLogController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/debugLog/index.phtml`
- `templates/adminlte/debugLog/module/listDebugLog.phtml`

**AJAX templates**
- `templates/adminlte/debugLog/index.phtml` <= `ANY /debug-log`
- `templates/adminlte/debugLog/module/listDebugLog.phtml` <= `POST /debug-log/reload`

**JavaScript files**
- `templates/adminlte/debugLog/index.phtml`

**customSender chains**
- `templates/adminlte/debugLog/index.phtml`: templates/adminlte/debugLog/index.phtml -> ANY /debug-log -> templates/adminlte/debugLog/index.phtml

### device

**Routes**
- `GET /device/coolcode/detail/{idDeviceCoolcode}`
- `GET /device/coolcode`
- `POST /device/coolcode/reload/list`

**Controllers**
- `App/Controller/Admin/Device/DeviceCoolcode/DeviceCoolcodeController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/DeviceCoolcodeTemplateRender.php`

**Templates**
- `templates/adminlte/device/deviceCoolcode/detail.phtml`
- `templates/adminlte/device/deviceCoolcode/index.phtml`
- `templates/adminlte/device/deviceCoolcode/module/detail.phtml`
- `templates/adminlte/device/deviceCoolcode/module/list.phtml`
- `templates/adminlte/device/deviceCoolcode/module/listHeartbeat.phtml`
- `templates/adminlte/device/deviceCoolcode/module/new.phtml`

**AJAX templates**
- `templates/adminlte/device/deviceCoolcode/module/list.phtml` <= `POST /device/coolcode/reload/list`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### deviceMonitoring

**Routes**
- `GET /device-monitoring`
- `GET /device-monitoring/location/{idLocation}`

**Controllers**
- `App/Controller/Admin/DeviceMonitoring/DeviceMonitoringController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Other renderers and parent relationships**
- `templates/adminlte/deviceMonitoring/locationDetail.phtml`

**Templates**
- `templates/adminlte/deviceMonitoring/dashboard.phtml`
- `templates/adminlte/deviceMonitoring/locationDetail.phtml`
- `templates/adminlte/deviceMonitoring/module/deviceCard.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### discount

**Routes**
- `GET /discount`
- `POST /discount/detail/{idDiscountButton}`
- `POST /discount/reload`

**Controllers**
- `App/Controller/Admin/Discount/DiscountButtonController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/DiscountButtonTemplateRender.php`

**Templates**
- `templates/adminlte/discount/index.phtml`
- `templates/adminlte/discount/module/detail.phtml`
- `templates/adminlte/discount/module/list.phtml`
- `templates/adminlte/discount/module/new.phtml`

**AJAX templates**
- `templates/adminlte/discount/module/detail.phtml` <= `POST /discount/detail/{idDiscountButton}`
- `templates/adminlte/discount/module/list.phtml` <= `POST /discount/reload`

**JavaScript files**
- `templates/adminlte/discount/module/list.phtml`

**customSender chains**
- `templates/adminlte/discount/module/detail.phtml`: templates/adminlte/discount/module/list.phtml -> POST /discount/detail/{idDiscountButton} -> templates/adminlte/discount/module/detail.phtml

### documentation

**Routes**
- `GET /documentation`

**Controllers**
- `App/Controller/Admin/DocumentationController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/documentation/knowledgeBase.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### domain

**Routes**
- `GET /domain`
- `POST /domain/detail/{idDomain}`
- `POST /domain/reload/list`

**Controllers**
- `App/Controller/Admin/DomainController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/domain/index.phtml`
- `templates/adminlte/domain/module/detail.phtml`
- `templates/adminlte/domain/module/list.phtml`
- `templates/adminlte/domain/module/new.phtml`
- `templates/adminlte/domain/module/restrictedEmail.phtml`

**AJAX templates**
- `templates/adminlte/domain/module/detail.phtml` <= `POST /domain/detail/{idDomain}`
- `templates/adminlte/domain/module/list.phtml` <= `POST /domain/reload/list`

**JavaScript files**
- `templates/adminlte/domain/module/list.phtml`

**customSender chains**
- `templates/adminlte/domain/module/detail.phtml`: templates/adminlte/domain/module/list.phtml -> POST /domain/detail/{idDomain} -> templates/adminlte/domain/module/detail.phtml

### email

**Routes**
- `GET /email/detail/{idEmail}`
- `GET /email/importer/detail/{idEmailImporter}`
- `GET /email/importer`
- `POST /email/importer/schedule/{idEmailImporter}`
- `POST /email/importer/reload`
- `POST /email/importer/detail/list/reload/data/{idEmailImporter}`
- `GET /email/received`
- `GET /email/sent`
- `GET /email/detail/{idEmail}/iframe`
- `POST /email/detail/{idEmail}/{token}/iframe/asy`
- `POST /email/received/reload`
- `POST /email/sent/reload`

**Controllers**
- `App/Controller/Admin/EmailController.php`
- `App/Controller/Admin/EmailImporterController.php`

**Managers**
- `App/Manager/EmailImporterManager.php`

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/email/detail.phtml`
- `templates/adminlte/email/importer/detail.phtml`
- `templates/adminlte/email/importer/index.phtml`
- `templates/adminlte/email/importer/module/boxAction.phtml`
- `templates/adminlte/email/importer/module/boxInfo.phtml`
- `templates/adminlte/email/importer/module/boxStats.phtml`
- `templates/adminlte/email/importer/module/detail.phtml`
- `templates/adminlte/email/importer/module/list.phtml`
- `templates/adminlte/email/importer/module/listData.phtml`
- `templates/adminlte/email/importer/module/new.phtml`
- `templates/adminlte/email/list.phtml`
- `templates/adminlte/email/module/iframe.phtml`
- `templates/adminlte/email/module/iframeTag.phtml`
- `templates/adminlte/email/module/list.phtml`

**AJAX templates**
- `templates/adminlte/email/importer/module/detail.phtml` <= `POST /email/importer/schedule/{idEmailImporter}`
- `templates/adminlte/email/importer/module/list.phtml` <= `POST /email/importer/reload`
- `templates/adminlte/email/importer/module/listData.phtml` <= `POST /email/importer/detail/list/reload/data/{idEmailImporter}`
- `templates/adminlte/email/module/iframeTag.phtml` <= `POST /email/detail/{idEmail}/{token}/iframe/asy`
- `templates/adminlte/email/module/list.phtml` <= `POST /email/received/reload`, `POST /email/sent/reload`

**JavaScript files**
- `templates/adminlte/email/importer/module/boxAction.phtml`
- `public/assets/adminlte/js/src/mainHelper.js`

**customSender chains**
- `templates/adminlte/email/importer/module/detail.phtml`: templates/adminlte/email/importer/module/boxAction.phtml -> POST /email/importer/schedule/{idEmailImporter} -> templates/adminlte/email/importer/module/detail.phtml
- `templates/adminlte/email/module/iframeTag.phtml`: public/assets/adminlte/js/src/mainHelper.js -> POST /email/detail/{idEmail}/{token}/iframe/asy -> templates/adminlte/email/module/iframeTag.phtml

### faq

**Routes**
- `GET /faq/detail/{idFaq}`
- `GET /faq/list`
- `POST /faq/module/order`
- `GET /faq/new`
- `GET /faq/order`

**Controllers**
- `App/Controller/Admin/FaqController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/faq/detail.phtml`
- `templates/adminlte/faq/list.phtml`
- `templates/adminlte/faq/module/editOrder.phtml`
- `templates/adminlte/faq/module/listOption.phtml`
- `templates/adminlte/faq/module/listTranslation.phtml`
- `templates/adminlte/faq/module/trList.phtml`
- `templates/adminlte/faq/new.phtml`
- `templates/adminlte/faq/order.phtml`

**AJAX templates**
- `templates/adminlte/faq/module/editOrder.phtml` <= `POST /faq/module/order`

**JavaScript files**
- `templates/adminlte/faq/order.phtml`

**customSender chains**
- `templates/adminlte/faq/module/editOrder.phtml`: templates/adminlte/faq/order.phtml -> POST /faq/module/order -> templates/adminlte/faq/module/editOrder.phtml

### feature

**Routes**
- `GET /feature/glass/interlayer/detail/{idInterlayer}`
- `GET /feature/glass/interlayer`
- `POST /feature/glass/interlayer/create/version/{idInterlayer}`
- `POST /feature/glass/interlayer/reload`
- `POST /feature/glass/interlayer/reload/version/{idInterlayer}`

**Controllers**
- `App/Controller/Admin/Glass/InterlayerController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/FeatureGlassTemplateRender.php`

**Templates**
- `templates/adminlte/feature/glass/interlayer/detail.phtml`
- `templates/adminlte/feature/glass/interlayer/index.phtml`
- `templates/adminlte/feature/glass/interlayer/module/detail.phtml`
- `templates/adminlte/feature/glass/interlayer/module/list.phtml`
- `templates/adminlte/feature/glass/interlayer/module/listShearModulus.phtml`
- `templates/adminlte/feature/glass/interlayer/module/listVersion.phtml`
- `templates/adminlte/feature/glass/interlayer/module/new.phtml`
- `templates/adminlte/feature/glass/interlayer/module/newVersion.phtml`

**AJAX templates**
- `templates/adminlte/feature/glass/interlayer/module/detail.phtml` <= `POST /feature/glass/interlayer/create/version/{idInterlayer}`
- `templates/adminlte/feature/glass/interlayer/module/list.phtml` <= `POST /feature/glass/interlayer/reload`
- `templates/adminlte/feature/glass/interlayer/module/listVersion.phtml` <= `POST /feature/glass/interlayer/reload/version/{idInterlayer}`

**JavaScript files**
- `templates/adminlte/feature/glass/interlayer/module/new.phtml`
- `templates/adminlte/feature/glass/interlayer/module/newVersion.phtml`

**customSender chains**
- `templates/adminlte/feature/glass/interlayer/module/detail.phtml`: templates/adminlte/feature/glass/interlayer/module/new.phtml -> POST /feature/glass/interlayer/create/version/{idInterlayer} -> templates/adminlte/feature/glass/interlayer/module/detail.phtml
- `templates/adminlte/feature/glass/interlayer/module/detail.phtml`: templates/adminlte/feature/glass/interlayer/module/newVersion.phtml -> POST /feature/glass/interlayer/create/version/{idInterlayer} -> templates/adminlte/feature/glass/interlayer/module/detail.phtml

### fileUpload

**Routes**
- `GET /file-upload`
- `POST /file-upload/upload`

**Controllers**
- `App/Controller/Admin/FileUploadController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/fileUpload/index.phtml`
- `templates/adminlte/fileUpload/module/list.phtml`
- `templates/adminlte/fileUpload/module/listOption.phtml`
- `templates/adminlte/fileUpload/module/new.phtml`

**AJAX templates**
- `templates/adminlte/fileUpload/module/list.phtml` <= `POST /file-upload/upload`
- `templates/adminlte/fileUpload/module/listOption.phtml` <= `POST /file-upload/upload`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### finder

**Routes**
- `GET /finder`

**Controllers**
- `App/Controller/Admin/FinderController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/finder/index.phtml`
- `templates/adminlte/finder/module/listCustomer.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### fiscalYear

**Routes**
- `GET /fiscal-year`
- `POST /fiscal-year/detail/{idFiscalYear}`
- `POST /fiscal-year/reload`

**Controllers**
- `App/Controller/Admin/FiscalYearController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/FiscalYearTemplateRender.php`

**Templates**
- `templates/adminlte/fiscalYear/index.phtml`
- `templates/adminlte/fiscalYear/module/detail.phtml`
- `templates/adminlte/fiscalYear/module/list.phtml`
- `templates/adminlte/fiscalYear/module/new.phtml`

**AJAX templates**
- `templates/adminlte/fiscalYear/module/detail.phtml` <= `POST /fiscal-year/detail/{idFiscalYear}`
- `templates/adminlte/fiscalYear/module/list.phtml` <= `POST /fiscal-year/reload`

**JavaScript files**
- `templates/adminlte/fiscalYear/module/list.phtml`

**customSender chains**
- `templates/adminlte/fiscalYear/module/detail.phtml`: templates/adminlte/fiscalYear/module/list.phtml -> POST /fiscal-year/detail/{idFiscalYear} -> templates/adminlte/fiscalYear/module/detail.phtml

### game

**Routes**
- `GET /game/acceptor/collection/accounting`
- `GET /game/acceptor/load/game/accounting`
- `GET /game/acceptor/collection/accounting/recalculate`
- `ANY /game/acceptor/collection/accounting/pending`
- `GET /game/acceptor/collection`
- `GET /game/acceptor/load/game`
- `GET /game/acceptor`
- `GET /game/acceptor/location`
- `POST /game/acceptor/location/detail/{idGameAcceptorLocation}`
- `POST /game/acceptor/detail/{idGameAcceptor}`
- `POST /game/acceptor/reload`
- `GET /game/detail/{idGame}`
- `POST /game-location/detail/{idGameLocation}`
- `POST /game-location/reload/{idLocation}`
- `POST /game-location/new-as-child/{idParent}`
- `GET /game-price/list`
- `POST /game-price/detail/{idGamePrice}`
- `POST /game-price/gl/list/{idGameLocation}`
- `POST /game-price/list/{idGame}`
- `POST /game-price/gl/new/{idGameLocation}`
- `POST /game-price/new/{idGame}`
- `GET /game/list`
- `POST /game-location/default/preview[/{idGameLocation}]`
- `GET /game/new`

**Controllers**
- `App/Controller/Admin/Game/GameAcceptorCollectionController.php`
- `App/Controller/Admin/Game/GameAcceptorController.php`
- `App/Controller/Admin/Game/GameAcceptorLocationController.php`
- `App/Controller/Admin/Game/GameController.php`
- `App/Controller/Admin/Game/GameLocationController.php`
- `App/Controller/Admin/Game/GamePriceController.php`
- `App/Controller/Admin/Game/GameLocationDefaultController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/GameTemplateRender.php`

**Templates**
- `templates/adminlte/game/acceptor/collection/accounting/index.phtml`
- `templates/adminlte/game/acceptor/collection/accounting/list.phtml`
- `templates/adminlte/game/acceptor/collection/accounting/module/accountingRowAccounting.phtml`
- `templates/adminlte/game/acceptor/collection/accounting/module/accountingSummary.phtml`
- `templates/adminlte/game/acceptor/collection/accounting/module/accountingTr.phtml`
- `templates/adminlte/game/acceptor/collection/accounting/pending.phtml`
- `templates/adminlte/game/acceptor/collection/index.phtml`
- `templates/adminlte/game/acceptor/collection/list.phtml`
- `templates/adminlte/game/acceptor/collection/mobileList.phtml`
- `templates/adminlte/game/acceptor/index.phtml`
- `templates/adminlte/game/acceptor/location/index.phtml`
- `templates/adminlte/game/acceptor/location/module/detail.phtml`
- `templates/adminlte/game/acceptor/location/module/list.phtml`
- `templates/adminlte/game/acceptor/module/detail.phtml`
- `templates/adminlte/game/acceptor/module/list.phtml`
- `templates/adminlte/game/acceptor/module/new.phtml`
- `templates/adminlte/game/detail.phtml`
- `templates/adminlte/game/gameLocation/index.phtml`
- `templates/adminlte/game/gameLocation/module/asListOption.phtml`
- `templates/adminlte/game/gameLocation/module/detail.phtml`
- `templates/adminlte/game/gameLocation/module/list.phtml`
- `templates/adminlte/game/gameLocation/module/new.phtml`
- `templates/adminlte/game/gamePrice/index.phtml`
- `templates/adminlte/game/gamePrice/module/detail.phtml`
- `templates/adminlte/game/gamePrice/module/list.phtml`
- `templates/adminlte/game/gamePrice/module/new.phtml`
- `templates/adminlte/game/list.phtml`
- `templates/adminlte/game/module/businessSetting/detail.phtml`
- `templates/adminlte/game/module/businessSetting/new.phtml`
- `templates/adminlte/game/module/businessSetting/preview.phtml`
- `templates/adminlte/game/module/detail.phtml`
- `templates/adminlte/game/module/list.phtml`
- `templates/adminlte/game/module/new.phtml`
- `templates/adminlte/game/new.phtml`

**AJAX templates**
- `templates/adminlte/game/acceptor/collection/accounting/pending.phtml` <= `ANY /game/acceptor/collection/accounting/pending`
- `templates/adminlte/game/acceptor/location/module/detail.phtml` <= `POST /game/acceptor/location/detail/{idGameAcceptorLocation}`
- `templates/adminlte/game/acceptor/module/detail.phtml` <= `POST /game/acceptor/detail/{idGameAcceptor}`
- `templates/adminlte/game/acceptor/module/list.phtml` <= `POST /game/acceptor/reload`
- `templates/adminlte/game/gameLocation/module/detail.phtml` <= `POST /game-location/detail/{idGameLocation}`
- `templates/adminlte/game/gameLocation/module/list.phtml` <= `POST /game-location/reload/{idLocation}`
- `templates/adminlte/game/gameLocation/module/new.phtml` <= `POST /game-location/new-as-child/{idParent}`
- `templates/adminlte/game/gamePrice/module/detail.phtml` <= `POST /game-price/detail/{idGamePrice}`
- `templates/adminlte/game/gamePrice/module/list.phtml` <= `POST /game-price/gl/list/{idGameLocation}`, `POST /game-price/list/{idGame}`
- `templates/adminlte/game/gamePrice/module/new.phtml` <= `POST /game-price/gl/new/{idGameLocation}`, `POST /game-price/new/{idGame}`
- `templates/adminlte/game/module/businessSetting/preview.phtml` <= `POST /game-location/default/preview[/{idGameLocation}]`

**JavaScript files**
- `templates/adminlte/game/acceptor/module/list.phtml`
- `templates/adminlte/game/gameLocation/module/new.phtml`
- `templates/adminlte/game/gamePrice/module/list.phtml`
- `templates/adminlte/game/gameLocation/module/detail.phtml`

**customSender chains**
- `templates/adminlte/game/acceptor/module/detail.phtml`: templates/adminlte/game/acceptor/module/list.phtml -> POST /game/acceptor/detail/{idGameAcceptor} -> templates/adminlte/game/acceptor/module/detail.phtml
- `templates/adminlte/game/gameLocation/module/new.phtml`: templates/adminlte/game/gameLocation/module/new.phtml -> POST /game-location/new-as-child/{idParent} -> templates/adminlte/game/gameLocation/module/new.phtml
- `templates/adminlte/game/gamePrice/module/detail.phtml`: templates/adminlte/game/gamePrice/module/list.phtml -> POST /game-price/detail/{idGamePrice} -> templates/adminlte/game/gamePrice/module/detail.phtml
- `templates/adminlte/game/module/businessSetting/preview.phtml`: templates/adminlte/game/gameLocation/module/detail.phtml -> POST /game-location/default/preview[/{idGameLocation}] -> templates/adminlte/game/module/businessSetting/preview.phtml
- `templates/adminlte/game/module/businessSetting/preview.phtml`: templates/adminlte/game/gameLocation/module/new.phtml -> POST /game-location/default/preview[/{idGameLocation}] -> templates/adminlte/game/module/businessSetting/preview.phtml

### helper

**Routes**
- `ANY /reservation/detail/{bookingCode}/{idLocation}/{idReservation}`
- `GET /action/pt/{macAddress}/{serialNumber}`
- `GET /action/pulse-box/new/{macAddress}`
- `GET /register/activation/{idUser}/{activationToken}`
- `GET /register/pin-reset/{idUser}/{token}`
- `GET /register/pin/{idUser}/{token}`
- `GET /register/reset`
- `GET /register/sca/payment/complete/{idPayment}/{idPaymentTransaction}`
- `POST /register/reset/password`
- `ANY /location/get/option/country/{country}`
- `POST /address/province/get/option/{country}/{required}`
- `POST /location/get/option/game-location/{idLocation}`
- `POST /location/get/option/workstation/{idLocation}`
- `POST /marketing/campaign/load/list/htmlTemplate/{idMarketingCampaign}/{idEmailImporter}`
- `POST /payment/link/get/domain/{idOrganization}`
- `POST /payment/link/get/product/{idDomain}/{idOrganization}/{type}`
- `POST /qrcode/bulk/get/option/activity/{activityCode}`
- `POST /lang/domain/get/option/{idDomain}`
- `POST /lang/domain/get/option/{idDomain}/{opt}`
- `POST /lang/get/option/{theme}`
- `POST /lang/get/option/{theme}/{filterLang}`
- `POST /lang/get/option/{theme}/{filterLang}/{opt}`

**Controllers**
- `App/Controller/Admin/MailboxController.php`
- `App/Controller/Admin/PaymentController.php`
- `App/Controller/Admin/PaymentTerminal/PaymentTerminalController.php`
- `App/Controller/Admin/PulseBoxController.php`
- `App/Controller/Admin/RegisterController.php`
- `App/Controller/Admin/Reservation/ReservationDataController.php`
- `App/Controller/Porto/RegisterController.php`
- `App/Controller/Admin/AddressController.php`
- `App/Controller/Admin/LocationController.php`
- `App/Controller/Admin/Marketing/MarketingCampaignController.php`
- `App/Controller/Admin/PaymentLinkController.php`
- `App/Controller/Admin/QrCode/QrCodeBulkController.php`
- `App/Controller/Admin/QrCode/QrCodeNfcController.php`
- `App/Controller/Admin/UserController.php`
- `App/Controller/Admin/VatRateController.php`
- `App/Controller/Admin/LanguageController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Other renderers and parent relationships**
- `App/Helper/DateHelper.php`
- `App/Helper/DesignHelper.php`
- `App/Model/NoDb/ThemeCollection.php`

**Templates**
- `templates/adminlte/helper/error.phtml`
- `templates/adminlte/helper/guest/error.phtml`
- `templates/adminlte/helper/module/addressHandler.phtml`
- `templates/adminlte/helper/module/dimensionHandler.phtml`
- `templates/adminlte/helper/module/estimationMultiCurrency.phtml`
- `templates/adminlte/helper/module/genericListKeyOption.phtml`
- `templates/adminlte/helper/module/genericListOption.phtml`
- `templates/adminlte/helper/module/genericMultipleListKeyOption.phtml`
- `templates/adminlte/helper/module/genericStatusListOption.phtml`
- `templates/adminlte/helper/module/iframe.phtml`
- `templates/adminlte/helper/module/langListOption.phtml`
- `templates/adminlte/helper/module/levelOption.phtml`
- `templates/adminlte/helper/module/message/message.phtml`
- `templates/adminlte/helper/module/serverPagination.phtml`
- `templates/adminlte/helper/module/themeListOption.phtml`
- `templates/adminlte/helper/module/userTypeListOption.phtml`
- `templates/adminlte/helper/module/yesNoOption.phtml`

**AJAX templates**
- `templates/adminlte/helper/error.phtml` <= `ANY /reservation/detail/{bookingCode}/{idLocation}/{idReservation}`
- `templates/adminlte/helper/guest/error.phtml` <= `ANY /reservation/detail/{bookingCode}/{idLocation}/{idReservation}`, `POST /register/reset/password`
- `templates/adminlte/helper/module/genericListKeyOption.phtml` <= `ANY /location/get/option/country/{country}`, `POST /address/province/get/option/{country}/{required}`, `POST /location/get/option/game-location/{idLocation}`, `POST /location/get/option/workstation/{idLocation}`, `POST /marketing/campaign/load/list/htmlTemplate/{idMarketingCampaign}/{idEmailImporter}`, `POST /payment/link/get/domain/{idOrganization}`, `POST /payment/link/get/product/{idDomain}/{idOrganization}/{type}`, `POST /qrcode/bulk/get/option/activity/{activityCode}`
- `templates/adminlte/helper/module/langListOption.phtml` <= `POST /lang/domain/get/option/{idDomain}`, `POST /lang/domain/get/option/{idDomain}/{opt}`, `POST /lang/get/option/{theme}`, `POST /lang/get/option/{theme}/{filterLang}`, `POST /lang/get/option/{theme}/{filterLang}/{opt}`

**JavaScript files**
- `templates/adminlte/customer/module/form/payment.phtml`
- `public/assets/adminlte/js/src/mainHelper.js`

**customSender chains**
- `templates/adminlte/helper/error.phtml`: templates/adminlte/customer/module/form/payment.phtml -> POST /customer/payment/invoice/view/{idUser}/{idPaymentTransaction} -> templates/adminlte/helper/error.phtml
- `templates/adminlte/helper/error.phtml`: templates/adminlte/customer/module/form/payment.phtml -> POST /customer/payment/invoice/generate/{idUser}/{idPaymentTransaction} -> templates/adminlte/helper/error.phtml
- `templates/adminlte/helper/module/genericListKeyOption.phtml`: public/assets/adminlte/js/src/mainHelper.js -> ANY /location/get/option/country/{country} -> templates/adminlte/helper/module/genericListKeyOption.phtml
- `templates/adminlte/helper/module/genericListKeyOption.phtml`: public/assets/adminlte/js/src/mainHelper.js -> POST /address/province/get/option/{country}/{required} -> templates/adminlte/helper/module/genericListKeyOption.phtml
- `templates/adminlte/helper/module/genericListKeyOption.phtml`: public/assets/adminlte/js/src/mainHelper.js -> POST /location/get/option/game-location/{idLocation} -> templates/adminlte/helper/module/genericListKeyOption.phtml
- `templates/adminlte/helper/module/langListOption.phtml`: public/assets/adminlte/js/src/mainHelper.js -> POST /lang/get/option/{theme} -> templates/adminlte/helper/module/langListOption.phtml
- `templates/adminlte/helper/module/langListOption.phtml`: public/assets/adminlte/js/src/mainHelper.js -> POST /lang/get/option/{theme}/{filterLang} -> templates/adminlte/helper/module/langListOption.phtml
- `templates/adminlte/helper/module/langListOption.phtml`: public/assets/adminlte/js/src/mainHelper.js -> POST /lang/get/option/{theme}/{filterLang}/{opt} -> templates/adminlte/helper/module/langListOption.phtml

### holiday

**Routes**
- `GET /holiday`
- `POST /holiday/detail/{idHoliday}`
- `POST /holiday/detail/{idHoliday}/{inLocation}`
- `POST /holiday/reload/list`
- `POST /holiday/reload/list/{idLocation}`

**Controllers**
- `App/Controller/Admin/Holiday/HolidayController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/HolidayTemplateRender.php`

**Templates**
- `templates/adminlte/holiday/index.phtml`
- `templates/adminlte/holiday/module/detail.phtml`
- `templates/adminlte/holiday/module/list.phtml`
- `templates/adminlte/holiday/module/location/detail.phtml`
- `templates/adminlte/holiday/module/location/index.phtml`
- `templates/adminlte/holiday/module/location/list.phtml`
- `templates/adminlte/holiday/module/location/new.phtml`
- `templates/adminlte/holiday/module/new.phtml`

**AJAX templates**
- `templates/adminlte/holiday/module/detail.phtml` <= `POST /holiday/detail/{idHoliday}`, `POST /holiday/detail/{idHoliday}/{inLocation}`
- `templates/adminlte/holiday/module/list.phtml` <= `POST /holiday/reload/list`, `POST /holiday/reload/list/{idLocation}`
- `templates/adminlte/holiday/module/location/detail.phtml` <= `POST /holiday/detail/{idHoliday}`, `POST /holiday/detail/{idHoliday}/{inLocation}`
- `templates/adminlte/holiday/module/location/list.phtml` <= `POST /holiday/reload/list`, `POST /holiday/reload/list/{idLocation}`

**JavaScript files**
- `templates/adminlte/holiday/module/list.phtml`
- `templates/adminlte/holiday/module/location/list.phtml`

**customSender chains**
- `templates/adminlte/holiday/module/detail.phtml`: templates/adminlte/holiday/module/list.phtml -> POST /holiday/detail/{idHoliday} -> templates/adminlte/holiday/module/detail.phtml
- `templates/adminlte/holiday/module/detail.phtml`: templates/adminlte/holiday/module/list.phtml -> POST /holiday/detail/{idHoliday}/{inLocation} -> templates/adminlte/holiday/module/detail.phtml
- `templates/adminlte/holiday/module/detail.phtml`: templates/adminlte/holiday/module/location/list.phtml -> POST /holiday/detail/{idHoliday} -> templates/adminlte/holiday/module/detail.phtml
- `templates/adminlte/holiday/module/detail.phtml`: templates/adminlte/holiday/module/location/list.phtml -> POST /holiday/detail/{idHoliday}/{inLocation} -> templates/adminlte/holiday/module/detail.phtml
- `templates/adminlte/holiday/module/location/detail.phtml`: templates/adminlte/holiday/module/list.phtml -> POST /holiday/detail/{idHoliday} -> templates/adminlte/holiday/module/location/detail.phtml
- `templates/adminlte/holiday/module/location/detail.phtml`: templates/adminlte/holiday/module/list.phtml -> POST /holiday/detail/{idHoliday}/{inLocation} -> templates/adminlte/holiday/module/location/detail.phtml
- `templates/adminlte/holiday/module/location/detail.phtml`: templates/adminlte/holiday/module/location/list.phtml -> POST /holiday/detail/{idHoliday} -> templates/adminlte/holiday/module/location/detail.phtml
- `templates/adminlte/holiday/module/location/detail.phtml`: templates/adminlte/holiday/module/location/list.phtml -> POST /holiday/detail/{idHoliday}/{inLocation} -> templates/adminlte/holiday/module/location/detail.phtml

### htmlTemplate

**Routes**
- `GET /htmlTemplate/builder/edit/{idHtmlTemplate}`
- `GET /template/html/template/{templateType}/{templateId}`
- `GET /htmlTemplate/detail/{idHtmlTemplate}`
- `GET /htmlTemplate/list`
- `GET /htmlTemplate/list/default`
- `GET /htmlTemplate/detail/{idHtmlTemplate}/iframe`
- `GET /htmlTemplate/new`
- `GET /htmlTemplate/new/by/model/{directory}/{key}`

**Controllers**
- `App/Controller/Admin/HtmlTemplateController.php`

**Managers**
- `App/Manager/HtmlTemplateManager.php`

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/htmlTemplate/builderJs/edit.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a0a8583a7/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a2135b974/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a2250a3a3/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a2401b055/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a24ebdbd6/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a25ddce80/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a26b0a286/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a275bf375/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a28418c95/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a29a35e05/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a2aa315d4/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a2b67ed27/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a2c3d7fa1/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/default/6037a2dcb6c56/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b5237afe01/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b524d6acbb/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b525bc015d/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b5263c3c6c/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b526bbfd4c/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b527444514/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b527be2bd2/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b5283e6c51/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b5289d3bc2/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b52910022d/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b529a0665a/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b52a201e37/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b52a91f5ba/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b52af333ad/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b52b657c89/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b52bc5fbfd/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b52c46f557/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5d7b52cbee554/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/5eeab07cbd8b4/index.phtml`
- `templates/adminlte/htmlTemplate/builderJs/resource/email/customGlass1/index.phtml`
- `templates/adminlte/htmlTemplate/detail.phtml`
- `templates/adminlte/htmlTemplate/list.phtml`
- `templates/adminlte/htmlTemplate/listDefaultTemplate.phtml`
- `templates/adminlte/htmlTemplate/module/iframe.phtml`
- `templates/adminlte/htmlTemplate/module/listDefaultTemplate.phtml`
- `templates/adminlte/htmlTemplate/module/trList.phtml`
- `templates/adminlte/htmlTemplate/new.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### include

**Routes**
- `ANY /analysis/individual`
- `ANY /analysis/individualRange`
- `ANY /analysis/v2/accounting-report`
- `ANY /analysis/v2/game-location-report`
- `ANY /analysis/v2/game-report`
- `ANY /analysis/v2/individual-range`
- `ANY /analysis/v2/individual-staff-report`
- `ANY /analysis/v2/loyalty-card-report`
- `ANY /reservation/detail/{bookingCode}/{idLocation}/{idReservation}`
- `GET /action/pt/{macAddress}/{serialNumber}`
- `GET /action/pulse-box/new/{macAddress}`
- `GET /login`
- `GET /register/activation/{idUser}/{activationToken}`
- `GET /register/pin-reset/{idUser}/{token}`
- `GET /register/pin/{idUser}/{token}`
- `GET /register/reset`

**Controllers**
- `App/Controller/Admin/AbsTrackerController.php`
- `App/Controller/Admin/Activity/ActivityPackageController.php`
- `App/Controller/Admin/AdsAccountController.php`
- `App/Controller/Admin/Analysis/FollowUpController.php`
- `App/Controller/Admin/Analysis/IndividualController.php`
- `App/Controller/Admin/Analysis/IndividualRangeController.php`
- `App/Controller/Admin/Analysis/ThemeController.php`
- `App/Controller/Admin/Analysis/YtdChargebackController.php`
- `... +119 more`
- `App/Controller/Admin/LoginController.php`
- `App/Controller/Admin/PaymentTerminal/PaymentTerminalController.php`
- `App/Controller/Admin/PulseBoxController.php`
- `App/Controller/Admin/RegisterController.php`
- `App/Controller/Admin/Reservation/ReservationDataController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Other renderers and parent relationships**
- `App/Helper/ControllerHelper.php`

**Templates**
- `templates/adminlte/include/footer.phtml`
- `templates/adminlte/include/guest/footer.phtml`
- `templates/adminlte/include/guest/header.phtml`
- `templates/adminlte/include/header.phtml`

**AJAX templates**
- `templates/adminlte/include/footer.phtml` <= `ANY /analysis/individual`, `ANY /analysis/individualRange`, `ANY /analysis/v2/accounting-report`, `ANY /analysis/v2/game-location-report`, `ANY /analysis/v2/game-report`, `ANY /analysis/v2/individual-range`, `ANY /analysis/v2/individual-staff-report`, `ANY /analysis/v2/loyalty-card-report`
- `templates/adminlte/include/guest/footer.phtml` <= `ANY /reservation/detail/{bookingCode}/{idLocation}/{idReservation}`
- `templates/adminlte/include/guest/header.phtml` <= `ANY /reservation/detail/{bookingCode}/{idLocation}/{idReservation}`
- `templates/adminlte/include/header.phtml` <= `ANY /analysis/individual`, `ANY /analysis/individualRange`, `ANY /analysis/v2/accounting-report`, `ANY /analysis/v2/game-location-report`, `ANY /analysis/v2/game-report`, `ANY /analysis/v2/individual-range`, `ANY /analysis/v2/individual-staff-report`, `ANY /analysis/v2/loyalty-card-report`

**JavaScript files**
- `templates/adminlte/debugLog/index.phtml`
- `templates/adminlte/reservation/module/quickEdit.phtml`
- `templates/adminlte/reservation/module/tr.phtml`
- `templates/adminlte/login/module/loginBox.phtml`

**customSender chains**
- `templates/adminlte/include/footer.phtml`: templates/adminlte/debugLog/index.phtml -> ANY /debug-log -> templates/adminlte/include/footer.phtml
- `templates/adminlte/include/footer.phtml`: templates/adminlte/reservation/module/quickEdit.phtml -> ANY /reservation -> templates/adminlte/include/footer.phtml
- `templates/adminlte/include/footer.phtml`: templates/adminlte/reservation/module/tr.phtml -> ANY /reservation -> templates/adminlte/include/footer.phtml
- `templates/adminlte/include/guest/footer.phtml`: templates/adminlte/login/module/loginBox.phtml -> POST /login -> templates/adminlte/include/guest/footer.phtml
- `templates/adminlte/include/guest/header.phtml`: templates/adminlte/login/module/loginBox.phtml -> POST /login -> templates/adminlte/include/guest/header.phtml
- `templates/adminlte/include/header.phtml`: templates/adminlte/debugLog/index.phtml -> ANY /debug-log -> templates/adminlte/include/header.phtml
- `templates/adminlte/include/header.phtml`: templates/adminlte/reservation/module/quickEdit.phtml -> ANY /reservation -> templates/adminlte/include/header.phtml
- `templates/adminlte/include/header.phtml`: templates/adminlte/reservation/module/tr.phtml -> ANY /reservation -> templates/adminlte/include/header.phtml

### issue

**Routes**
- `GET /issue/dashboard`

**Controllers**
- `App/Controller/Admin/Issue/IssueController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/issue/index.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### location

**Routes**
- `GET /location/detail/{idLocation}`
- `GET /location/list`
- `POST /location/get/option/nayax/{idOrganization}`
- `POST /location/prepare/organization-user/{token}`
- `POST /location/prepare/organization-user/{idOrganization}/{token}`
- `POST /location/prepare/user/{idOrganization}/{userType}/{token}`
- `GET /location/new`
- `POST /location/opening-hour/check-schedule/{idLocation}`

**Controllers**
- `App/Controller/Admin/LocationController.php`
- `App/Controller/Admin/LocationOpeningHourController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`
- `App/View/LocationTemplateRender.php`

**Templates**
- `templates/adminlte/location/detail.phtml`
- `templates/adminlte/location/index.phtml`
- `templates/adminlte/location/module/asListLabel.phtml`
- `templates/adminlte/location/module/asListOption.phtml`
- `templates/adminlte/location/module/detail.phtml`
- `templates/adminlte/location/module/generalSetting.phtml`
- `templates/adminlte/location/module/list.phtml`
- `templates/adminlte/location/module/nayaxSetting.phtml`
- `templates/adminlte/location/module/new.phtml`
- `templates/adminlte/location/module/openStatus.phtml`
- `templates/adminlte/location/module/organizationUser.phtml`
- `templates/adminlte/location/module/settingUser.phtml`
- `templates/adminlte/location/module/user.phtml`
- `templates/adminlte/location/new.phtml`
- `templates/adminlte/location/openingHour/module/detail.phtml`
- `templates/adminlte/location/openingHour/module/detailPeriod.phtml`
- `templates/adminlte/location/openingHour/module/scheduleCheckResult.phtml`
- `templates/adminlte/location/period/module/index.phtml`
- `templates/adminlte/location/period/module/list.phtml`
- `templates/adminlte/location/period/module/openingHoursMain.phtml`
- `templates/adminlte/location/workstation/module/detail.phtml`
- `templates/adminlte/location/workstation/module/detailListRfid.phtml`
- `templates/adminlte/location/workstation/module/list.phtml`
- `templates/adminlte/location/workstation/module/listPrinter.phtml`

**AJAX templates**
- `templates/adminlte/location/module/nayaxSetting.phtml` <= `POST /location/get/option/nayax/{idOrganization}`
- `templates/adminlte/location/module/organizationUser.phtml` <= `POST /location/prepare/organization-user/{token}`
- `templates/adminlte/location/module/organizationUser.phtml` <= `POST /location/prepare/organization-user/{idOrganization}/{token}`
- `templates/adminlte/location/module/user.phtml` <= `POST /location/prepare/user/{idOrganization}/{userType}/{token}`
- `templates/adminlte/location/openingHour/module/scheduleCheckResult.phtml` <= `POST /location/opening-hour/check-schedule/{idLocation}`

**JavaScript files**
- `templates/adminlte/location/module/new.phtml`
- `templates/adminlte/location/module/organizationUser.phtml`
- `templates/adminlte/location/detail.phtml`

**customSender chains**
- `templates/adminlte/location/module/organizationUser.phtml`: templates/adminlte/location/module/new.phtml -> POST /location/prepare/organization-user/{idOrganization}/{token} -> templates/adminlte/location/module/organizationUser.phtml
- `templates/adminlte/location/module/user.phtml`: templates/adminlte/location/module/organizationUser.phtml -> POST /location/prepare/user/{idOrganization}/{userType}/{token} -> templates/adminlte/location/module/user.phtml
- `templates/adminlte/location/openingHour/module/scheduleCheckResult.phtml`: templates/adminlte/location/detail.phtml -> POST /location/opening-hour/check-schedule/{idLocation} -> templates/adminlte/location/openingHour/module/scheduleCheckResult.phtml

### login

**Routes**
- `GET /login`
- `POST /login`

**Controllers**
- `App/Controller/Admin/LoginController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/login.phtml`
- `templates/adminlte/login/module/loginBox.phtml`

**AJAX templates**
- `templates/adminlte/login.phtml` <= `POST /login`
- `templates/adminlte/login/module/loginBox.phtml` <= `POST /login`

**JavaScript files**
- `templates/adminlte/login/module/loginBox.phtml`

**customSender chains**
- `templates/adminlte/login.phtml`: templates/adminlte/login/module/loginBox.phtml -> POST /login -> templates/adminlte/login.phtml
- `templates/adminlte/login/module/loginBox.phtml`: templates/adminlte/login/module/loginBox.phtml -> POST /login -> templates/adminlte/login/module/loginBox.phtml

### loyalty

**Routes**
- `GET /loyalty-card/detail/{idLoyaltyCard}`
- `GET /loyalty-card`
- `POST /loyalty-card/reload`
- `GET /loyalty-card-context`
- `POST /loyalty-card-context/detail/{idLoyaltyCardContext}`
- `POST /loyalty-card-context/reload/list`
- `GET /loyalty-card-operation`
- `GET /loyalty-card-package/detail/{idLoyaltyCardPackage}`
- `GET /loyalty-card-package/list`
- `POST /loyalty-card-package/location/{idLocation}`
- `GET /loyalty-card-package/new`
- `GET /loyalty-card-transaction`
- `GET /loyalty-tier`
- `POST /loyalty-tier/detail/{idLoyaltyTier}`
- `POST /loyalty-tier/reload/list`

**Controllers**
- `App/Controller/Admin/Loyalty/LoyaltyCardController.php`
- `App/Controller/Admin/Loyalty/LoyaltyCardContextController.php`
- `App/Controller/Admin/Loyalty/LoyaltyCardOperationController.php`
- `App/Controller/Admin/Loyalty/LoyaltyCardPackageController.php`
- `App/Controller/Admin/Loyalty/LoyaltyCardTransactionController.php`
- `App/Controller/Admin/Loyalty/LoyaltyTierController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/LoyaltyTemplateRender.php`

**Templates**
- `templates/adminlte/loyalty/loyaltyCard/detail.phtml`
- `templates/adminlte/loyalty/loyaltyCard/index.phtml`
- `templates/adminlte/loyalty/loyaltyCard/module/detail.phtml`
- `templates/adminlte/loyalty/loyaltyCard/module/list.phtml`
- `templates/adminlte/loyalty/loyaltyCard/module/listService.phtml`
- `templates/adminlte/loyalty/loyaltyCard/module/reset.phtml`
- `templates/adminlte/loyalty/loyaltyCardContext/index.phtml`
- `templates/adminlte/loyalty/loyaltyCardContext/module/detail.phtml`
- `templates/adminlte/loyalty/loyaltyCardContext/module/list.phtml`
- `templates/adminlte/loyalty/loyaltyCardContext/module/new.phtml`
- `templates/adminlte/loyalty/loyaltyCardOperation/list.phtml`
- `templates/adminlte/loyalty/loyaltyCardOperation/module/list.phtml`
- `templates/adminlte/loyalty/loyaltyCardPackage/detail.phtml`
- `templates/adminlte/loyalty/loyaltyCardPackage/list.phtml`
- `templates/adminlte/loyalty/loyaltyCardPackage/module/detail.phtml`
- `templates/adminlte/loyalty/loyaltyCardPackage/module/list.phtml`
- `templates/adminlte/loyalty/loyaltyCardPackage/module/listCompact.phtml`
- `templates/adminlte/loyalty/loyaltyCardPackage/module/new.phtml`
- `templates/adminlte/loyalty/loyaltyCardPackage/new.phtml`
- `templates/adminlte/loyalty/loyaltyCardTransaction/index.phtml`
- `templates/adminlte/loyalty/loyaltyCardTransaction/module/list.phtml`
- `templates/adminlte/loyalty/loyaltyTier/index.phtml`
- `templates/adminlte/loyalty/loyaltyTier/module/detail.phtml`
- `templates/adminlte/loyalty/loyaltyTier/module/list.phtml`
- `templates/adminlte/loyalty/loyaltyTier/module/new.phtml`

**AJAX templates**
- `templates/adminlte/loyalty/loyaltyCard/module/list.phtml` <= `POST /loyalty-card/reload`
- `templates/adminlte/loyalty/loyaltyCardContext/module/detail.phtml` <= `POST /loyalty-card-context/detail/{idLoyaltyCardContext}`
- `templates/adminlte/loyalty/loyaltyCardContext/module/list.phtml` <= `POST /loyalty-card-context/reload/list`
- `templates/adminlte/loyalty/loyaltyCardPackage/module/list.phtml` <= `POST /loyalty-card-package/location/{idLocation}`
- `templates/adminlte/loyalty/loyaltyCardPackage/module/listCompact.phtml` <= `POST /loyalty-card-package/location/{idLocation}`
- `templates/adminlte/loyalty/loyaltyTier/module/detail.phtml` <= `POST /loyalty-tier/detail/{idLoyaltyTier}`
- `templates/adminlte/loyalty/loyaltyTier/module/list.phtml` <= `POST /loyalty-tier/reload/list`

**JavaScript files**
- `templates/adminlte/loyalty/loyaltyCardContext/module/list.phtml`
- `templates/adminlte/loyalty/loyaltyTier/module/list.phtml`

**customSender chains**
- `templates/adminlte/loyalty/loyaltyCardContext/module/detail.phtml`: templates/adminlte/loyalty/loyaltyCardContext/module/list.phtml -> POST /loyalty-card-context/detail/{idLoyaltyCardContext} -> templates/adminlte/loyalty/loyaltyCardContext/module/detail.phtml
- `templates/adminlte/loyalty/loyaltyTier/module/detail.phtml`: templates/adminlte/loyalty/loyaltyTier/module/list.phtml -> POST /loyalty-tier/detail/{idLoyaltyTier} -> templates/adminlte/loyalty/loyaltyTier/module/detail.phtml

### mailbox

**Routes**
- `GET /mailbox/detail/{idTicket}`
- `GET /mailbox`
- `POST /mailbox/send/message`
- `POST /mailbox/send/message/{closeTicket}`
- `POST /mailbox/list/reload`
- `POST /mailbox/list/reload/{trash}`
- `POST /mailbox/detail/{idTicket}/load/message`
- `GET /mailbox/sent`
- `GET /mailbox/template/custom`
- `GET /mailbox/template/list`
- `POST /mailbox/template/custom/detail/{idCustomEmailTemplate}`
- `POST /mailbox/template/custom/reload/list`
- `POST /mailbox/template/custom/modal/{token}/{theme}/{lang}`
- `GET /mailbox/trash`

**Controllers**
- `App/Controller/Admin/MailboxController.php`
- `App/Controller/Admin/EmailTemplateController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/mailbox/detail.phtml`
- `templates/adminlte/mailbox/index.phtml`
- `templates/adminlte/mailbox/module/avatarUserFrom.phtml`
- `templates/adminlte/mailbox/module/langAsBtn.phtml`
- `templates/adminlte/mailbox/module/listTicketMessage.phtml`
- `templates/adminlte/mailbox/module/mailboxList.phtml`
- `templates/adminlte/mailbox/module/menu.phtml`
- `templates/adminlte/mailbox/module/priorityAsBtn.phtml`
- `templates/adminlte/mailbox/module/renderDetailOneTicket.phtml`
- `templates/adminlte/mailbox/module/renderOneTicket.phtml`
- `templates/adminlte/mailbox/module/sendMessage.phtml`
- `templates/adminlte/mailbox/module/ticketBox.phtml`
- `templates/adminlte/mailbox/module/ticketNumberAsBtn.phtml`
- `templates/adminlte/mailbox/sent.phtml`
- `templates/adminlte/mailbox/template/custom.phtml`
- `templates/adminlte/mailbox/template/list.phtml`
- `templates/adminlte/mailbox/template/module/detailCustom.phtml`
- `templates/adminlte/mailbox/template/module/listCustom.phtml`
- `templates/adminlte/mailbox/template/module/listCustomForComposer.phtml`
- `templates/adminlte/mailbox/template/module/listCustomForModalSelect.phtml`
- `templates/adminlte/mailbox/template/module/newCustom.phtml`
- `templates/adminlte/mailbox/trash.phtml`

**AJAX templates**
- `templates/adminlte/mailbox/module/listTicketMessage.phtml` <= `POST /mailbox/send/message`, `POST /mailbox/send/message/{closeTicket}`
- `templates/adminlte/mailbox/module/mailboxList.phtml` <= `POST /mailbox/list/reload`, `POST /mailbox/list/reload/{trash}`
- `templates/adminlte/mailbox/module/renderDetailOneTicket.phtml` <= `POST /mailbox/detail/{idTicket}/load/message`
- `templates/adminlte/mailbox/template/module/detailCustom.phtml` <= `POST /mailbox/template/custom/detail/{idCustomEmailTemplate}`
- `templates/adminlte/mailbox/template/module/listCustom.phtml` <= `POST /mailbox/template/custom/reload/list`
- `templates/adminlte/mailbox/template/module/listCustomForModalSelect.phtml` <= `POST /mailbox/template/custom/modal/{token}/{theme}/{lang}`

**JavaScript files**
- `public/assets/adminlte/js/src/whatsApp.js`
- `templates/adminlte/mailbox/module/sendMessage.phtml`
- `templates/adminlte/mailbox/template/module/listCustom.phtml`
- `templates/adminlte/mailbox/template/module/listCustomForComposer.phtml`

**customSender chains**
- `templates/adminlte/mailbox/module/listTicketMessage.phtml`: public/assets/adminlte/js/src/whatsApp.js -> POST /mailbox/send/message -> templates/adminlte/mailbox/module/listTicketMessage.phtml
- `templates/adminlte/mailbox/module/listTicketMessage.phtml`: templates/adminlte/mailbox/module/sendMessage.phtml -> POST /mailbox/send/message -> templates/adminlte/mailbox/module/listTicketMessage.phtml
- `templates/adminlte/mailbox/module/listTicketMessage.phtml`: templates/adminlte/mailbox/module/sendMessage.phtml -> POST /mailbox/send/message/{closeTicket} -> templates/adminlte/mailbox/module/listTicketMessage.phtml
- `templates/adminlte/mailbox/template/module/detailCustom.phtml`: templates/adminlte/mailbox/template/module/listCustom.phtml -> POST /mailbox/template/custom/detail/{idCustomEmailTemplate} -> templates/adminlte/mailbox/template/module/detailCustom.phtml
- `templates/adminlte/mailbox/template/module/listCustomForModalSelect.phtml`: templates/adminlte/mailbox/template/module/listCustomForComposer.phtml -> POST /mailbox/template/custom/modal/{token}/{theme}/{lang} -> templates/adminlte/mailbox/template/module/listCustomForModalSelect.phtml

### marketing

**Routes**
- `GET /marketing/ads/detail/{idMarketingAds}`
- `GET /marketing/ads`
- `POST /marketing/ads/reload/list`
- `GET /marketing/campaign/detail/{idMarketingCampaign}`
- `GET /marketing/campaign`
- `GET /marketing/campaign/log/detail/{idMarketingCampaignLog}`
- `POST /marketing/campaign/log/reload/{idMarketingCampaign}/{tokenLog}`
- `POST /marketing/campaign/load/map/htmlTemplate/{idMarketingCampaign}/{idEmailImporter}/{idHtmlTemplate}`
- `GET /marketing/campaign/preview/{idMarketingCampaign}`
- `GET /marketing/promo/detail/{idMarketingPromo}`
- `GET /marketing/promo/list`
- `GET /marketing/promo/new`
- `POST /marketing/promo/usage/reload/{idMarketingPromo}`
- `GET /marketing/tracker`
- `POST /marketing/tracker/reload`

**Controllers**
- `App/Controller/Admin/MarketingAdsController.php`
- `App/Controller/Admin/Marketing/MarketingCampaignController.php`
- `App/Controller/Admin/Marketing/Promo/MarketingPromoController.php`
- `App/Controller/Admin/Marketing/Promo/MarketingPromoUsageController.php`
- `App/Controller/Admin/MarketingTrackerController.php`

**Managers**
- `App/Manager/Marketing/MarketingCampaignManager.php`

**View renderers**
- `App/View/InnerTemplateRender.php`
- `App/View/MarketingPromoTemplateRender.php`

**Templates**
- `templates/adminlte/marketing/ads/detail.phtml`
- `templates/adminlte/marketing/ads/index.phtml`
- `templates/adminlte/marketing/ads/module/detail.phtml`
- `templates/adminlte/marketing/ads/module/detailRedditivity.phtml`
- `templates/adminlte/marketing/ads/module/detailStats.phtml`
- `templates/adminlte/marketing/ads/module/list.phtml`
- `templates/adminlte/marketing/ads/module/new.phtml`
- `templates/adminlte/marketing/campaign/detail.phtml`
- `templates/adminlte/marketing/campaign/index.phtml`
- `templates/adminlte/marketing/campaign/logDetail.phtml`
- `templates/adminlte/marketing/campaign/module/cron.phtml`
- `templates/adminlte/marketing/campaign/module/detail.phtml`
- `templates/adminlte/marketing/campaign/module/list.phtml`
- `templates/adminlte/marketing/campaign/module/log.phtml`
- `templates/adminlte/marketing/campaign/module/logDetail.phtml`
- `templates/adminlte/marketing/campaign/module/logDetailListEmail.phtml`
- `templates/adminlte/marketing/campaign/module/mapEmailImporterHtmlTemplate.phtml`
- `templates/adminlte/marketing/campaign/module/new.phtml`
- `templates/adminlte/marketing/campaign/preview.phtml`
- `templates/adminlte/marketing/promo/detail.phtml`
- `templates/adminlte/marketing/promo/index.phtml`
- `templates/adminlte/marketing/promo/module/list.phtml`
- `templates/adminlte/marketing/promo/module/packageUsage.phtml`
- `templates/adminlte/marketing/promo/module/periodGroup.phtml`
- `templates/adminlte/marketing/promo/new.phtml`
- `templates/adminlte/marketing/promo/usage/module/list.phtml`
- `templates/adminlte/marketing/tracker/list.phtml`
- `templates/adminlte/marketing/tracker/module/listMarketingTracker.phtml`

**AJAX templates**
- `templates/adminlte/marketing/ads/module/list.phtml` <= `POST /marketing/ads/reload/list`
- `templates/adminlte/marketing/campaign/module/log.phtml` <= `POST /marketing/campaign/log/reload/{idMarketingCampaign}/{tokenLog}`
- `templates/adminlte/marketing/campaign/module/mapEmailImporterHtmlTemplate.phtml` <= `POST /marketing/campaign/load/map/htmlTemplate/{idMarketingCampaign}/{idEmailImporter}/{idHtmlTemplate}`
- `templates/adminlte/marketing/promo/usage/module/list.phtml` <= `POST /marketing/promo/usage/reload/{idMarketingPromo}`
- `templates/adminlte/marketing/tracker/module/listMarketingTracker.phtml` <= `POST /marketing/tracker/reload`

**JavaScript files**
- `templates/adminlte/marketing/campaign/module/detail.phtml`

**customSender chains**
- `templates/adminlte/marketing/campaign/module/mapEmailImporterHtmlTemplate.phtml`: templates/adminlte/marketing/campaign/module/detail.phtml -> POST /marketing/campaign/load/map/htmlTemplate/{idMarketingCampaign}/{idEmailImporter}/{idHtmlTemplate} -> templates/adminlte/marketing/campaign/module/mapEmailImporterHtmlTemplate.phtml

### merchant

**Routes**
- `GET /merchant`
- `POST /merchant/detail/{idMerchant}`
- `POST /merchant/reload/list`

**Controllers**
- `App/Controller/Admin/MerchantController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/merchant/index.phtml`
- `templates/adminlte/merchant/module/detail.phtml`
- `templates/adminlte/merchant/module/list.phtml`
- `templates/adminlte/merchant/module/new.phtml`

**AJAX templates**
- `templates/adminlte/merchant/module/detail.phtml` <= `POST /merchant/detail/{idMerchant}`
- `templates/adminlte/merchant/module/list.phtml` <= `POST /merchant/reload/list`

**JavaScript files**
- `templates/adminlte/merchant/module/list.phtml`

**customSender chains**
- `templates/adminlte/merchant/module/detail.phtml`: templates/adminlte/merchant/module/list.phtml -> POST /merchant/detail/{idMerchant} -> templates/adminlte/merchant/module/detail.phtml

### module

**Routes**
- None mapped

**Controllers**
- None mapped

**Managers**
- None mapped

**View renderers**
- None mapped

**Other renderers and parent relationships**
- `App/Module/LoyaltyCardSacoaModule.php`

**Templates**
- `templates/adminlte/module/partialModule/loyaltyCardSacoa/detail.phtml`
- `templates/adminlte/module/partialModule/loyaltyCardSacoa/new.phtml`
- `templates/adminlte/module/partialModule/loyaltyCardSacoa/view.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### monitoring

**Routes**
- `GET /monitoring/alert/detail/{idMonitoringAlert}`
- `GET /monitoring`

**Controllers**
- `App/Controller/Admin/Monitoring/MonitoringController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/monitoring/alert-detail.phtml`
- `templates/adminlte/monitoring/dashboard.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### nayax

**Routes**
- `GET /nayax/outbound`
- `GET /nayax/pos/detail/{idNayaxPos}`
- `GET /nayax/pos/list`
- `GET /nayax/pos/sync`

**Controllers**
- `App/Controller/Admin/Nayax/NayaxOutboundController.php`
- `App/Controller/Admin/Nayax/NayaxPosController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/NayaxTemplateRender.php`

**Templates**
- `templates/adminlte/nayax/actor/module/listOption.phtml`
- `templates/adminlte/nayax/outbound/index.phtml`
- `templates/adminlte/nayax/pos/detail.phtml`
- `templates/adminlte/nayax/pos/list.phtml`
- `templates/adminlte/nayax/pos/module/list.phtml`
- `templates/adminlte/nayax/pos/module/sync.phtml`
- `templates/adminlte/nayax/pos/sync.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### nfcPayment

**Routes**
- `GET /nfc-payment/admin`
- `POST /nfc-payment/admin/list`

**Controllers**
- `App/Controller/Admin/NfcPayment/NfcPaymentAdminController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/nfcPayment/admin/index.phtml`
- `templates/adminlte/nfcPayment/admin/module/list.phtml`

**AJAX templates**
- `templates/adminlte/nfcPayment/admin/module/list.phtml` <= `POST /nfc-payment/admin/list`

**JavaScript files**
- `templates/adminlte/nfcPayment/admin/index.phtml`

**customSender chains**
- `templates/adminlte/nfcPayment/admin/module/list.phtml`: templates/adminlte/nfcPayment/admin/index.phtml -> POST /nfc-payment/admin/list -> templates/adminlte/nfcPayment/admin/module/list.phtml

### note

**Routes**
- `POST /note/create/{action}/{idAction}`
- `POST /note/create/{action}/{idAction}/{lastIdUser}`

**Controllers**
- `App/Controller/Admin/NoteController.php`

**Managers**
- `App/Manager/NoteManager.php`

**View renderers**
- None mapped

**Other renderers and parent relationships**
- `App/Model/Note.php`

**Templates**
- `templates/adminlte/note/module/adder.phtml`
- `templates/adminlte/note/module/cloudNoteSubModule.phtml`
- `templates/adminlte/note/module/listNoteGroup.phtml`
- `templates/adminlte/note/module/prepare.phtml`

**AJAX templates**
- `templates/adminlte/note/module/cloudNoteSubModule.phtml` <= `POST /note/create/{action}/{idAction}`, `POST /note/create/{action}/{idAction}/{lastIdUser}`

**JavaScript files**
- `templates/adminlte/note/module/listNoteGroup.phtml`
- `templates/adminlte/note/module/prepare.phtml`

**customSender chains**
- `templates/adminlte/note/module/cloudNoteSubModule.phtml`: templates/adminlte/note/module/listNoteGroup.phtml -> POST /note/create/{action}/{idAction} -> templates/adminlte/note/module/cloudNoteSubModule.phtml
- `templates/adminlte/note/module/cloudNoteSubModule.phtml`: templates/adminlte/note/module/listNoteGroup.phtml -> POST /note/create/{action}/{idAction}/{lastIdUser} -> templates/adminlte/note/module/cloudNoteSubModule.phtml
- `templates/adminlte/note/module/cloudNoteSubModule.phtml`: templates/adminlte/note/module/prepare.phtml -> POST /note/create/{action}/{idAction} -> templates/adminlte/note/module/cloudNoteSubModule.phtml
- `templates/adminlte/note/module/cloudNoteSubModule.phtml`: templates/adminlte/note/module/prepare.phtml -> POST /note/create/{action}/{idAction}/{lastIdUser} -> templates/adminlte/note/module/cloudNoteSubModule.phtml

### notification

**Routes**
- `GET /notification`
- `POST /notification/history/load`

**Controllers**
- `App/Controller/Admin/Notification/NotificationController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/notification/user/index.phtml`
- `templates/adminlte/notification/user/module/listAsWidget.phtml`

**AJAX templates**
- `templates/adminlte/notification/user/module/listAsWidget.phtml` <= `POST /notification/history/load`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### nuc

**Routes**
- `GET /nuc/detail/{idNuc}`
- `GET /nuc/list`
- `POST /nuc/command-queue/detail/{idNucCommandQueue}`
- `POST /nuc/command-queue/reload/{idNuc}`
- `POST /nuc/command-queue/main/{idNuc}`
- `POST /nuc/log/reload/{idNuc}`
- `POST /nuc/log-request/reload/{idNuc}`
- `POST /nuc/system-metric/detail/{idNucSystemMetric}`
- `POST /nuc/system-metric/reload/{idNuc}`
- `GET /nuc/new`

**Controllers**
- `App/Controller/Admin/Nuc/NucController.php`
- `App/Controller/Admin/Nuc/NucCommandQueueController.php`
- `App/Controller/Admin/Nuc/NucLogController.php`
- `App/Controller/Admin/Nuc/NucLogRequestController.php`
- `App/Controller/Admin/Nuc/NucSystemMetricController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`
- `App/View/NucCommandQueueTemplateRender.php`
- `App/View/NucSystemMetricTemplateRender.php`

**Templates**
- `templates/adminlte/nuc/detail.phtml`
- `templates/adminlte/nuc/list.phtml`
- `templates/adminlte/nuc/module/action.phtml`
- `templates/adminlte/nuc/module/commandQueue/detail.phtml`
- `templates/adminlte/nuc/module/commandQueue/list.phtml`
- `templates/adminlte/nuc/module/commandQueue/main.phtml`
- `templates/adminlte/nuc/module/commandQueue/new.phtml`
- `templates/adminlte/nuc/module/detail/info.phtml`
- `templates/adminlte/nuc/module/list.phtml`
- `templates/adminlte/nuc/module/log/list.phtml`
- `templates/adminlte/nuc/module/logRequest/list.phtml`
- `templates/adminlte/nuc/module/new.phtml`
- `templates/adminlte/nuc/module/systemMetric/detailGlances.phtml`
- `templates/adminlte/nuc/module/systemMetric/detailSpeedtest.phtml`
- `templates/adminlte/nuc/module/systemMetric/list.phtml`
- `templates/adminlte/nuc/module/systemMetric/listGlances.phtml`
- `templates/adminlte/nuc/module/systemMetric/listSpeedtest.phtml`
- `templates/adminlte/nuc/new.phtml`

**AJAX templates**
- `templates/adminlte/nuc/module/commandQueue/detail.phtml` <= `POST /nuc/command-queue/detail/{idNucCommandQueue}`
- `templates/adminlte/nuc/module/commandQueue/list.phtml` <= `POST /nuc/command-queue/reload/{idNuc}`
- `templates/adminlte/nuc/module/commandQueue/main.phtml` <= `POST /nuc/command-queue/main/{idNuc}`
- `templates/adminlte/nuc/module/log/list.phtml` <= `POST /nuc/log/reload/{idNuc}`
- `templates/adminlte/nuc/module/logRequest/list.phtml` <= `POST /nuc/log-request/reload/{idNuc}`
- `templates/adminlte/nuc/module/systemMetric/detailGlances.phtml` <= `POST /nuc/system-metric/detail/{idNucSystemMetric}`
- `templates/adminlte/nuc/module/systemMetric/detailSpeedtest.phtml` <= `POST /nuc/system-metric/detail/{idNucSystemMetric}`
- `templates/adminlte/nuc/module/systemMetric/list.phtml` <= `POST /nuc/system-metric/reload/{idNuc}`

**JavaScript files**
- `templates/adminlte/nuc/module/commandQueue/list.phtml`
- `templates/adminlte/nuc/module/systemMetric/listGlances.phtml`
- `templates/adminlte/nuc/module/systemMetric/listSpeedtest.phtml`

**customSender chains**
- `templates/adminlte/nuc/module/commandQueue/detail.phtml`: templates/adminlte/nuc/module/commandQueue/list.phtml -> POST /nuc/command-queue/detail/{idNucCommandQueue} -> templates/adminlte/nuc/module/commandQueue/detail.phtml
- `templates/adminlte/nuc/module/systemMetric/detailGlances.phtml`: templates/adminlte/nuc/module/systemMetric/listGlances.phtml -> POST /nuc/system-metric/detail/{idNucSystemMetric} -> templates/adminlte/nuc/module/systemMetric/detailGlances.phtml
- `templates/adminlte/nuc/module/systemMetric/detailGlances.phtml`: templates/adminlte/nuc/module/systemMetric/listSpeedtest.phtml -> POST /nuc/system-metric/detail/{idNucSystemMetric} -> templates/adminlte/nuc/module/systemMetric/detailGlances.phtml
- `templates/adminlte/nuc/module/systemMetric/detailSpeedtest.phtml`: templates/adminlte/nuc/module/systemMetric/listGlances.phtml -> POST /nuc/system-metric/detail/{idNucSystemMetric} -> templates/adminlte/nuc/module/systemMetric/detailSpeedtest.phtml
- `templates/adminlte/nuc/module/systemMetric/detailSpeedtest.phtml`: templates/adminlte/nuc/module/systemMetric/listSpeedtest.phtml -> POST /nuc/system-metric/detail/{idNucSystemMetric} -> templates/adminlte/nuc/module/systemMetric/detailSpeedtest.phtml

### odoo

**Routes**
- `GET /odoo/journal-entry`
- `POST /odoo/journal-entry/detail/{idOdooJournalEntry}`
- `POST /odoo/journal-entry/reload[/{odooJournalEntryStatus}]`
- `POST /odoo/journal-entry/tab/{odooJournalEntryStatus}`
- `POST /location/odoo-setting/{idLocation}`
- `GET /odoo/outbound`

**Controllers**
- `App/Controller/Admin/Odoo/OdooJournalEntryController.php`
- `App/Controller/Admin/LocationController.php`
- `App/Controller/Admin/Odoo/OdooOutboundController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/OdooTemplateRender.php`

**Templates**
- `templates/adminlte/odoo/journalEntry/index.phtml`
- `templates/adminlte/odoo/journalEntry/module/detail.phtml`
- `templates/adminlte/odoo/journalEntry/module/detailLoyaltyCard.phtml`
- `templates/adminlte/odoo/journalEntry/module/detailLoyaltyPackage.phtml`
- `templates/adminlte/odoo/journalEntry/module/detailRegularSale.phtml`
- `templates/adminlte/odoo/journalEntry/module/detailVarious.phtml`
- `templates/adminlte/odoo/journalEntry/module/list.phtml`
- `templates/adminlte/odoo/module/setting.phtml`
- `templates/adminlte/odoo/outbound/index.phtml`

**AJAX templates**
- `templates/adminlte/odoo/journalEntry/module/detail.phtml` <= `POST /odoo/journal-entry/detail/{idOdooJournalEntry}`
- `templates/adminlte/odoo/journalEntry/module/list.phtml` <= `POST /odoo/journal-entry/reload[/{odooJournalEntryStatus}]`, `POST /odoo/journal-entry/tab/{odooJournalEntryStatus}`
- `templates/adminlte/odoo/module/setting.phtml` <= `POST /location/odoo-setting/{idLocation}`

**JavaScript files**
- `templates/adminlte/odoo/journalEntry/module/detail.phtml`
- `templates/adminlte/odoo/journalEntry/module/list.phtml`
- `templates/adminlte/location/module/detail.phtml`

**customSender chains**
- `templates/adminlte/odoo/journalEntry/module/detail.phtml`: templates/adminlte/odoo/journalEntry/module/detail.phtml -> POST /odoo/journal-entry/detail/{idOdooJournalEntry} -> templates/adminlte/odoo/journalEntry/module/detail.phtml
- `templates/adminlte/odoo/journalEntry/module/detail.phtml`: templates/adminlte/odoo/journalEntry/module/list.phtml -> POST /odoo/journal-entry/detail/{idOdooJournalEntry} -> templates/adminlte/odoo/journalEntry/module/detail.phtml
- `templates/adminlte/odoo/module/setting.phtml`: templates/adminlte/location/module/detail.phtml -> POST /location/odoo-setting/{idLocation} -> templates/adminlte/odoo/module/setting.phtml

### openingWeek

**Routes**
- None mapped

**Controllers**
- None mapped

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/openingWeek/module/individualUpsert.phtml`
- `templates/adminlte/openingWeek/module/upsert.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### organization

**Routes**
- `GET /organization/detail/{idOrganization}`
- `GET /organization/list`
- `POST /organization/prepare/domain/{token}`
- `POST /organization/prepare/merchant/{idDomain}/{token}`
- `POST /organization/prepare/merchant/{idDomain}/{token}/{idOrganization}`
- `POST /organization/get/setting/{idDomain}/{token}/{idOrganization}`
- `GET /organization/new`

**Controllers**
- `App/Controller/Admin/OrganizationController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`
- `App/View/OrganizationTemplateRender.php`

**Templates**
- `templates/adminlte/organization/detail.phtml`
- `templates/adminlte/organization/index.phtml`
- `templates/adminlte/organization/module/detail.phtml`
- `templates/adminlte/organization/module/domain.phtml`
- `templates/adminlte/organization/module/list.phtml`
- `templates/adminlte/organization/module/merchant.phtml`
- `templates/adminlte/organization/module/new.phtml`
- `templates/adminlte/organization/module/setting.phtml`
- `templates/adminlte/organization/module/settingMerchant.phtml`
- `templates/adminlte/organization/new.phtml`

**AJAX templates**
- `templates/adminlte/organization/module/domain.phtml` <= `POST /organization/prepare/domain/{token}`
- `templates/adminlte/organization/module/merchant.phtml` <= `POST /organization/prepare/merchant/{idDomain}/{token}`, `POST /organization/prepare/merchant/{idDomain}/{token}/{idOrganization}`
- `templates/adminlte/organization/module/settingMerchant.phtml` <= `POST /organization/get/setting/{idDomain}/{token}/{idOrganization}`

**JavaScript files**
- `templates/adminlte/organization/module/detail.phtml`
- `templates/adminlte/organization/module/new.phtml`
- `templates/adminlte/organization/module/domain.phtml`
- `templates/adminlte/payment/link/module/new.phtml`

**customSender chains**
- `templates/adminlte/organization/module/domain.phtml`: templates/adminlte/organization/module/detail.phtml -> POST /organization/prepare/domain/{token} -> templates/adminlte/organization/module/domain.phtml
- `templates/adminlte/organization/module/domain.phtml`: templates/adminlte/organization/module/new.phtml -> POST /organization/prepare/domain/{token} -> templates/adminlte/organization/module/domain.phtml
- `templates/adminlte/organization/module/merchant.phtml`: templates/adminlte/organization/module/domain.phtml -> POST /organization/prepare/merchant/{idDomain}/{token} -> templates/adminlte/organization/module/merchant.phtml
- `templates/adminlte/organization/module/merchant.phtml`: templates/adminlte/organization/module/domain.phtml -> POST /organization/prepare/merchant/{idDomain}/{token}/{idOrganization} -> templates/adminlte/organization/module/merchant.phtml
- `templates/adminlte/organization/module/settingMerchant.phtml`: templates/adminlte/payment/link/module/new.phtml -> POST /organization/get/setting/{idDomain}/{token}/{idOrganization} -> templates/adminlte/organization/module/settingMerchant.phtml

### payment

**Routes**
- `GET /payment/link`
- `POST /organization/get/counter/{idDomain}/{token}/{idOrganization}`
- `POST /payment/link/list/reload`
- `ANY /payment/dispute`
- `POST /payment/dispute/{type}`
- `GET /payment/transaction`
- `POST /payment/transaction`
- `POST /payment/payout/detail/{idPayout}`
- `GET /payment-location`
- `GET /payment/payout`
- `POST /payment/payout/paid/detail/{idPayoutPaid}/{token}`

**Controllers**
- `App/Controller/Admin/PaymentLinkController.php`
- `App/Controller/Admin/OrganizationController.php`
- `App/Controller/Admin/PaymentController.php`
- `App/Controller/Admin/PayoutController.php`
- `App/Controller/Admin/Payment/PaymentLocation/PaymentLocationController.php`
- `App/Controller/Admin/PayoutPaidController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`
- `App/View/PaymentTemplateRenderer.php`

**Templates**
- `templates/adminlte/payment/link/index.phtml`
- `templates/adminlte/payment/link/module/counter.phtml`
- `templates/adminlte/payment/link/module/list.phtml`
- `templates/adminlte/payment/link/module/new.phtml`
- `templates/adminlte/payment/listDispute.phtml`
- `templates/adminlte/payment/listTransaction.phtml`
- `templates/adminlte/payment/module/listPayment.phtml`
- `templates/adminlte/payment/module/listPaymentTransaction.phtml`
- `templates/adminlte/payment/module/listPaymentTransactionChargeback.phtml`
- `templates/adminlte/payment/module/listPaymentTransactionInquiry.phtml`
- `templates/adminlte/payment/paymentLocation/indexPaymentOperation.phtml`
- `templates/adminlte/payment/paymentLocation/module/listPaymentOperation.phtml`
- `templates/adminlte/payment/payout/index.phtml`
- `templates/adminlte/payment/payout/module/payoutPaid.phtml`

**AJAX templates**
- `templates/adminlte/payment/link/module/counter.phtml` <= `POST /organization/get/counter/{idDomain}/{token}/{idOrganization}`
- `templates/adminlte/payment/link/module/list.phtml` <= `POST /payment/link/list/reload`
- `templates/adminlte/payment/listDispute.phtml` <= `ANY /payment/dispute`, `POST /payment/dispute/{type}`
- `templates/adminlte/payment/listTransaction.phtml` <= `POST /payment/transaction`
- `templates/adminlte/payment/module/listPaymentTransaction.phtml` <= `POST /payment/payout/detail/{idPayout}`, `POST /payment/transaction`
- `templates/adminlte/payment/module/listPaymentTransactionChargeback.phtml` <= `ANY /payment/dispute`, `POST /payment/dispute/{type}`
- `templates/adminlte/payment/module/listPaymentTransactionInquiry.phtml` <= `ANY /payment/dispute`, `POST /payment/dispute/{type}`
- `templates/adminlte/payment/payout/module/payoutPaid.phtml` <= `POST /payment/payout/paid/detail/{idPayoutPaid}/{token}`

**JavaScript files**
- `templates/adminlte/payment/link/module/new.phtml`
- `templates/adminlte/payment/payout/index.bck.phtml`
- `templates/adminlte/payment/payout/index.phtml`

**customSender chains**
- `templates/adminlte/payment/link/module/counter.phtml`: templates/adminlte/payment/link/module/new.phtml -> POST /organization/get/counter/{idDomain}/{token}/{idOrganization} -> templates/adminlte/payment/link/module/counter.phtml
- `templates/adminlte/payment/module/listPaymentTransaction.phtml`: templates/adminlte/payment/payout/index.bck.phtml -> POST /payment/payout/detail/{idPayout} -> templates/adminlte/payment/module/listPaymentTransaction.phtml
- `templates/adminlte/payment/module/listPaymentTransaction.phtml`: templates/adminlte/payment/payout/index.phtml -> POST /payment/payout/detail/{idPayout} -> templates/adminlte/payment/module/listPaymentTransaction.phtml

### paymentTerminal

**Routes**
- `GET /payment-terminal/config/game`
- `POST /payment-terminal/config/game/detail/{owner}/{idGame}`
- `POST /payment-terminal/config/game/list/{owner}`
- `GET /payment-terminal/config/game-location`
- `POST /payment-terminal/config/game-location/detail/{owner}/{idGameLocation}`
- `POST /payment-terminal/config/game-location/list-games/{owner}`
- `POST /payment-terminal/config/game-location/list/{owner}/{idGame}`
- `POST /payment-terminal/config/detail/{action}/{idAction}`
- `POST /payment-terminal/config/operational-mode/detail/{owner}/{mode}`
- `POST /payment-terminal/config/owner/detail/{idAction}`
- `POST /payment-terminal/skin-version/detail/{idSkinVersion}`
- `GET /payment-terminal/config/operational-mode`
- `GET /payment-terminal/config`
- `GET /payment-terminal/config/owner`
- `GET /payment-terminal/image-library`
- `POST /payment-terminal/image-library/list/{owner}`
- `GET /payment-terminal`
- `POST /payment-terminal/detail/{idPaymentTerminal}`
- `POST /payment-terminal/reload/list`
- `POST /payment-terminal/selector-preview`
- `GET /payment-terminal/skin-version`
- `POST /payment-terminal/skin-version/list/{owner}`
- `POST /payment-terminal/skin-version/reload/list`

**Controllers**
- `App/Controller/Admin/PaymentTerminal/PaymentTerminalConfigController.php`
- `App/Controller/Admin/PaymentTerminal/SkinVersionController.php`
- `App/Controller/Admin/PaymentTerminal/PaymentTerminalImageController.php`
- `App/Controller/Admin/PaymentTerminal/PaymentTerminalController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/PaymentTerminalTemplateRender.php`

**Other renderers and parent relationships**
- `templates/adminlte/paymentTerminal/config/game/module/detail.phtml`
- `templates/adminlte/paymentTerminal/config/gameLocation/module/detail.phtml`
- `templates/adminlte/paymentTerminal/config/operationalMode/module/detail.phtml`
- `templates/adminlte/paymentTerminal/config/owner/module/detail.phtml`
- `templates/adminlte/paymentTerminal/skinVersion/module/detail.phtml`

**Templates**
- `templates/adminlte/paymentTerminal/config/game/index.phtml`
- `templates/adminlte/paymentTerminal/config/game/module/detail.phtml`
- `templates/adminlte/paymentTerminal/config/game/module/list.phtml`
- `templates/adminlte/paymentTerminal/config/gameLocation/index.phtml`
- `templates/adminlte/paymentTerminal/config/gameLocation/module/detail.phtml`
- `templates/adminlte/paymentTerminal/config/gameLocation/module/gameSelect.phtml`
- `templates/adminlte/paymentTerminal/config/gameLocation/module/list.phtml`
- `templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml`
- `templates/adminlte/paymentTerminal/config/operationalMode/index.phtml`
- `templates/adminlte/paymentTerminal/config/operationalMode/module/detail.phtml`
- `templates/adminlte/paymentTerminal/config/owner/index.phtml`
- `templates/adminlte/paymentTerminal/config/owner/module/detail.phtml`
- `templates/adminlte/paymentTerminal/imageLibrary/index.phtml`
- `templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml`
- `templates/adminlte/paymentTerminal/index.phtml`
- `templates/adminlte/paymentTerminal/module/detail.phtml`
- `templates/adminlte/paymentTerminal/module/list.phtml`
- `templates/adminlte/paymentTerminal/module/new.phtml`
- `templates/adminlte/paymentTerminal/module/selectorPreview.phtml`
- `templates/adminlte/paymentTerminal/skinVersion/index.phtml`
- `templates/adminlte/paymentTerminal/skinVersion/module/detail.phtml`
- `templates/adminlte/paymentTerminal/skinVersion/module/list.phtml`

**AJAX templates**
- `templates/adminlte/paymentTerminal/config/game/module/detail.phtml` <= `POST /payment-terminal/config/game/detail/{owner}/{idGame}`
- `templates/adminlte/paymentTerminal/config/game/module/list.phtml` <= `POST /payment-terminal/config/game/list/{owner}`
- `templates/adminlte/paymentTerminal/config/gameLocation/module/detail.phtml` <= `POST /payment-terminal/config/game-location/detail/{owner}/{idGameLocation}`
- `templates/adminlte/paymentTerminal/config/gameLocation/module/gameSelect.phtml` <= `POST /payment-terminal/config/game-location/list-games/{owner}`
- `templates/adminlte/paymentTerminal/config/gameLocation/module/list.phtml` <= `POST /payment-terminal/config/game-location/list/{owner}/{idGame}`
- `templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml` <= `POST /payment-terminal/config/detail/{action}/{idAction}`, `POST /payment-terminal/config/game-location/detail/{owner}/{idGameLocation}`, `POST /payment-terminal/config/game/detail/{owner}/{idGame}`, `POST /payment-terminal/config/operational-mode/detail/{owner}/{mode}`, `POST /payment-terminal/config/owner/detail/{idAction}`, `POST /payment-terminal/skin-version/detail/{idSkinVersion}`
- `templates/adminlte/paymentTerminal/config/operationalMode/module/detail.phtml` <= `POST /payment-terminal/config/operational-mode/detail/{owner}/{mode}`
- `templates/adminlte/paymentTerminal/config/owner/module/detail.phtml` <= `POST /payment-terminal/config/detail/{action}/{idAction}`, `POST /payment-terminal/config/owner/detail/{idAction}`
- `templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml` <= `POST /payment-terminal/image-library/list/{owner}`
- `templates/adminlte/paymentTerminal/module/detail.phtml` <= `POST /payment-terminal/detail/{idPaymentTerminal}`
- `templates/adminlte/paymentTerminal/module/list.phtml` <= `POST /payment-terminal/reload/list`
- `templates/adminlte/paymentTerminal/module/selectorPreview.phtml` <= `POST /payment-terminal/selector-preview`
- `templates/adminlte/paymentTerminal/skinVersion/module/detail.phtml` <= `POST /payment-terminal/skin-version/detail/{idSkinVersion}`
- `templates/adminlte/paymentTerminal/skinVersion/module/list.phtml` <= `POST /payment-terminal/skin-version/list/{owner}`, `POST /payment-terminal/skin-version/reload/list`

**JavaScript files**
- `templates/adminlte/paymentTerminal/config/game/module/list.phtml`
- `templates/adminlte/paymentTerminal/config/game/index.phtml`
- `templates/adminlte/paymentTerminal/config/gameLocation/module/list.phtml`
- `templates/adminlte/paymentTerminal/config/gameLocation/index.phtml`
- `templates/adminlte/paymentTerminal/config/gameLocation/module/gameSelect.phtml`
- `templates/adminlte/paymentTerminal/config/index.phtml`
- `templates/adminlte/paymentTerminal/config/operationalMode/index.phtml`
- `templates/adminlte/paymentTerminal/config/owner/index.phtml`
- `public/assets/adminlte/js/src/mainHelper.js`
- `templates/adminlte/paymentTerminal/imageLibrary/index.phtml`
- `templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml`
- `templates/adminlte/paymentTerminal/module/list.phtml`
- `templates/adminlte/paymentTerminal/skinVersion/module/list.phtml`
- `templates/adminlte/paymentTerminal/skinVersion/index.phtml`

**customSender chains**
- `templates/adminlte/paymentTerminal/config/game/module/detail.phtml`: templates/adminlte/paymentTerminal/config/game/module/list.phtml -> POST /payment-terminal/config/game/detail/{owner}/{idGame} -> templates/adminlte/paymentTerminal/config/game/module/detail.phtml
- `templates/adminlte/paymentTerminal/config/game/module/list.phtml`: templates/adminlte/paymentTerminal/config/game/index.phtml -> POST /payment-terminal/config/game/list/{owner} -> templates/adminlte/paymentTerminal/config/game/module/list.phtml
- `templates/adminlte/paymentTerminal/config/gameLocation/module/detail.phtml`: templates/adminlte/paymentTerminal/config/gameLocation/module/list.phtml -> POST /payment-terminal/config/game-location/detail/{owner}/{idGameLocation} -> templates/adminlte/paymentTerminal/config/gameLocation/module/detail.phtml
- `templates/adminlte/paymentTerminal/config/gameLocation/module/gameSelect.phtml`: templates/adminlte/paymentTerminal/config/gameLocation/index.phtml -> POST /payment-terminal/config/game-location/list-games/{owner} -> templates/adminlte/paymentTerminal/config/gameLocation/module/gameSelect.phtml
- `templates/adminlte/paymentTerminal/config/gameLocation/module/list.phtml`: templates/adminlte/paymentTerminal/config/gameLocation/module/gameSelect.phtml -> POST /payment-terminal/config/game-location/list/{owner}/{idGame} -> templates/adminlte/paymentTerminal/config/gameLocation/module/list.phtml
- `templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml`: templates/adminlte/paymentTerminal/config/game/module/list.phtml -> POST /payment-terminal/config/game/detail/{owner}/{idGame} -> templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml
- `templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml`: templates/adminlte/paymentTerminal/config/gameLocation/module/list.phtml -> POST /payment-terminal/config/game-location/detail/{owner}/{idGameLocation} -> templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml
- `templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml`: templates/adminlte/paymentTerminal/config/index.phtml -> POST /payment-terminal/config/detail/{action}/{idAction} -> templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml
- `templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml`: templates/adminlte/paymentTerminal/config/operationalMode/index.phtml -> POST /payment-terminal/config/operational-mode/detail/{owner}/{mode} -> templates/adminlte/paymentTerminal/config/module/affectedDevice.phtml
- `templates/adminlte/paymentTerminal/config/operationalMode/module/detail.phtml`: templates/adminlte/paymentTerminal/config/operationalMode/index.phtml -> POST /payment-terminal/config/operational-mode/detail/{owner}/{mode} -> templates/adminlte/paymentTerminal/config/operationalMode/module/detail.phtml
- `templates/adminlte/paymentTerminal/config/owner/module/detail.phtml`: templates/adminlte/paymentTerminal/config/index.phtml -> POST /payment-terminal/config/detail/{action}/{idAction} -> templates/adminlte/paymentTerminal/config/owner/module/detail.phtml
- `templates/adminlte/paymentTerminal/config/owner/module/detail.phtml`: templates/adminlte/paymentTerminal/config/owner/index.phtml -> POST /payment-terminal/config/owner/detail/{idAction} -> templates/adminlte/paymentTerminal/config/owner/module/detail.phtml
- `templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml`: public/assets/adminlte/js/src/mainHelper.js -> POST /payment-terminal/image-library/list/{owner} -> templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml
- `templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml`: templates/adminlte/paymentTerminal/imageLibrary/index.phtml -> POST /payment-terminal/image-library/list/{owner} -> templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml
- `templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml`: templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml -> POST /payment-terminal/image-library/list/{owner} -> templates/adminlte/paymentTerminal/imageLibrary/module/list.phtml
- `templates/adminlte/paymentTerminal/module/detail.phtml`: templates/adminlte/paymentTerminal/module/list.phtml -> POST /payment-terminal/detail/{idPaymentTerminal} -> templates/adminlte/paymentTerminal/module/detail.phtml
- `templates/adminlte/paymentTerminal/skinVersion/module/detail.phtml`: templates/adminlte/paymentTerminal/skinVersion/module/list.phtml -> POST /payment-terminal/skin-version/detail/{idSkinVersion} -> templates/adminlte/paymentTerminal/skinVersion/module/detail.phtml
- `templates/adminlte/paymentTerminal/skinVersion/module/list.phtml`: templates/adminlte/paymentTerminal/skinVersion/index.phtml -> POST /payment-terminal/skin-version/list/{owner} -> templates/adminlte/paymentTerminal/skinVersion/module/list.phtml

### pda

**Routes**
- `GET /pda/detail/{idPda}`
- `GET /pda`
- `GET /pda/new`

**Controllers**
- `App/Controller/Admin/Pda/PdaController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/pda/detail.phtml`
- `templates/adminlte/pda/list.phtml`
- `templates/adminlte/pda/new.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### period

**Routes**
- `GET /period`
- `POST /period/detail/{idPeriod}`
- `POST /period/reload/list`

**Controllers**
- `App/Controller/Admin/PeriodController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/PeriodTemplateRender.php`

**Templates**
- `templates/adminlte/period/index.phtml`
- `templates/adminlte/period/module/detail.phtml`
- `templates/adminlte/period/module/list.phtml`
- `templates/adminlte/period/module/new.phtml`

**AJAX templates**
- `templates/adminlte/period/module/detail.phtml` <= `POST /period/detail/{idPeriod}`
- `templates/adminlte/period/module/list.phtml` <= `POST /period/reload/list`

**JavaScript files**
- `templates/adminlte/period/module/list.phtml`

**customSender chains**
- `templates/adminlte/period/module/detail.phtml`: templates/adminlte/period/module/list.phtml -> POST /period/detail/{idPeriod} -> templates/adminlte/period/module/detail.phtml

### permission

**Routes**
- `POST /user/permission/reload/{idUser}`

**Controllers**
- `App/Controller/Admin/UserController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/permission/module/hierarchyNode.phtml`
- `templates/adminlte/permission/module/permissionBox.phtml`
- `templates/adminlte/permission/module/permissionSelectorNode.phtml`
- `templates/adminlte/permission/module/permissionTreeSelector.phtml`
- `templates/adminlte/permission/module/permissionTreeViewer.phtml`

**AJAX templates**
- `templates/adminlte/permission/module/permissionBox.phtml` <= `POST /user/permission/reload/{idUser}`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### planet

**Routes**
- `GET /planet/location`
- `POST /planet/location/detail/{idPlanetLocation}`
- `POST /planet/location/reload/list`

**Controllers**
- `App/Controller/Admin/Planet/PlanetLocationController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/PlanetLocationTemplateRender.php`

**Templates**
- `templates/adminlte/planet/location/index.phtml`
- `templates/adminlte/planet/location/module/detail.phtml`
- `templates/adminlte/planet/location/module/list.phtml`
- `templates/adminlte/planet/location/module/new.phtml`

**AJAX templates**
- `templates/adminlte/planet/location/module/detail.phtml` <= `POST /planet/location/detail/{idPlanetLocation}`
- `templates/adminlte/planet/location/module/list.phtml` <= `POST /planet/location/reload/list`

**JavaScript files**
- `templates/adminlte/planet/location/module/list.phtml`

**customSender chains**
- `templates/adminlte/planet/location/module/detail.phtml`: templates/adminlte/planet/location/module/list.phtml -> POST /planet/location/detail/{idPlanetLocation} -> templates/adminlte/planet/location/module/detail.phtml

### pos

**Routes**
- `GET /pos/pos-terminal-device`
- `POST /pos/pos-terminal-device/detail/{idPosTerminalDevice}`
- `POST /pos/pos-terminal-device/reload/list`

**Controllers**
- `App/Controller/Admin/Pos/PosTerminalDeviceController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/PosTerminalDeviceTemplateRender.php`

**Templates**
- `templates/adminlte/pos/posTerminalDevice/index.phtml`
- `templates/adminlte/pos/posTerminalDevice/module/detail.phtml`
- `templates/adminlte/pos/posTerminalDevice/module/list.phtml`
- `templates/adminlte/pos/posTerminalDevice/module/new.phtml`

**AJAX templates**
- `templates/adminlte/pos/posTerminalDevice/module/detail.phtml` <= `POST /pos/pos-terminal-device/detail/{idPosTerminalDevice}`
- `templates/adminlte/pos/posTerminalDevice/module/list.phtml` <= `POST /pos/pos-terminal-device/reload/list`

**JavaScript files**
- `templates/adminlte/pos/posTerminalDevice/module/list.phtml`

**customSender chains**
- `templates/adminlte/pos/posTerminalDevice/module/detail.phtml`: templates/adminlte/pos/posTerminalDevice/module/list.phtml -> POST /pos/pos-terminal-device/detail/{idPosTerminalDevice} -> templates/adminlte/pos/posTerminalDevice/module/detail.phtml

### product

**Routes**
- `GET /product/detail/{idProduct}`
- `GET /product/import`
- `GET /product/list`
- `POST /product/location/list/{idLocation}`
- `POST /product/location/update/{idProductLocation}`
- `POST /product/location/update/{idProductLocation}/{idDataTableTr}/{idDataTable}`
- `POST /product/import/detail/{idFileUpload}`
- `GET /product/new`
- `POST /product/location/reload/list/{idProductCountry}`
- `POST /product/location/detail/{idProductLocation}`
- `POST /product/location/detail/{idProductLocation}/{idDataTableTr}/{idDataTable}`

**Controllers**
- `App/Controller/Admin/Product/ProductController.php`
- `App/Controller/Admin/Product/ProductImportController.php`
- `App/Controller/Admin/Product/ProductLocationController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/ProductTemplateRenderer.php`

**Templates**
- `templates/adminlte/product/detail.phtml`
- `templates/adminlte/product/import.phtml`
- `templates/adminlte/product/list.phtml`
- `templates/adminlte/product/location/module/list.phtml`
- `templates/adminlte/product/location/module/tr.phtml`
- `templates/adminlte/product/module/detail.phtml`
- `templates/adminlte/product/module/detailImport.phtml`
- `templates/adminlte/product/module/list.phtml`
- `templates/adminlte/product/module/listImport.phtml`
- `templates/adminlte/product/module/new.phtml`
- `templates/adminlte/product/new.phtml`
- `templates/adminlte/product/setting/country/module/detail.phtml`
- `templates/adminlte/product/setting/country/module/list.phtml`
- `templates/adminlte/product/setting/country/module/new.phtml`
- `templates/adminlte/product/setting/location/module/detail.phtml`
- `templates/adminlte/product/setting/location/module/new.phtml`

**AJAX templates**
- `templates/adminlte/product/location/module/list.phtml` <= `POST /product/location/list/{idLocation}`
- `templates/adminlte/product/location/module/tr.phtml` <= `POST /product/location/update/{idProductLocation}`, `POST /product/location/update/{idProductLocation}/{idDataTableTr}/{idDataTable}`
- `templates/adminlte/product/module/detailImport.phtml` <= `POST /product/import/detail/{idFileUpload}`
- `templates/adminlte/product/setting/country/module/list.phtml` <= `POST /product/location/reload/list/{idProductCountry}`
- `templates/adminlte/product/setting/location/module/detail.phtml` <= `POST /product/location/detail/{idProductLocation}`, `POST /product/location/detail/{idProductLocation}/{idDataTableTr}/{idDataTable}`

**JavaScript files**
- `templates/adminlte/product/setting/location/module/detail.phtml`
- `templates/adminlte/product/module/listImport.phtml`
- `templates/adminlte/product/location/module/list.phtml`
- `templates/adminlte/product/setting/country/module/list.phtml`

**customSender chains**
- `templates/adminlte/product/location/module/tr.phtml`: templates/adminlte/product/setting/location/module/detail.phtml -> POST /product/location/update/{idProductLocation} -> templates/adminlte/product/location/module/tr.phtml
- `templates/adminlte/product/location/module/tr.phtml`: templates/adminlte/product/setting/location/module/detail.phtml -> POST /product/location/update/{idProductLocation}/{idDataTableTr}/{idDataTable} -> templates/adminlte/product/location/module/tr.phtml
- `templates/adminlte/product/module/detailImport.phtml`: templates/adminlte/product/module/listImport.phtml -> POST /product/import/detail/{idFileUpload} -> templates/adminlte/product/module/detailImport.phtml
- `templates/adminlte/product/setting/location/module/detail.phtml`: templates/adminlte/product/location/module/list.phtml -> POST /product/location/detail/{idProductLocation} -> templates/adminlte/product/setting/location/module/detail.phtml
- `templates/adminlte/product/setting/location/module/detail.phtml`: templates/adminlte/product/location/module/list.phtml -> POST /product/location/detail/{idProductLocation}/{idDataTableTr}/{idDataTable} -> templates/adminlte/product/setting/location/module/detail.phtml
- `templates/adminlte/product/setting/location/module/detail.phtml`: templates/adminlte/product/setting/country/module/list.phtml -> POST /product/location/detail/{idProductLocation} -> templates/adminlte/product/setting/location/module/detail.phtml
- `templates/adminlte/product/setting/location/module/detail.phtml`: templates/adminlte/product/setting/country/module/list.phtml -> POST /product/location/detail/{idProductLocation}/{idDataTableTr}/{idDataTable} -> templates/adminlte/product/setting/location/module/detail.phtml

### productRequest

**Routes**

`{idOperator}` is the technologies operator the request belongs to, resolved from its `owner`
through `TechnologiesOperatorResolver`. It is carried in the route because the outbound `/api/v1`
calls need it in their path, and list rows already know it — see `../apis.md`.

- `GET /product-request/list` — unscoped: it loops every owner the user has.
- `GET /product-request/new` — unscoped: a static menu link, reached before an owner is chosen (the wizard's own owner picker chooses it).
- `GET /product-request/edit/{idOperator}/{idProductRequest}`
- `GET /product-request/detail/{idOperator}/{idProductRequest}`
- `GET /product-request/detail/{idProductRequest}` — back-compat only (`redirectDetail()`): finds which of the user's owners holds the request and 302s to the operator-scoped URL, so old bookmarks and already-queued notification links keep working.
- `POST /product-request/create` — unscoped: resolves the operator from the posted `owner`.
- `POST /product-request/update/{idOperator}/{idProductRequest}`
- `POST /product-request/preview/grouping` — unscoped: reads the global catalog only.
- `POST /product-request/resolve/address/{idWarehouse}` — unscoped: local warehouse data only.
- `POST /product-request/submit/{idOperator}/{idProductRequest}`
- `POST /product-request/approve/{idOperator}/{idProductRequest}`
- `POST /product-request/reject/{idOperator}/{idProductRequest}`
- `POST /product-request/return-to-draft/{idOperator}/{idProductRequest}`
- `POST /product-request/{idOperator}/{idProductRequest}/shipping/{idShipping}/issue[/modal]` — reports a shipping issue (missing/damaged/incorrect/other) against one shipment. Reception itself (received/not received) is a Technologies-side-only decision now (per `sapienscore-technologies`' `../decisions/0011-shipping-reception-simplification.md`) — this side no longer records receipt, so this is the only write action left here for shipping.

**Controllers**
- `App/Controller/Admin/ProductRequestController.php`

**Managers**
- `App/Manager/API/Admin/SapienscoreTechnologies/Outbound/OutboundProductRequestManager.php`
- `App/Manager/API/Admin/SapienscoreTechnologies/Outbound/OutboundProductManager.php`
- `App/Manager/API/Admin/SapienscoreTechnologies/Outbound/OutboundShippingManager.php` — also `reportIssue()`, the issue-report write (technologies side: `APIShippingController::reportIssue`).

**View renderers**
- `App/View/ProductRequestTemplateRender.php`

**NoDb helpers (status/vocabulary mirrored from technologies, no local persistence)**
- `App/Model/NoDb/ShippingStatus.php` — mirrors `Shipping::STATUS_*`; renders the read-only shipment status badge. A shipment not yet marked received simply stays `STATUS_SENT` — there is no "not received" status.
- `App/Model/NoDb/ShippingIssueType.php` — mirrors `ShippingIssue::TYPE_*` (missing/damaged/incorrect/other) for the "report an issue" modal's type dropdown.

**Templates**
- `templates/adminlte/productRequest/list.phtml`
- `templates/adminlte/productRequest/create.phtml`
- `templates/adminlte/productRequest/edit.phtml`
- `templates/adminlte/productRequest/detail.phtml`
- `templates/adminlte/productRequest/module/detail.phtml`
- `templates/adminlte/productRequest/module/list.phtml`
- `templates/adminlte/productRequest/module/listLine.phtml`
- `templates/adminlte/productRequest/module/listTabSection.phtml`
- `templates/adminlte/productRequest/module/groupingPreview.phtml`
- `templates/adminlte/productRequest/module/shippingList.phtml` — read-only shipment list (per-product sent quantity, no reception input) plus a "Report an issue" button per shipment; `productRequest.showReportShippingIssueModal()` fetches the modal body server-side (see AJAX templates below) instead of toggling static markup. CSS: `public/assets/adminlte/css/productRequestReception.css` (loaded only on `renderDetail()` for physical requests).
- `templates/adminlte/productRequest/module/reportShippingIssueModal.phtml` — body-only fragment for the shared `#modalDiv` (type select + optional product select, scoped to this shipment's own lines only, shown only when the shipment has any + description textarea + `btnActionModal` confirm button with `idProductRequest`/`idShipping` baked into its own `onclick`, mirroring `note/module/prepare.phtml`'s idiom).
- `templates/adminlte/productRequest/module/statusHistory.phtml`
- `templates/adminlte/productRequest/module/lineRow.phtml`
- `templates/adminlte/productRequest/module/destinationBlock.phtml`

**AJAX templates**
- `templates/adminlte/productRequest/module/groupingPreview.phtml` <= `POST /product-request/preview/grouping`
- `templates/adminlte/productRequest/module/reportShippingIssueModal.phtml` <= `POST /product-request/{idProductRequest}/shipping/{idShipping}/issue/modal` (`ReturnHandlerBuilder::SUB_TYPE_MODAL`, injected into the shared `#modalDiv` by `returnHandler.js`/`modalHelper.js`).
- `POST /product-request/resolve/address/{idWarehouse}` returns an eval script (`productRequest.applyResolvedAddress(...)`), not a rendered template.
- `POST /product-request/submit`, `/approve`, `/reject`, `/return-to-draft`, `/create`, `/update/{idProductRequest}` respond with a redirect (`ReturnHandlerBuilder::SUB_REDIRECT_TO`) to `GET /product-request/list` or `GET /product-request/detail/{idProductRequest}`, not a template swap.

**JavaScript files**
- `templates/adminlte/productRequest/create.phtml`
- `templates/adminlte/productRequest/edit.phtml`
  - Both driven by `public/assets/adminlte/js/src/productRequest.js` (destination groups + lines wizard; `edit.phtml` bootstraps `productRequest.groupIndex`/`lineIndex` from server-rendered state before reusing the same `addDestination()`/`addLine()`/`submitDraft(url)` flow).

**customSender chains**
- `templates/adminlte/productRequest/create.phtml`: `customSender.serializeAndSendAsy('product-request/preview/grouping', 'productRequestForm', false);` -> `POST /product-request/preview/grouping` -> `templates/adminlte/productRequest/module/groupingPreview.phtml`
- `templates/adminlte/productRequest/edit.phtml`: `customSender.serializeAndSendAsy('product-request/preview/grouping', 'productRequestForm', false);` -> `POST /product-request/preview/grouping` -> `templates/adminlte/productRequest/module/groupingPreview.phtml`
- `templates/adminlte/productRequest/module/detail.phtml`: `customSender.serializeAndSendAsy('product-request/submit', ...)` / `/approve` / `/reject` / `/return-to-draft` -> redirect to `templates/adminlte/productRequest/detail.phtml`. The "Closure Request" button no longer submits anything — it opens the static `#productRequestClosureInfoModal` (Smartmonkey contact info), same file.
- `templates/adminlte/productRequest/module/shippingList.phtml`: `productRequest.showReportShippingIssueModal(idProductRequest, idShipping)` -> `customSender.sendAsySingleRoute('product-request/{idProductRequest}/shipping/{idShipping}/issue/modal')` -> `templates/adminlte/productRequest/module/reportShippingIssueModal.phtml` injected into `#modalDiv`; its own confirm button then does `customSender.serializeAndSendAsy('product-request/{idProductRequest}/shipping/{idShipping}/issue', token)` -> `POST /product-request/{idProductRequest}/shipping/{idShipping}/issue` -> redirect to `templates/adminlte/productRequest/detail.phtml` (same `SUB_REDIRECT_TO` convention as `submit`/`approve`).

### profile

**Routes**
- `GET /profile`
- `POST /telegram/setting/save`

**Controllers**
- `App/Controller/Admin/ProfileController.php`
- `App/Controller/Admin/TelegramController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/profile/index.phtml`
- `templates/adminlte/profile/module/telegram.phtml`

**AJAX templates**
- `templates/adminlte/profile/module/telegram.phtml` <= `POST /telegram/setting/save`

**JavaScript files**
- `templates/adminlte/profile/module/telegram.phtml`

**customSender chains**
- `templates/adminlte/profile/module/telegram.phtml`: templates/adminlte/profile/module/telegram.phtml -> POST /telegram/setting/save -> templates/adminlte/profile/module/telegram.phtml

### pulseBox

**Routes**
- `GET /pulse-box/game-default`
- `POST /pulse-box/game-default/create-and-detail/{owner}/{idGame}`
- `POST /pulse-box/game-default/detail/{idPulseBoxGameDefault}`
- `POST /pulse-box/game-default/list/{owner}`
- `POST /pulse-box/game-default/reload/list`
- `GET /pulse-box`
- `POST /pulse-box/detail/{idPulseBox}`
- `POST /pulse-box/option/game-location/{idLocation}`
- `POST /pulse-box/reload/list`

**Controllers**
- `App/Controller/Admin/PulseBox/PulseBoxGameDefaultController.php`
- `App/Controller/Admin/PulseBoxController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/PulseBoxTemplateRender.php`

**Templates**
- `templates/adminlte/pulseBox/gameDefault/index.phtml`
- `templates/adminlte/pulseBox/gameDefault/module/detail.phtml`
- `templates/adminlte/pulseBox/gameDefault/module/list.phtml`
- `templates/adminlte/pulseBox/index.phtml`
- `templates/adminlte/pulseBox/module/detail.phtml`
- `templates/adminlte/pulseBox/module/gameLocationGroupedOption.phtml`
- `templates/adminlte/pulseBox/module/list.phtml`
- `templates/adminlte/pulseBox/module/new.phtml`

**AJAX templates**
- `templates/adminlte/pulseBox/gameDefault/module/detail.phtml` <= `POST /pulse-box/game-default/create-and-detail/{owner}/{idGame}`, `POST /pulse-box/game-default/detail/{idPulseBoxGameDefault}`
- `templates/adminlte/pulseBox/gameDefault/module/list.phtml` <= `POST /pulse-box/game-default/list/{owner}`, `POST /pulse-box/game-default/reload/list`
- `templates/adminlte/pulseBox/module/detail.phtml` <= `POST /pulse-box/detail/{idPulseBox}`
- `templates/adminlte/pulseBox/module/gameLocationGroupedOption.phtml` <= `POST /pulse-box/option/game-location/{idLocation}`
- `templates/adminlte/pulseBox/module/list.phtml` <= `POST /pulse-box/reload/list`

**JavaScript files**
- `templates/adminlte/pulseBox/gameDefault/module/list.phtml`
- `templates/adminlte/pulseBox/gameDefault/index.phtml`
- `templates/adminlte/pulseBox/module/list.phtml`
- `public/assets/adminlte/js/src/mainHelper.js`

**customSender chains**
- `templates/adminlte/pulseBox/gameDefault/module/detail.phtml`: templates/adminlte/pulseBox/gameDefault/module/list.phtml -> POST /pulse-box/game-default/create-and-detail/{owner}/{idGame} -> templates/adminlte/pulseBox/gameDefault/module/detail.phtml
- `templates/adminlte/pulseBox/gameDefault/module/detail.phtml`: templates/adminlte/pulseBox/gameDefault/module/list.phtml -> POST /pulse-box/game-default/detail/{idPulseBoxGameDefault} -> templates/adminlte/pulseBox/gameDefault/module/detail.phtml
- `templates/adminlte/pulseBox/gameDefault/module/list.phtml`: templates/adminlte/pulseBox/gameDefault/index.phtml -> POST /pulse-box/game-default/list/{owner} -> templates/adminlte/pulseBox/gameDefault/module/list.phtml
- `templates/adminlte/pulseBox/module/detail.phtml`: templates/adminlte/pulseBox/module/list.phtml -> POST /pulse-box/detail/{idPulseBox} -> templates/adminlte/pulseBox/module/detail.phtml
- `templates/adminlte/pulseBox/module/gameLocationGroupedOption.phtml`: public/assets/adminlte/js/src/mainHelper.js -> POST /pulse-box/option/game-location/{idLocation} -> templates/adminlte/pulseBox/module/gameLocationGroupedOption.phtml

### qrcode

**Routes**
- `GET /qrcode/bulk/detail/{idQrCodeBulk}`
- `GET /qrcode/bulk/list`
- `GET /qrcode/bulk/new`
- `POST /game-location/update/{idGameLocation}`
- `POST /qrcode/assign/{idGameLocation}`
- `GET /qrcode/nfc`
- `POST /qrcode/nfc/detail/{idQrcode}`
- `POST /qrcode/nfc/reload`

**Controllers**
- `App/Controller/Admin/QrCode/QrCodeBulkController.php`
- `App/Controller/Admin/Game/GameLocationController.php`
- `App/Controller/Admin/QrCode/QrCodeController.php`
- `App/Controller/Admin/QrCode/QrCodeNfcController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/QrcodeBulkTemplateRender.php`
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/qrcode/bulk/detail.phtml`
- `templates/adminlte/qrcode/bulk/index.phtml`
- `templates/adminlte/qrcode/bulk/module/detail.phtml`
- `templates/adminlte/qrcode/bulk/module/list.phtml`
- `templates/adminlte/qrcode/bulk/module/new.phtml`
- `templates/adminlte/qrcode/bulk/new.phtml`
- `templates/adminlte/qrcode/module/action.phtml`
- `templates/adminlte/qrcode/module/shortDetail.phtml`
- `templates/adminlte/qrcode/nfc/index.phtml`
- `templates/adminlte/qrcode/nfc/module/detail.phtml`
- `templates/adminlte/qrcode/nfc/module/list.phtml`

**AJAX templates**
- `templates/adminlte/qrcode/module/action.phtml` <= `POST /game-location/update/{idGameLocation}`, `POST /qrcode/assign/{idGameLocation}`
- `templates/adminlte/qrcode/module/shortDetail.phtml` <= `POST /qrcode/assign/{idGameLocation}`
- `templates/adminlte/qrcode/nfc/module/detail.phtml` <= `POST /qrcode/nfc/detail/{idQrcode}`
- `templates/adminlte/qrcode/nfc/module/list.phtml` <= `POST /qrcode/nfc/reload`

**JavaScript files**
- `templates/adminlte/game/gameLocation/module/detail.phtml`
- `templates/adminlte/game/gameLocation/module/list.phtml`
- `templates/adminlte/qrcode/module/action.phtml`
- `templates/adminlte/qrcode/nfc/module/list.phtml`

**customSender chains**
- `templates/adminlte/qrcode/module/action.phtml`: templates/adminlte/game/gameLocation/module/detail.phtml -> POST /game-location/update/{idGameLocation} -> templates/adminlte/qrcode/module/action.phtml
- `templates/adminlte/qrcode/module/action.phtml`: templates/adminlte/game/gameLocation/module/detail.phtml -> POST /qrcode/assign/{idGameLocation} -> templates/adminlte/qrcode/module/action.phtml
- `templates/adminlte/qrcode/module/action.phtml`: templates/adminlte/game/gameLocation/module/list.phtml -> POST /qrcode/assign/{idGameLocation} -> templates/adminlte/qrcode/module/action.phtml
- `templates/adminlte/qrcode/module/action.phtml`: templates/adminlte/qrcode/module/action.phtml -> POST /qrcode/assign/{idGameLocation} -> templates/adminlte/qrcode/module/action.phtml
- `templates/adminlte/qrcode/module/shortDetail.phtml`: templates/adminlte/game/gameLocation/module/detail.phtml -> POST /qrcode/assign/{idGameLocation} -> templates/adminlte/qrcode/module/shortDetail.phtml
- `templates/adminlte/qrcode/module/shortDetail.phtml`: templates/adminlte/game/gameLocation/module/list.phtml -> POST /qrcode/assign/{idGameLocation} -> templates/adminlte/qrcode/module/shortDetail.phtml
- `templates/adminlte/qrcode/module/shortDetail.phtml`: templates/adminlte/qrcode/module/action.phtml -> POST /qrcode/assign/{idGameLocation} -> templates/adminlte/qrcode/module/shortDetail.phtml
- `templates/adminlte/qrcode/nfc/module/detail.phtml`: templates/adminlte/qrcode/nfc/module/list.phtml -> POST /qrcode/nfc/detail/{idQrcode} -> templates/adminlte/qrcode/nfc/module/detail.phtml

### register

**Routes**
- `GET /register/pin/{idUser}/{token}`
- `GET /register/pin-reset/{idUser}/{token}`
- `GET /register/reset`
- `GET /register/activation/{idUser}/{activationToken}`

**Controllers**
- `App/Controller/Admin/RegisterController.php`

**Managers**
- None mapped

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/register/pinChange.phtml`
- `templates/adminlte/register/pinReset.phtml`
- `templates/adminlte/register/reset.phtml`
- `templates/adminlte/register/setup.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### reservation

**Routes**
- `ANY /reservation`
- `ANY /reservation/list`
- `GET /reservation/location/{idLocation}`
- `ANY /reservation/detail/{bookingCode}/{idLocation}/{idReservation}`
- `ANY /reservation/new`
- `ANY /reservation/activity-type/{idLocation}`
- `ANY /reservation/calendar-view/{idLocation}`
- `GET /reservation/calendar-data`
- `POST /reservation/action/cancel-refund/{idReservation}`
- `POST /reservation/action/cancel/{idReservation}`
- `POST /reservation/action/quick-update/{idReservation}`
- `ANY /reservation/customer-info-form/{idLocation}`
- `ANY /reservation/day-detail/{idLocation}`
- `ANY /reservation/create`
- `ANY /reservation/time-slot/{idLocation}`
- `GET /reservation/time-slots`
- `POST /reservation/action/quick-edit/{idReservation}`

**Controllers**
- `App/Controller/Admin/Reservation/ReservationController.php`
- `App/Controller/Porto/Reservation/ReservationController.php`
- `App/Controller/Admin/Reservation/ReservationDataController.php`
- `App/Controller/Porto/Reservation/DataController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/ReservationTemplateRender.php`
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/reservation/index.phtml`
- `templates/adminlte/reservation/index-v2.phtml`
- `templates/adminlte/reservation/module/activityType.phtml`
- `templates/adminlte/reservation/module/calendar.phtml`
- `templates/adminlte/reservation/module/calendarDay.phtml`
- `templates/adminlte/reservation/module/cancelModal.phtml`
- `templates/adminlte/reservation/module/customerDetail.phtml`
- `templates/adminlte/reservation/module/customerForm.phtml`
- `templates/adminlte/reservation/module/dayDetail.phtml`
- `templates/adminlte/reservation/module/externalPaymentSuccess.phtml`
- `templates/adminlte/reservation/module/holdSuccess.phtml`
- `templates/adminlte/reservation/module/list.phtml`
- `templates/adminlte/reservation/module/listRecent.phtml`
- `templates/adminlte/reservation/module/listTimeSlot.phtml`
- `templates/adminlte/reservation/module/quickEdit.phtml`
- `templates/adminlte/reservation/module/tr.phtml`

**AJAX templates**
- `templates/adminlte/reservation/index.phtml` <= `ANY /reservation`, `ANY /reservation/list`
- `templates/adminlte/reservation/index-v2.phtml` <= `ANY /reservation/detail/{bookingCode}/{idLocation}/{idReservation}`, `ANY /reservation/new`
- `templates/adminlte/reservation/module/activityType.phtml` <= `ANY /reservation/activity-type/{idLocation}`
- `templates/adminlte/reservation/module/calendar.phtml` <= `ANY /reservation/calendar-view/{idLocation}`
- `templates/adminlte/reservation/module/customerDetail.phtml` <= `POST /reservation/action/cancel-refund/{idReservation}`, `POST /reservation/action/cancel/{idReservation}`, `POST /reservation/action/quick-update/{idReservation}`
- `templates/adminlte/reservation/module/customerForm.phtml` <= `ANY /reservation/customer-info-form/{idLocation}`
- `templates/adminlte/reservation/module/dayDetail.phtml` <= `ANY /reservation/day-detail/{idLocation}`
- `templates/adminlte/reservation/module/externalPaymentSuccess.phtml` <= `ANY /reservation/create`
- `templates/adminlte/reservation/module/holdSuccess.phtml` <= `ANY /reservation/create`
- `templates/adminlte/reservation/module/listTimeSlot.phtml` <= `ANY /reservation/time-slot/{idLocation}`
- `templates/adminlte/reservation/module/quickEdit.phtml` <= `POST /reservation/action/quick-edit/{idReservation}`

**JavaScript files**
- `templates/adminlte/reservation/module/quickEdit.phtml`
- `templates/adminlte/reservation/module/tr.phtml`

**customSender chains**
- `templates/adminlte/reservation/index.phtml`: templates/adminlte/reservation/module/quickEdit.phtml -> ANY /reservation -> templates/adminlte/reservation/index.phtml
- `templates/adminlte/reservation/index.phtml`: templates/adminlte/reservation/module/tr.phtml -> ANY /reservation -> templates/adminlte/reservation/index.phtml
- `templates/adminlte/reservation/module/customerDetail.phtml`: templates/adminlte/reservation/module/quickEdit.phtml -> POST /reservation/action/quick-update/{idReservation} -> templates/adminlte/reservation/module/customerDetail.phtml
- `templates/adminlte/reservation/module/quickEdit.phtml`: templates/adminlte/reservation/module/tr.phtml -> POST /reservation/action/quick-edit/{idReservation} -> templates/adminlte/reservation/module/quickEdit.phtml

### risk

**Routes**
- `GET /risk-manager/bank`
- `POST /risk-manager/bank/get/option`
- `POST /risk-manager/bank/status/{idMerchant}/{status}/{bank}`
- `POST /risk-manager/bank/action/preview`
- `GET /risk-manager/cookie-warning`
- `POST /risk-manager/cookie-warning/reload`
- `GET /risk-manager/ethoca/alert`
- `POST /risk-manager/ethoca/alert/reload/{idEthocaAlert}`
- `POST /risk-manager/ethoca/alert/inconsistency/{idEthocaAlert}/resolve`
- `POST /risk-manager/ethoca/alert/list/reload`
- `GET /risk-manager/ethoca/request`
- `GET /ethoca`
- `POST /ethoca/detail/{idEthoca}`
- `POST /ethoca/reload/list`
- `GET /risk-manager/merchant-warning`
- `POST /risk-manager/merchant-warning/detail/{idMerchantWarning}`

**Controllers**
- `App/Controller/Admin/Risk/BankController.php`
- `App/Controller/Admin/Risk/CookieWarningController.php`
- `App/Controller/Admin/Risk/Ethoca/EthocaAlertController.php`
- `App/Controller/Admin/Risk/Ethoca/EthocaRequestController.php`
- `App/Controller/Admin/Risk/Ethoca/EthocaSettingController.php`
- `App/Controller/Admin/Risk/MerchantWarningController.php`

**Managers**
- `App/Manager/Risk/RiskBankManager.php`

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/risk/bank/index.phtml`
- `templates/adminlte/risk/bank/module/action.phtml`
- `templates/adminlte/risk/bank/module/bankStatusAsBtn.phtml`
- `templates/adminlte/risk/bank/module/previewAction.phtml`
- `templates/adminlte/risk/bank/module/renderStatus.phtml`
- `templates/adminlte/risk/cookieWarning/index.phtml`
- `templates/adminlte/risk/cookieWarning/module/list.phtml`
- `templates/adminlte/risk/cookieWarning/module/statusAsBtn.phtml`
- `templates/adminlte/risk/ethoca/alert/index.phtml`
- `templates/adminlte/risk/ethoca/alert/module/action.phtml`
- `templates/adminlte/risk/ethoca/alert/module/actionInconsistency.phtml`
- `templates/adminlte/risk/ethoca/alert/module/detailInconsistency.phtml`
- `templates/adminlte/risk/ethoca/alert/module/detailToVerify.phtml`
- `templates/adminlte/risk/ethoca/alert/module/listAsWidgetInconsistency.phtml`
- `templates/adminlte/risk/ethoca/alert/module/listAsWidgetToVerify.phtml`
- `templates/adminlte/risk/ethoca/alert/module/listInconsistencyResolved.phtml`
- `templates/adminlte/risk/ethoca/alert/module/listVerified.phtml`
- `templates/adminlte/risk/ethoca/request/index.phtml`
- `templates/adminlte/risk/ethoca/request/module/list.phtml`
- `templates/adminlte/risk/ethoca/setting/index.phtml`
- `templates/adminlte/risk/ethoca/setting/module/detail.phtml`
- `templates/adminlte/risk/ethoca/setting/module/list.phtml`
- `templates/adminlte/risk/ethoca/setting/module/new.phtml`
- `templates/adminlte/risk/merchantWarning/index.phtml`
- `templates/adminlte/risk/merchantWarning/module/detail.phtml`

**AJAX templates**
- `templates/adminlte/risk/bank/module/action.phtml` <= `POST /risk-manager/bank/get/option`
- `templates/adminlte/risk/bank/module/bankStatusAsBtn.phtml` <= `POST /risk-manager/bank/status/{idMerchant}/{status}/{bank}`
- `templates/adminlte/risk/bank/module/previewAction.phtml` <= `POST /risk-manager/bank/action/preview`
- `templates/adminlte/risk/bank/module/renderStatus.phtml` <= `POST /risk-manager/bank/get/option`
- `templates/adminlte/risk/cookieWarning/module/list.phtml` <= `POST /risk-manager/cookie-warning/reload`
- `templates/adminlte/risk/ethoca/alert/module/detailToVerify.phtml` <= `POST /risk-manager/ethoca/alert/reload/{idEthocaAlert}`
- `templates/adminlte/risk/ethoca/alert/module/listInconsistencyResolved.phtml` <= `POST /risk-manager/ethoca/alert/inconsistency/{idEthocaAlert}/resolve`
- `templates/adminlte/risk/ethoca/alert/module/listVerified.phtml` <= `POST /risk-manager/ethoca/alert/list/reload`
- `templates/adminlte/risk/ethoca/setting/module/detail.phtml` <= `POST /ethoca/detail/{idEthoca}`
- `templates/adminlte/risk/ethoca/setting/module/list.phtml` <= `POST /ethoca/reload/list`
- `templates/adminlte/risk/merchantWarning/module/detail.phtml` <= `POST /risk-manager/merchant-warning/detail/{idMerchantWarning}`

**JavaScript files**
- `templates/adminlte/risk/bank/index.phtml`
- `templates/adminlte/risk/bank/module/bankStatusAsBtn.phtml`
- `templates/adminlte/risk/bank/module/action.phtml`
- `templates/adminlte/risk/ethoca/alert/module/detailToVerify.phtml`
- `templates/adminlte/risk/ethoca/alert/module/actionInconsistency.phtml`
- `templates/adminlte/risk/ethoca/setting/module/list.phtml`
- `templates/adminlte/risk/merchantWarning/index.phtml`

**customSender chains**
- `templates/adminlte/risk/bank/module/action.phtml`: templates/adminlte/risk/bank/index.phtml -> POST /risk-manager/bank/get/option -> templates/adminlte/risk/bank/module/action.phtml
- `templates/adminlte/risk/bank/module/bankStatusAsBtn.phtml`: templates/adminlte/risk/bank/module/bankStatusAsBtn.phtml -> POST /risk-manager/bank/status/{idMerchant}/{status}/{bank} -> templates/adminlte/risk/bank/module/bankStatusAsBtn.phtml
- `templates/adminlte/risk/bank/module/previewAction.phtml`: templates/adminlte/risk/bank/module/action.phtml -> POST /risk-manager/bank/action/preview -> templates/adminlte/risk/bank/module/previewAction.phtml
- `templates/adminlte/risk/bank/module/renderStatus.phtml`: templates/adminlte/risk/bank/index.phtml -> POST /risk-manager/bank/get/option -> templates/adminlte/risk/bank/module/renderStatus.phtml
- `templates/adminlte/risk/ethoca/alert/module/detailToVerify.phtml`: templates/adminlte/risk/ethoca/alert/module/detailToVerify.phtml -> POST /risk-manager/ethoca/alert/reload/{idEthocaAlert} -> templates/adminlte/risk/ethoca/alert/module/detailToVerify.phtml
- `templates/adminlte/risk/ethoca/alert/module/listInconsistencyResolved.phtml`: templates/adminlte/risk/ethoca/alert/module/actionInconsistency.phtml -> POST /risk-manager/ethoca/alert/inconsistency/{idEthocaAlert}/resolve -> templates/adminlte/risk/ethoca/alert/module/listInconsistencyResolved.phtml
- `templates/adminlte/risk/ethoca/setting/module/detail.phtml`: templates/adminlte/risk/ethoca/setting/module/list.phtml -> POST /ethoca/detail/{idEthoca} -> templates/adminlte/risk/ethoca/setting/module/detail.phtml
- `templates/adminlte/risk/merchantWarning/module/detail.phtml`: templates/adminlte/risk/merchantWarning/index.phtml -> POST /risk-manager/merchant-warning/detail/{idMerchantWarning} -> templates/adminlte/risk/merchantWarning/module/detail.phtml

### sapiensDw

**Routes**
- `GET /sapiens-dw`
- `POST /sapiens-dw/detail/{idSapiensDw}`
- `POST /sapiens-dw/reload/list`

**Controllers**
- `App/Controller/Admin/SapiensDwController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/SapiensDwTemplateRender.php`

**Templates**
- `templates/adminlte/sapiensDw/index.phtml`
- `templates/adminlte/sapiensDw/module/detail.phtml`
- `templates/adminlte/sapiensDw/module/list.phtml`
- `templates/adminlte/sapiensDw/module/new.phtml`

**AJAX templates**
- `templates/adminlte/sapiensDw/module/detail.phtml` <= `POST /sapiens-dw/detail/{idSapiensDw}`
- `templates/adminlte/sapiensDw/module/list.phtml` <= `POST /sapiens-dw/reload/list`

**JavaScript files**
- `templates/adminlte/sapiensDw/module/list.phtml`

**customSender chains**
- `templates/adminlte/sapiensDw/module/detail.phtml`: templates/adminlte/sapiensDw/module/list.phtml -> POST /sapiens-dw/detail/{idSapiensDw} -> templates/adminlte/sapiensDw/module/detail.phtml

### sapiensPulse

**Routes**
- `GET /sapiens-pulse`
- `POST /sapiens-pulse/detail/{idSapiensPulse}`
- `POST /sapiens-pulse/reload/list`

**Controllers**
- `App/Controller/Admin/SapiensPulseController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/SapiensPulseTemplateRender.php`

**Templates**
- `templates/adminlte/sapiensPulse/index.phtml`
- `templates/adminlte/sapiensPulse/module/detail.phtml`
- `templates/adminlte/sapiensPulse/module/list.phtml`
- `templates/adminlte/sapiensPulse/module/new.phtml`

**AJAX templates**
- `templates/adminlte/sapiensPulse/module/detail.phtml` <= `POST /sapiens-pulse/detail/{idSapiensPulse}`
- `templates/adminlte/sapiensPulse/module/list.phtml` <= `POST /sapiens-pulse/reload/list`

**JavaScript files**
- `templates/adminlte/sapiensPulse/module/list.phtml`

**customSender chains**
- `templates/adminlte/sapiensPulse/module/detail.phtml`: templates/adminlte/sapiensPulse/module/list.phtml -> POST /sapiens-pulse/detail/{idSapiensPulse} -> templates/adminlte/sapiensPulse/module/detail.phtml

### sapiensWorkstation

**Routes**
- `GET /sapiens-workstation`
- `POST /sapiens-workstation/detail/{idSapiensWorkstation}`
- `POST /sapiens-workstation/reload/list`

**Controllers**
- `App/Controller/Admin/SapiensWorkstationController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/SapiensWorkstationTemplateRender.php`

**Templates**
- `templates/adminlte/sapiensWorkstation/index.phtml`
- `templates/adminlte/sapiensWorkstation/module/detail.phtml`
- `templates/adminlte/sapiensWorkstation/module/detailRead.phtml`
- `templates/adminlte/sapiensWorkstation/module/list.phtml`
- `templates/adminlte/sapiensWorkstation/module/new.phtml`

**AJAX templates**
- `templates/adminlte/sapiensWorkstation/module/detail.phtml` <= `POST /sapiens-workstation/detail/{idSapiensWorkstation}`
- `templates/adminlte/sapiensWorkstation/module/detailRead.phtml` <= `POST /sapiens-workstation/detail/{idSapiensWorkstation}`
- `templates/adminlte/sapiensWorkstation/module/list.phtml` <= `POST /sapiens-workstation/reload/list`

**JavaScript files**
- `templates/adminlte/sapiensWorkstation/module/list.phtml`

**customSender chains**
- `templates/adminlte/sapiensWorkstation/module/detail.phtml`: templates/adminlte/sapiensWorkstation/module/list.phtml -> POST /sapiens-workstation/detail/{idSapiensWorkstation} -> templates/adminlte/sapiensWorkstation/module/detail.phtml
- `templates/adminlte/sapiensWorkstation/module/detailRead.phtml`: templates/adminlte/sapiensWorkstation/module/list.phtml -> POST /sapiens-workstation/detail/{idSapiensWorkstation} -> templates/adminlte/sapiensWorkstation/module/detailRead.phtml

### seller

**Routes**
- None mapped

**Controllers**
- None mapped

**Managers**
- None mapped

**View renderers**
- `App/View/SellerTemplateRender.php`

**Templates**
- `templates/adminlte/seller/loyaltyCard/action/module/join.phtml`
- `templates/adminlte/seller/loyaltyCard/action/module/redeem.phtml`
- `templates/adminlte/seller/loyaltyCard/action/module/replace.phtml`
- `templates/adminlte/seller/loyaltyCard/action/module/ticket.phtml`
- `templates/adminlte/seller/loyaltyCard/module/boxAction.phtml`
- `templates/adminlte/seller/loyaltyCard/module/boxInfo.phtml`
- `templates/adminlte/seller/loyaltyCard/module/boxTopupSuccess.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### semanticDetector

**Routes**
- `GET /semantic-detector/{type}`
- `POST /semantic-detector/{type}/detail/{idSemanticDetector}`
- `POST /semantic-detector/{type}/reload/list`
- `POST /semantic-detector/{type}/prepare/list-message`
- `POST /semantic-detector/{type}/prepare/list-term`

**Controllers**
- `App/Controller/Admin/SemanticDetector/SemanticDetectorController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/semanticDetector/index.phtml`
- `templates/adminlte/semanticDetector/module/detail.phtml`
- `templates/adminlte/semanticDetector/module/list.phtml`
- `templates/adminlte/semanticDetector/module/new.phtml`
- `templates/adminlte/semanticDetector/module/prepareListMessage.phtml`
- `templates/adminlte/semanticDetector/module/prepareListTerm.phtml`

**AJAX templates**
- `templates/adminlte/semanticDetector/module/detail.phtml` <= `POST /semantic-detector/{type}/detail/{idSemanticDetector}`
- `templates/adminlte/semanticDetector/module/list.phtml` <= `POST /semantic-detector/{type}/reload/list`
- `templates/adminlte/semanticDetector/module/prepareListMessage.phtml` <= `POST /semantic-detector/{type}/prepare/list-message`
- `templates/adminlte/semanticDetector/module/prepareListTerm.phtml` <= `POST /semantic-detector/{type}/prepare/list-term`

**JavaScript files**
- `templates/adminlte/semanticDetector/module/detail.phtml`
- `templates/adminlte/semanticDetector/module/list.phtml`
- `templates/adminlte/semanticDetector/module/new.phtml`

**customSender chains**
- `templates/adminlte/semanticDetector/module/detail.phtml`: templates/adminlte/semanticDetector/module/detail.phtml -> POST /semantic-detector/{type}/detail/{idSemanticDetector} -> templates/adminlte/semanticDetector/module/detail.phtml
- `templates/adminlte/semanticDetector/module/detail.phtml`: templates/adminlte/semanticDetector/module/list.phtml -> POST /semantic-detector/{type}/detail/{idSemanticDetector} -> templates/adminlte/semanticDetector/module/detail.phtml
- `templates/adminlte/semanticDetector/module/detail.phtml`: templates/adminlte/semanticDetector/module/new.phtml -> POST /semantic-detector/{type}/detail/{idSemanticDetector} -> templates/adminlte/semanticDetector/module/detail.phtml
- `templates/adminlte/semanticDetector/module/list.phtml`: templates/adminlte/semanticDetector/module/detail.phtml -> POST /semantic-detector/{type}/reload/list -> templates/adminlte/semanticDetector/module/list.phtml
- `templates/adminlte/semanticDetector/module/list.phtml`: templates/adminlte/semanticDetector/module/list.phtml -> POST /semantic-detector/{type}/reload/list -> templates/adminlte/semanticDetector/module/list.phtml
- `templates/adminlte/semanticDetector/module/list.phtml`: templates/adminlte/semanticDetector/module/new.phtml -> POST /semantic-detector/{type}/reload/list -> templates/adminlte/semanticDetector/module/list.phtml
- `templates/adminlte/semanticDetector/module/prepareListMessage.phtml`: templates/adminlte/semanticDetector/module/detail.phtml -> POST /semantic-detector/{type}/prepare/list-message -> templates/adminlte/semanticDetector/module/prepareListMessage.phtml
- `templates/adminlte/semanticDetector/module/prepareListMessage.phtml`: templates/adminlte/semanticDetector/module/list.phtml -> POST /semantic-detector/{type}/prepare/list-message -> templates/adminlte/semanticDetector/module/prepareListMessage.phtml
- `templates/adminlte/semanticDetector/module/prepareListMessage.phtml`: templates/adminlte/semanticDetector/module/new.phtml -> POST /semantic-detector/{type}/prepare/list-message -> templates/adminlte/semanticDetector/module/prepareListMessage.phtml
- `templates/adminlte/semanticDetector/module/prepareListTerm.phtml`: templates/adminlte/semanticDetector/module/detail.phtml -> POST /semantic-detector/{type}/prepare/list-term -> templates/adminlte/semanticDetector/module/prepareListTerm.phtml
- `templates/adminlte/semanticDetector/module/prepareListTerm.phtml`: templates/adminlte/semanticDetector/module/list.phtml -> POST /semantic-detector/{type}/prepare/list-term -> templates/adminlte/semanticDetector/module/prepareListTerm.phtml
- `templates/adminlte/semanticDetector/module/prepareListTerm.phtml`: templates/adminlte/semanticDetector/module/new.phtml -> POST /semantic-detector/{type}/prepare/list-term -> templates/adminlte/semanticDetector/module/prepareListTerm.phtml

### sii

**Routes**
- `GET /sii`
- `GET /sii/log`
- `POST /sii/detail/{idSii}`
- `GET /sii/reconciliation`
- `GET /sii/schedule`
- `POST /sii/schedule/detail/{idSiiSchedule}`
- `POST /sii/schedule/reload[/{siiScheduleStatus}]`
- `POST /sii/schedule/tab/{siiScheduleStatus}`
- `POST /sii/schedule/action/prepare`

**Controllers**
- `App/Controller/Admin/Sii/SiiController.php`
- `App/Controller/Admin/Sii/SiiLogController.php`
- `App/Controller/Admin/Sii/SiiOdooReconciliationController.php`
- `App/Controller/Admin/Sii/SiiScheduleController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/SiiTemplateRender.php`

**Other renderers and parent relationships**
- `templates/adminlte/sii/reconciliation/index.phtml`

**Templates**
- `templates/adminlte/sii/list.phtml`
- `templates/adminlte/sii/log/index.phtml`
- `templates/adminlte/sii/log/module/list.phtml`
- `templates/adminlte/sii/module/detail.phtml`
- `templates/adminlte/sii/module/list.phtml`
- `templates/adminlte/sii/reconciliation/index.phtml`
- `templates/adminlte/sii/reconciliation/module/listRun.phtml`
- `templates/adminlte/sii/schedule/index.phtml`
- `templates/adminlte/sii/schedule/module/detail.phtml`
- `templates/adminlte/sii/schedule/module/list.phtml`
- `templates/adminlte/sii/schedule/module/prepareAction.phtml`

**AJAX templates**
- `templates/adminlte/sii/module/detail.phtml` <= `POST /sii/detail/{idSii}`
- `templates/adminlte/sii/schedule/module/detail.phtml` <= `POST /sii/schedule/detail/{idSiiSchedule}`
- `templates/adminlte/sii/schedule/module/list.phtml` <= `POST /sii/schedule/reload[/{siiScheduleStatus}]`, `POST /sii/schedule/tab/{siiScheduleStatus}`
- `templates/adminlte/sii/schedule/module/prepareAction.phtml` <= `POST /sii/schedule/action/prepare`

**JavaScript files**
- `templates/adminlte/sii/log/module/list.phtml`
- `templates/adminlte/sii/module/list.phtml`
- `templates/adminlte/sii/schedule/module/detail.phtml`
- `templates/adminlte/sii/schedule/module/list.phtml`

**customSender chains**
- `templates/adminlte/sii/module/detail.phtml`: templates/adminlte/sii/log/module/list.phtml -> POST /sii/detail/{idSii} -> templates/adminlte/sii/module/detail.phtml
- `templates/adminlte/sii/module/detail.phtml`: templates/adminlte/sii/module/list.phtml -> POST /sii/detail/{idSii} -> templates/adminlte/sii/module/detail.phtml
- `templates/adminlte/sii/module/detail.phtml`: templates/adminlte/sii/schedule/module/detail.phtml -> POST /sii/detail/{idSii} -> templates/adminlte/sii/module/detail.phtml
- `templates/adminlte/sii/schedule/module/detail.phtml`: templates/adminlte/sii/schedule/module/list.phtml -> POST /sii/schedule/detail/{idSiiSchedule} -> templates/adminlte/sii/schedule/module/detail.phtml
- `templates/adminlte/sii/schedule/module/prepareAction.phtml`: templates/adminlte/sii/schedule/module/list.phtml -> POST /sii/schedule/action/prepare -> templates/adminlte/sii/schedule/module/prepareAction.phtml

### subscription

**Routes**
- `ANY /subscription/list`
- `POST /customer/subscription/prepare/{idUser}/{token}`
- `POST /customer/subscription/prepare/test/{idUser}/{token}`

**Controllers**
- `App/Controller/Admin/SubscriptionController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/subscription/list.phtml`
- `templates/adminlte/subscription/module/listSubscription.phtml`
- `templates/adminlte/subscription/module/listSubscriptionMv.phtml`
- `templates/adminlte/subscription/module/prepareCustomerSubscription.phtml`
- `templates/adminlte/subscription/module/prepareCustomerSubscriptionTest.phtml`

**AJAX templates**
- `templates/adminlte/subscription/list.phtml` <= `ANY /subscription/list`
- `templates/adminlte/subscription/module/listSubscriptionMv.phtml` <= `ANY /subscription/list`
- `templates/adminlte/subscription/module/prepareCustomerSubscription.phtml` <= `POST /customer/subscription/prepare/{idUser}/{token}`
- `templates/adminlte/subscription/module/prepareCustomerSubscriptionTest.phtml` <= `POST /customer/subscription/prepare/test/{idUser}/{token}`

**JavaScript files**
- `templates/adminlte/customer/module/form/subscription.phtml`

**customSender chains**
- `templates/adminlte/subscription/module/prepareCustomerSubscription.phtml`: templates/adminlte/customer/module/form/subscription.phtml -> POST /customer/subscription/prepare/{idUser}/{token} -> templates/adminlte/subscription/module/prepareCustomerSubscription.phtml
- `templates/adminlte/subscription/module/prepareCustomerSubscriptionTest.phtml`: templates/adminlte/customer/module/form/subscription.phtml -> POST /customer/subscription/prepare/test/{idUser}/{token} -> templates/adminlte/subscription/module/prepareCustomerSubscriptionTest.phtml

### sys

**Routes**
- `GET /sys/log`
- `POST /sys/log/reload`

**Controllers**
- `App/Controller/Admin/SysController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/sys/log/index.phtml`
- `templates/adminlte/sys/module/listLog.phtml`

**AJAX templates**
- `templates/adminlte/sys/module/listLog.phtml` <= `POST /sys/log/reload`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### tag

**Routes**
- `POST /article/update/{idArticle}`

**Controllers**
- `App/Controller/Admin/ArticleController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/tag/module/listOption.phtml`

**AJAX templates**
- `templates/adminlte/tag/module/listOption.phtml` <= `POST /article/update/{idArticle}`

**JavaScript files**
- `templates/adminlte/article/detail.phtml`

**customSender chains**
- `templates/adminlte/tag/module/listOption.phtml`: templates/adminlte/article/detail.phtml -> POST /article/update/{idArticle} -> templates/adminlte/tag/module/listOption.phtml

### translation

**Routes**
- `GET /translation/automatic`
- `POST /translation/automatic/reload/selectLang/{token}/{theme}`
- `GET /translation/detail/{idTranslationValue}/{theme}`
- `GET /translation/detail/{idTranslationValue}/{theme}/{lang}`
- `GET /translation/group`
- `POST /translation/group/detail/{idTranslationGroup}`
- `POST /translation/group/reload`
- `GET /translation/import-export`
- `GET /translation/list`
- `POST /translation/render/new`
- `POST /translation/automatic/preview`
- `POST /translation/automatic/run`
- `POST /translation/render/list`
- `GET /translation/new`

**Controllers**
- `App/Controller/Admin/AutomaticTranslationController.php`
- `App/Controller/Admin/TranslationController.php`
- `App/Controller/Admin/TranslationGroupController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`
- `App/View/TranslationTemplateRenderer.php`

**Templates**
- `templates/adminlte/translation/automatic/index.phtml`
- `templates/adminlte/translation/automatic/module/selectFromToLang.phtml`
- `templates/adminlte/translation/detail.phtml`
- `templates/adminlte/translation/group/index.phtml`
- `templates/adminlte/translation/group/module/detail.phtml`
- `templates/adminlte/translation/group/module/list.phtml`
- `templates/adminlte/translation/group/module/new.phtml`
- `templates/adminlte/translation/group/module/option.phtml`
- `templates/adminlte/translation/importExport.phtml`
- `templates/adminlte/translation/list.phtml`
- `templates/adminlte/translation/module/convert.phtml`
- `templates/adminlte/translation/module/export.phtml`
- `templates/adminlte/translation/module/importToDb.phtml`
- `templates/adminlte/translation/module/importToRedisFromDb.phtml`
- `templates/adminlte/translation/module/interactive.phtml`
- `templates/adminlte/translation/module/listNewTranslation.phtml`
- `templates/adminlte/translation/module/listTranslation.phtml`
- `templates/adminlte/translation/module/selectLangShowTranslation.phtml`
- `templates/adminlte/translation/module/utilityLog.phtml`
- `templates/adminlte/translation/new.phtml`

**AJAX templates**
- `templates/adminlte/translation/automatic/module/selectFromToLang.phtml` <= `POST /translation/automatic/reload/selectLang/{token}/{theme}`
- `templates/adminlte/translation/group/module/detail.phtml` <= `POST /translation/group/detail/{idTranslationGroup}`
- `templates/adminlte/translation/group/module/list.phtml` <= `POST /translation/group/reload`
- `templates/adminlte/translation/module/listNewTranslation.phtml` <= `POST /translation/render/new`
- `templates/adminlte/translation/module/listTranslation.phtml` <= `POST /translation/automatic/preview`, `POST /translation/automatic/run`, `POST /translation/render/list`

**JavaScript files**
- `templates/adminlte/translation/automatic/index.phtml`
- `templates/adminlte/translation/group/module/list.phtml`
- `templates/adminlte/translation/module/listTranslation.phtml`

**customSender chains**
- `templates/adminlte/translation/automatic/module/selectFromToLang.phtml`: templates/adminlte/translation/automatic/index.phtml -> POST /translation/automatic/reload/selectLang/{token}/{theme} -> templates/adminlte/translation/automatic/module/selectFromToLang.phtml
- `templates/adminlte/translation/group/module/detail.phtml`: templates/adminlte/translation/group/module/list.phtml -> POST /translation/group/detail/{idTranslationGroup} -> templates/adminlte/translation/group/module/detail.phtml
- `templates/adminlte/translation/module/listTranslation.phtml`: templates/adminlte/translation/automatic/index.phtml -> POST /translation/automatic/preview -> templates/adminlte/translation/module/listTranslation.phtml
- `templates/adminlte/translation/module/listTranslation.phtml`: templates/adminlte/translation/module/listTranslation.phtml -> POST /translation/automatic/run -> templates/adminlte/translation/module/listTranslation.phtml

### user

**Routes**
- `GET /user/detail/{idUser}`
- `GET /user/list`
- `POST /user/reload`

**Controllers**
- `App/Controller/Admin/UserController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/user/detail.phtml`
- `templates/adminlte/user/index.phtml`
- `templates/adminlte/user/module/list.phtml`
- `templates/adminlte/user/module/new.phtml`

**AJAX templates**
- `templates/adminlte/user/module/list.phtml` <= `POST /user/reload`

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### vatRate

**Routes**
- `GET /vat-rate`
- `POST /vat-rate/create`
- `POST /vat-rate/update/{idVatRate}`
- `POST /vat-rate/detail/{idVatRate}`
- `POST /vat-rate/reload`
- `POST /vat-rate/get/odoo-section/{idVatRate}/{country}`

**Controllers**
- `App/Controller/Admin/VatRateController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/VatRateTemplateRender.php`

**Templates**
- `templates/adminlte/vatRate/index.phtml`
- `templates/adminlte/vatRate/module/detail.phtml`
- `templates/adminlte/vatRate/module/list.phtml`
- `templates/adminlte/vatRate/module/listOption.phtml`
- `templates/adminlte/vatRate/module/new.phtml`
- `templates/adminlte/vatRate/module/odooSection.phtml`
- `templates/adminlte/vatRate/module/row.phtml`

**AJAX templates**
- `templates/adminlte/vatRate/module/list.phtml` <= `POST /vat-rate/create`
- `templates/adminlte/vatRate/module/row.phtml` <= `POST /vat-rate/update/{idVatRate}`
- `templates/adminlte/vatRate/module/detail.phtml` <= `POST /vat-rate/detail/{idVatRate}`
- `templates/adminlte/vatRate/module/list.phtml` <= `POST /vat-rate/reload`
- `templates/adminlte/vatRate/module/odooSection.phtml` <= `POST /vat-rate/get/odoo-section/{idVatRate}/{country}`

**JavaScript files**
- None mapped after Tabler/HTMX migration

**customSender chains**
- None; migrated to HTMX:
- `templates/adminlte/vatRate/module/detail.phtml`: templates/adminlte/vatRate/module/list.phtml -> `hx-post /vat-rate/detail/{idVatRate}` -> templates/adminlte/vatRate/module/detail.phtml
- `templates/adminlte/vatRate/module/odooSection.phtml`: templates/adminlte/vatRate/module/detail.phtml -> `hx-post /vat-rate/get/odoo-section/{idVatRate}/{country}` -> templates/adminlte/vatRate/module/odooSection.phtml

### vendus

**Routes**
- `GET /invoice/vendus/list`
- `POST /invoice/vendus/detail/{idVendusInvoice}`
- `POST /invoice/vendus/reload`

**Controllers**
- `App/Controller/Admin/VendusInvoiceController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/VendusInvoiceTemplateRender.php`

**Templates**
- `templates/adminlte/vendus/invoice/list.phtml`
- `templates/adminlte/vendus/invoice/module/detail.phtml`
- `templates/adminlte/vendus/invoice/module/list.phtml`

**AJAX templates**
- `templates/adminlte/vendus/invoice/module/detail.phtml` <= `POST /invoice/vendus/detail/{idVendusInvoice}`
- `templates/adminlte/vendus/invoice/module/list.phtml` <= `POST /invoice/vendus/reload`

**JavaScript files**
- `templates/adminlte/vendus/invoice/module/detail.phtml`
- `templates/adminlte/vendus/invoice/module/list.phtml`

**customSender chains**
- `templates/adminlte/vendus/invoice/module/detail.phtml`: templates/adminlte/vendus/invoice/module/detail.phtml -> POST /invoice/vendus/detail/{idVendusInvoice} -> templates/adminlte/vendus/invoice/module/detail.phtml
- `templates/adminlte/vendus/invoice/module/detail.phtml`: templates/adminlte/vendus/invoice/module/list.phtml -> POST /invoice/vendus/detail/{idVendusInvoice} -> templates/adminlte/vendus/invoice/module/detail.phtml

### voicemail

**Routes**
- `GET /voicemail/detail/{idVoicemail}`
- `GET /voicemail`

**Controllers**
- `App/Controller/Admin/VoicemailController.php`

**Managers**
- `App/Manager/VoicemailManager.php`

**View renderers**
- None mapped

**Templates**
- `templates/adminlte/voicemail/detail.phtml`
- `templates/adminlte/voicemail/index.phtml`
- `templates/adminlte/voicemail/module/list.phtml`
- `templates/adminlte/voicemail/module/renderOneVoicemail.phtml`
- `templates/adminlte/voicemail/module/statusAsBtn.phtml`
- `templates/adminlte/voicemail/module/voicemailBox.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### voucher

**Routes**
- `GET /voucher/bulk`
- `POST /voucher/bulk/detail/{idVoucherBulkGeneration}`
- `POST /voucher/bulk/reload`

**Controllers**
- `App/Controller/Admin/Voucher/VoucherBulkController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/VoucherBulkTemplateRender.php`

**Templates**
- `templates/adminlte/voucher/voucherBulk/index.phtml`
- `templates/adminlte/voucher/voucherBulk/module/detail.phtml`
- `templates/adminlte/voucher/voucherBulk/module/list.phtml`
- `templates/adminlte/voucher/voucherBulk/module/new.phtml`

**AJAX templates**
- `templates/adminlte/voucher/voucherBulk/module/detail.phtml` <= `POST /voucher/bulk/detail/{idVoucherBulkGeneration}`
- `templates/adminlte/voucher/voucherBulk/module/list.phtml` <= `POST /voucher/bulk/reload`

**JavaScript files**
- `templates/adminlte/voucher/voucherBulk/module/list.phtml`

**customSender chains**
- `templates/adminlte/voucher/voucherBulk/module/detail.phtml`: templates/adminlte/voucher/voucherBulk/module/list.phtml -> POST /voucher/bulk/detail/{idVoucherBulkGeneration} -> templates/adminlte/voucher/voucherBulk/module/detail.phtml

### wallet

**Routes**
- None mapped

**Controllers**
- None mapped

**Managers**
- None mapped

**View renderers**
- `App/View/InnerTemplateRender.php`

**Templates**
- `templates/adminlte/wallet/module/listWallet.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### warehouse

**Routes**
- `GET /warehouse/detail/{idWarehouse}`
- `GET /warehouse/list`
- `GET /warehouse/new`

**Controllers**
- `App/Controller/Admin/WarehouseController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/WarehouseTemplateRender.php`

**Templates**
- `templates/adminlte/warehouse/detail.phtml`
- `templates/adminlte/warehouse/list.phtml`
- `templates/adminlte/warehouse/module/detail.phtml`
- `templates/adminlte/warehouse/module/list.phtml`
- `templates/adminlte/warehouse/module/new.phtml`
- `templates/adminlte/warehouse/new.phtml`

**AJAX templates**
- None mapped

**JavaScript files**
- None mapped

**customSender chains**
- None mapped

### workstationPosition

**Routes**
- `GET /workstation-position`
- `POST /workstation-position/detail/{idWorkstationPosition}`
- `POST /workstation-position/reload/list`

**Controllers**
- `App/Controller/Admin/WorkstationPositionController.php`

**Managers**
- None mapped

**View renderers**
- `App/View/WorkstationPositionTemplateRender.php`

**Templates**
- `templates/adminlte/workstationPosition/index.phtml`
- `templates/adminlte/workstationPosition/module/detail.phtml`
- `templates/adminlte/workstationPosition/module/list.phtml`
- `templates/adminlte/workstationPosition/module/new.phtml`

**AJAX templates**
- `templates/adminlte/workstationPosition/module/detail.phtml` <= `POST /workstation-position/detail/{idWorkstationPosition}`
- `templates/adminlte/workstationPosition/module/list.phtml` <= `POST /workstation-position/reload/list`

**JavaScript files**
- `templates/adminlte/workstationPosition/module/list.phtml`

**customSender chains**
- `templates/adminlte/workstationPosition/module/detail.phtml`: templates/adminlte/workstationPosition/module/list.phtml -> POST /workstation-position/detail/{idWorkstationPosition} -> templates/adminlte/workstationPosition/module/detail.phtml
