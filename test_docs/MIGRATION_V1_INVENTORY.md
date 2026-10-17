# v1 → v2 Migration Inventory (verified 2026-07-05)

Campaign tracking doc for the remaining AdminLTE-2 (v1) admin pages. Verified
against actual controller render calls — do NOT trust older docs/memory; a lot
was migrated between sessions. Check a box only when EVERY feature of the v1
page exists in v2 (porting is not improving; nothing gets lost).

**Excluded on purpose:** Glass/* (domain will be removed), Analysis/v2/*
(React shells — React stays).

**Method:** v1 = `ControllerHelper::renderPage(...)` or `TP::p('include/header')`
trio. v2 = `TP::p('v2/include/header')` trio + list-page playbook (CLAUDE.md).

## Mixed controllers (part v2, part v1 — finish these carefully)

- [ ] **MailboxController** — `detail()` → mailbox/detail, `sent()`, `trash()` (index already v2). Threaded ticket detail, composer, iframe email render, bulk checkboxes, inline status/priority/assign. **M**
- [ ] **Loyalty/LoyaltyCardController** — `renderDetail()` → loyalty/loyaltyCard/detail (index already v2). Dense: balances (credit/bonus/courtesy/ticket/time), tier + status selects, transaction list, reset form (6 fields), assign-user modal (`resetLoyaltyCard`, `assignUserAdmin` AJAX). **S but dense**

## Tier 1 — Loyalty
- [ ] Loyalty/LoyaltyCardTransactionController — `renderIndex()` read-only transaction list. **S**
- [ ] Loyalty/LoyaltyCardContextController — `renderIndex()` list + modal CRUD + delete. **S**

## Tier 2 — Device fleet (highest operational load)
- [x] PulseBoxController — `index()` list + detail modal, location/version selects, hardware-config JSON. **S** (registration flow `/action/pulse-box/*` + `PulseBoxGameDefaultController` intentionally left v1 — separate pages)
- [x] PaymentTerminal/PaymentTerminalController — device list + create/edit modals + config-preview modal + activation page. **All fleet-critical logic preserved verbatim**: GL multi-select validation (`validateGameLocationsForLocation`/`enforceNoAttendedInMultiSelection`/`releaseGlFromOtherPt`), kiosk-vs-game assignment, per-GL selector colours+arrow order, dual-sync on location change, `checkAndSyncPaymentTerminal`. v2 interactivity in `_ptFormScript.phtml` (`window.ptPage`): delegated GL change → attended-validate (revert on fail) → selector-preview fetch, arrow swap/reorder, stacked config-preview modal, `#row-N` deep-link. Location→GL cascade via htmx. Device/API side (handshake/provision/transaction sync) untouched.
- [x] PaymentTerminal/PaymentTerminalConfigController — 4 config levels (owner / operational-mode / game / game-location) rebuilt on htmx query-param cascades (`module/_cascadeSelect`) + ONE generalized `v2/paymentTerminal/config/_configForm.phtml`. Non-image fields are plain (empty = inherit — controller stores only non-empty). Image fields use the new **three-state override** (inherit `__sapiens__` / app-default `__default_app__` / custom): `helper/_imageOverride.phtml` wraps the part-1 image picker; `window.ptImagePicker.setMode` writes the sentinel/id into the picker's hidden input. Reuses part-2 `_affectedDevice` + the shared `/image/upload` + `/image-library/list-option` endpoints (untouched). Per-level sync preserved (`checkAndSyncByOwner/ByOperationalMode/ByGame/ByGameLocation`). Detail/list routes flipped POST→GET fragments; legacy `/config/{action}/{idAction}` update/detail routes + `updateLegacy`/`renderDetailLegacy` dropped (dead). Added `pt_config.image.*` + `pt_config.mode.*` translations.
- [x] PaymentTerminal/PaymentTerminalImageController — image library: owner-cascade gallery + fetch-based upload (Cloudflare Images + local fallback preserved verbatim) + delete, all page-local v2 JS (`window.ptImageLibraryPage`). **`getListOption` (`/image-library/list-option/{owner}`) left UNTOUCHED — the still-v1 skin/config image picker (mainHelper.js) depends on it.**
- [x] PaymentTerminal/SkinVersionController — owner-cascade list + create modal (name) + edit modal (rich `_visualFields`: skin/orientation/custom-image/durations + ~14 colour overrides as text+picker so empty = inherit) + affected-devices. Introduced the reusable **v2 image picker** (`InnerTemplateRender::renderPaymentTerminalImagePicker[Script]`, `window.ptImagePicker`) that replaces the mainHelper `ptImage*` fns — upload → `/image/upload`, pick → `/image-library/list-option/{owner}` (both unchanged v1 endpoints). Colours preserved verbatim.
- [x] Kiosk/KioskController — device list + create/edit modals + config-preview modal (GET htmx `<pre>`). The **activation page** `/action/kiosk/{serialNumber}` also migrated (shares the detail form via `$isActivation`; `source=activation` update swaps `#kioskActivationBox` with a success card via `applyListReplace`). DeviceConfigSyncManager sync preserved; model status/type → Tabler badges.
- [x] Kiosk/KioskConfigController — 4-tier cascade (owner/org/location/kiosk) rebuilt on htmx query-param cascades + ONE generalized `v2/kiosk/config/_configForm.phtml` (reuses the Alpine `_overrideField` + `_affectedDevice`). Location tab (`renderTabLocation`/`updateLocationV2`) repointed to the same form. **Deferred** (data-safe — `KioskConfig::setDetail` merges, so stored values are preserved): the owner-only per-language idle-hero editor + per-field colour overrides (colours come from the skin version by design).
- [x] Kiosk/KioskSkinVersionController — owner-cascade list + create/edit modals with native colour pickers (13 `LIST_COLOR` keys over a base skin); create/update re-render the owner list via `applyListReplace`.
- [ ] Pda/PdaController — `renderList/renderNew/renderDetail/renderNewCode` (QR registration flow). **M**
- [x] SapiensWorkstationController — list + create modal (**.exe file upload** via `FileManager::uploadSapiensWorkstation` reading `$_FILES['fileSource']`, works through list.js FormData) + edit modal (canAdminH editable / canAdmin read-only split preserved) + GET symlink download. Activation/support rules + transaction preserved.
- [x] SapiensPulseController — list + create modal (file upload via `uploadSapiensPulse`, rejects .exe) + edit modal. Same version-manager pattern as SapiensWorkstation (activation/support rules + transaction). renderDetail/create/update require canAdminH.
- [x] SapiensDwController — same as pulse but upload requires **.dpk** (`uploadSapiensDw`, stores file MD5); detail shows the MD5 (read-only). renderDetail/create/update require canAdminH.

## Tier 3-4 — Finder & Profile
- [ ] FinderController — `index()` global search, multi-entity results (loyalty cards / customers / wallets / payments), "open first" auto-redirect. **S**
- [x] ProfileController — `index()` tabbed: info + avatar upload, settings (language/telegram), password, PIN. **S** (personal-cluster tab wired via htmx to /profile/cluster; TelegramController's 3 methods folded to v2 JSON; avatar upload now goes through Cloudflare R2 via `MediaUploadManager::uploadAvatar`, stored as `extraDetail.avatar.url` — `User::getAvatarSrc()` prefers it, legacy local avatars fall back to the old `/assets/storing` path)

## Tier 5 — Communication
- [ ] VoicemailController — `index()` (tabs open/missing/completed) + `renderDetail()` thread. **S**
- [ ] Notification/NotificationController — `renderIndex()` list, read toggles. **S**

## Tier 6 — Templates & email
- [ ] EmailTemplateController — `renderListTemplate()` + `renderCustomTemplate()` (system list read-only, custom CRUD). **S**
- [ ] HtmlTemplateController — new/detail/list/defaultList — TinyMCE editor pages. **M**
- [ ] EmailImporterController — `renderIndex()` + `renderDetail()` (IMAP config, sync status). **S**

## Tier 7 — Payments
- [ ] PaymentController — `renderListTransaction()` (refund modal, invoice buttons) + `renderListDispute()`. **S**
- [ ] PaymentLinkController — `renderIndex()`. **S**
- [ ] PayoutController — `renderIndex()` status filters + CSV export. **S**
- [ ] SubscriptionController — `renderIndex()`. **S**

## Tier 8 — Translation admin
- [x] TranslationController — **fully migrated**. list/new (theme+lang selector → htmx Show → grid / create form), detail (edit-across-langs + history + add-missing-lang, field names identical so `updateAndStoreHistory` untouched), create/update → JSON. Theme→lang cascade is client-side from an embedded map. Grid: group filter + search + sortable + WIP highlight. **Translation values use TinyMCE 7** (`.translation-richtext`, light config via `_richtextAssets`) replacing v1 Summernote. `activateInteractive` → JSON. **import-export** (SYS): downloads (export ×2 / convert) are native form POSTs (target=_blank, `downloadStringAsFile` streams the file; error/info → plain message page); imports → JSON `data-list-submit`; utility-log → htmx GET fragment; shared theme→lang cascade via `data-lang-target`.
- [x] TranslationGroupController — list + create/edit modals (list-page playbook, `data-list-edit-url`/`data-list-append-table`, JSON `{id,row}`). Dropped dead `/render/new` + `/reload` routes.
- [x] AutomaticTranslationController — theme → from(live)/to(draft) lang pickers → **Preview** (AI translate, no save) → **Run** (translate + persist), both rendering the shared `_grid` (extended with an optional title + Run footer). `select-lang` GET cascade; preview/run POST fragments.

## Tier 9 — Marketing
- [ ] Marketing/MarketingCampaignController — index/detail/logDetail. **M**
- [x] MarketingAdsController — index (list + create modal) + rich detail page (settings form, stats datagrid, htmx notes, redditivity table). No image upload exists (inventory note was wrong).
- [x] AdsAccountController — `renderIndex()` list + create/edit modals (discount-style). **S**
- [x] MarketingTrackerController — `renderIndex()` stats list. **S**

## Tier 10 — System
- [x] SysController — `/sys/log` paginated viewer (id/type/message/action/date, search + sort). v2 server pagination via `renderServerPaginationV2` + same-URL `HX-Request` fragment (dropped `/log/reload`). canAdminH gated.
- [x] DebugLogController — `/debug-log` list (scope/level/date filters, level badges, truncated detail) + enable/disable **toggle** (htmx POST → toggle fragment). Server pagination preserving filters via `extraParam`; same-URL `HX-Request` fragment (dropped `/reload`). isSys gated. (Added `common.system.sys_log` + the shared pagination's `server_pagination`/`rows` keys.)

## Tier 11 — Domain peers & misc (all S)
- [ ] DomainController (list + Telegram/WhatsApp webhook buttons)
- [ ] OrganizationController — `renderNew()` form
- [ ] MerchantController · [ ] NoteController · [x] Holiday/HolidayController (standalone /holiday page: list grouped by country server-side — replaces v1 DataTables raw-group; country→location cascade on create; create/update re-render the grouped tbody via `applyListReplace`. **Deferred**: the per-location holiday-days widget `holiday/module/location/*` — orphaned in v2, belongs to the location page's future holiday tab; its old routes `create/{idLocation}`, `detail/{inLocation}`, `reload/list[/{idLocation}]` were dropped, reachable by no live page)
- [ ] FaqController — `renderDetail()` (TinyMCE + translation preview)
- [x] WorkstationPositionController · [x] Planet/PlanetLocationController
- [x] Sii/SiiController · [x] Sii/SiiLogController · [x] Sii/SiiScheduleController · [x] Sii/SiiOdooReconciliationController
- [x] Odoo/OdooJournalEntryController (v2 rebuild: server-side filter bar status+type+location+date, filter-preserving pagination, htmx fragment; broken tabs + dead /set-posted removed)
- [ ] Risk: BankController · CookieWarningController · MerchantWarningController · Ethoca{Alert,Request,Setting}Controller
- [x] QrCode/QrCodeBulkController — list + create modal + detail modal (mirrors VoucherBulk: `data-list-edit-url` rows, JSON `{status,redirect}` create, `{status,id,row}` update). activityCode→groupCode cascade is **client-side from an embedded map** (correct string codes, no TomSelect/htmx round-trip); conditional NFC-domain field (S+N). CSV downloads (simple + nfc/print full) kept as GET links; download errors → alert fragment. Added `QrCodeBulk::renderStatus()` Tabler badge; `/new` folded into the modal (route + sidebar link dropped). Create transaction (sequence get/create, range/capacity, bulk) preserved verbatim.
- [x] QrCode/QrCodeNfcController — NFC code list (status badges, search/sort) → **detail modal** (`data-list-edit-url`) with location→game-location htmx cascade + status select driving reactivate/block/unassign via `update` (verbatim). Assign card (available codes server-rendered + location→GL cascade). Every mutation (assign/update/unassign/block/reactivate) returns the `{status,listSelector,listHtml}` applyListReplace envelope to refresh the list; history is a GET fragment in a stacked modal. Dropped `/reload` + `/get/available-codes`; `detail`/`history`/`game-location` flipped to GET.
- [ ] NfcPayment/NfcPaymentAdminController · [x] Voucher/VoucherBulkController
- [x] Discount/DiscountButtonController · [x] Device/DeviceCoolcode (index + detail)
- [ ] SemanticDetector/SemanticDetectorController · [x] Pos/PosTerminalDeviceController

## Tier 12 — Analysis v1 dashboards: REMOVED 2026-07-05 (not migrated)
All reporting lives in the React app (Highcharts). Deleted: Ytd, YtdChargeback,
Individual, IndividualRange, FollowUp, Theme controllers + their routes +
templates/adminlte/analysis/{ytd,ytdChargeback,individual,individualRange,followup,theme}.
Kept (still used by the v1 dashboard + React shells): AnalysisTemplateRender,
templates/adminlte/analysis/{module,highcharts,v2}.

## Done (verified fully v2 — do not re-check)
Game domain (GameController, GameLocationController, GamePrice, **GameAcceptorController + GameAcceptorLocationController migrated 2026-07-05**), Monitoring, Customer, User, Article, FileUpload, Location, Period, CronJobStatus, FiscalYear, VatRate, VendusInvoice, Warehouse, Address, Documentation, Telegram, Login/Register, CardGenerator, DeviceMonitoring, Trace, Floor, LocationTable, Mailbox index, LoyaltyCard index.

## Tier 13 — Dashboard (`/`): permission-widget rebuild 2026-07-18
Replaced the v1 role/capability/permission `if/else` fork (dashboard / dashboardLimited / dashboardItSupport) with a **single permission-widget model**: the dashboard is the union of widgets the user is allowed to see. `App/Dashboard/`: `DashboardContext` (faithful one-time extraction of the v1 counter wiring — currency/merchant/country/date filter + PaymentLocation/Item/Nayax/LoyaltyCard counters), `DashboardWidget` (gate callable + partial + grid size), `DashboardRegistry` (`visible()` = filter `all()` by gate). Controller is a thin trio render; filter bar (merchant/currency/`locationCountry`/date, one combined GET form, native date → `fromInputDateToServer`) → `backOfficeHeader`. Widgets under `templates/adminlte/v2/home/widget/`: `_income` (canAdminH — income/cash/card today + 7-day trend), `_vat` (VAT_SAVING perm), `_collectionShortcut` (GAME_ACCEPTOR_COUNTER perm), `_serviceHealth` (isItSupport — read-only service-card table, click-to-detail rows). New widget = one registry line + one partial via `InnerTemplateRender::renderPartial`. **Full v1 dashboard ported** — added `_paymentItems` (canAdminH — loyalty/activity/product/reservation, today + month + 7-day trend), `_recentPayments` (canAdminH — `PaymentLocation::getListLast()`), `_absTracker` (canAdminH — `AbsTracker::getListLastAbsTracker(counterOptionWDomain)`; v1's jQuery async-popup row has no v2 equiv, so rows show data + keep the two real navigations: "View all" → `/abs-tracker` and the user cell → customer detail), `_salesComparison` (SALES_COMPARISON_DASHBOARD — 3 period boxes → `/analysis/v2/sales-comparison`, own try/catch like v1). `_income` extended to income/cash/card/**nayax**, today + month. **`loyaltyCardTransactionCounter` deliberately not ported** — it's loaded but never rendered in v1 `dashboard.phtml` (porting isn't improving). Note: VAT/salesComparison now gate on their own permission alone (v1 nested VAT inside the canAdminH template) — the intended permission-widget semantics.

## Tier 14 — Notification rebuild Phase 1 (live v2 surface) 2026-07-18
Foundation kept (it's sound): `Notification` (event: level/area/purpose/status) + `NotificationUser` (per-recipient read state) two-table fan-out; pluggable `Medium` classes (Email/Telegram/BrowserToast); `BrowserToastMedium` already pushes over daemon-core. **Phase 1 = put a live inbox on every v2 page + migrate `/notification`:**
- **Header bell** (`v2/include/header.phtml`) — Tabler dropdown, seeded server-side from `getLastNotificationUserDTO()` into `window.__notificationSeed`, backed by Alpine store `notification` (`realtime/notificationStore.js`, mirrors `coreStatusStore.js`: seed on `alpine:init`, then `daemon:notification` events prepend + bump count). The v2 header previously had **no bell at all** — migrated pages only got ephemeral toasts.
- **`/notification` page** migrated to v2: filter bar (level/area/status/search, plain-JS `window.notificationPage`), Tabler tabs (to-read + htmx-lazy history via GET `/history/load`), collapsible per-notification cards (`module/_row`), actions (`read`/`acknowledge`) flipped from `ReturnHandlerBuilder` eval to `{status:'success'}` JSON — on success the card removes + decrements the bell store.
- Added `Notification::getGenericLevelDesign()` (Tabler color+ti-icon+txt, one place) + `renderBadgeLevel()`. Vite rebuilt, JS_VERSION 21→22.
- **Known limitation:** the bell only updates *live* for notifications sent with the `BROWSER_TOAST` medium (opt-in per `setListMedium`); others appear on next page-load via the seed. Making all notifications live = wire the daemon push unconditionally or default browser-toast — a Phase 2 (routing/preferences) decision.
- **Pending phases:** 2 = per-user routing/preferences (`user.extraDetail.notification`) to kill the all-Sapiens-staff flood; 3 = per-user archive/dismiss + bulk; 4 = actionability + Trace linking. See `project_notification_rebuild` memory.

## Migration conventions reminder
Same URL, flip render trio; playbook: `data-list-filter` search, `_row.phtml`, edit modal via `data-list-edit-url` (GET fragment; id 0 = create form), `{status:'success', id, row}` / `{status:'error', errors}` envelope, `renderBadge` for statuses, delete dead RHB reload endpoints, field errors via `common.error.essential_information_missing` / `common.error.already_exist_object`.
