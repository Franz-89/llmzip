# Currency handling — rules and cleanup spec

Applies to **sapienscore** and **sapiensclient** (cross-project sync rule: shared idioms stay identical).
Status: cleanup in progress. The **Rules** section is permanent documentation; the **Cleanup slices** section describes the one-time refactor and can be trimmed once done.

## Rules

1. **The installation `.env` is the single source of truth.** One deployment = one operator = one currency (the multi-owner ambition is retired in practice; org-less data like per-country products makes an org anchor impossible anyway). Four explicit values, set once at install time and **never edited afterwards** — changing them is a deliberate deploy operation, there is no UI:
   ```
   CURRENCY=EUR
   CURRENCY_SYMBOL=€
   CURRENCY_SYMBOL_POSITION=after   # before|after
   CURRENCY_DECIMAL_SEPARATOR=,     # . or ,
   ```
   One small config accessor (following the app's existing env-read idiom) exposes them; `CurrencyCollection` may pre-fill symbol/position defaults per code, but the env values win.
2. **Currency columns stay, users don't fill them.** Every table keeps its `currency` column as the historical record of what currency an amount was in when written. The value is **stamped server-side from the env config at write time** — never read from a request param, never a form field, never a literal `'EUR'`.
3. **Rendering always goes through `NumberHelper::renderAmount($amount, $currency)`**, where `$currency` is the record's own currency if the record has one, else the env currency (the accessor is the helper's default). Templates and PHP never contain literal `€` / `'EUR'` for rendering. JS that formats amounts receives the symbol/position from the server (see `OutboundKioskManager` for the existing `currency` / `currencySymbol` / `currencySymbolPosition` payload shape). Admin and receipts use the env decimal separator; per-visitor-language formatting for customer-facing pages is a deferred, separate decision (`LocaleNumber` stays for that).
4. **Selection survives only where it describes an external reality:**
   - the **analysis/reporting** currency selector — it drives `CurrencyConverter` for cross-currency reporting, it never writes business data;
   - **marketing ads** (Google/Bing bill in their own currency; the field records the platform's fact, conversion normalizes reporting);
   - **payment hardware responses** (the EMV/terminal response's `Currency` is a fact — record it as received);
   - **product buying-side currency** (supplier invoices are an external fact) — *if* it is user-set today; the slice verifies. Selling side stamps from env.
5. **`Organization.currency` stays as a fiscal record, loses all UI.** Stamped from env at org creation (select removed from the form), locked afterwards, synced to the client as today. It exists for eventual fiscal needs, not as a live setting.
6. **`GameLocation.detail['businessSetting']['currency']` has no UI.** Stamped from env (it feeds SQL views `sqlinstall00271–273`, which stay unchanged). Location-level currency overrides do not exist until a real multi-country customer exists.
7. **Silent `?? 'EUR'` defaults are forbidden** — default to the env currency via the accessor. DTO property initializers drop `= 'EUR'`; callers pass the resolved currency.
8. **The client has no currency config of its own — core pushes it.** The NUC gets a generic `system_setting` table (`key` text PK, `value` jsonb, audit fields) populated by core during **initNuc**: the outbound payload carries the four currency values from core's env (`OutboundKioskManager`'s `currency`/`currencySymbol`/`currencySymbolPosition` payload is the precedent). The client currency accessor reads the synced setting, not env. If the setting is missing (init incomplete), fall back to EUR **and open a Trace** — the venue keeps operating, the gap is loud. Settings ride along on every initNuc run, so re-init heals gaps. Currency is the first tenant of `system_setting`; future core-owned config reuses the same channel.
9. **Multi-currency later = price lists per currency** (a pricing feature). No exchange-rate logic outside the existing reporting `CurrencyConverter`. Supported currency list lives in `CurrencyCollection` (`EUR, GBP, NOK, SEK, DKK`).

## Cleanup slices (one agent task each, reviewed as a diff before the next starts)

Inventories below come from the July 2026 audit; agents re-grep before editing (the branch is active, lines drift). Scope excludes: React `/analysis` bundle, static marketing copy with example prices (e.g. Porto `booking-success.phtml` €450/€300 blurbs — flag, don't edit), vendor dirs, and any data migration.

### Slice 1 — Core foundation
- Add the env currency config accessor (rule 1) and make it `NumberHelper::renderAmount()`'s default currency; document the four vars in the env example file.
- `Organization.currency`: remove the select from creation + update forms/controllers; stamp from env at creation (rule 5).
- Add a **migration report** utility (report-only, no writes): per table with a currency column (20 on core), count rows where `currency` differs from the env currency. Same report shape for client (10 tables).

### Slice 2 — Core write paths (stamp from env, remove selection)
- `GamePriceController` (`getParam('currency') ?: 'EUR'` at ~369/775/1062) → stamp; remove currency **text inputs** from v1 game price templates and v2 `game/gamePrice/module/_detail.phtml` + `_new.phtml`.
- `PaymentTerminalController` (~473) config currency → stamp; remove input from `paymentTerminal/config/module/detail.phtml`.
- Loyalty package form hidden `currency` inputs (v1 `loyalty/loyaltyCardPackage/module/detail.phtml`, v2 `loyaltyCardPackage/module/_form.phtml`) and activity package (`weekIndividualUpsert.phtml`) → remove; managers stamp.
- `GameLocationController` businessSetting `'EUR'` literals (~425/478) → env stamp.
- `qrcode_nfc_assignment` / kiosk operation / other create paths defaulting `'EUR'` → env stamp.
- Product selling-side currency → env stamp; verify buying-side (rule 4) and note the outcome in the PR.
- Filter selects (`filter/module/control/reservation.phtml`, `mvGeneric.phtml`): these are report filters — keep only if they feed `CurrencyConverter`; otherwise remove (verify usage before deciding, note the outcome in the PR).

### Slice 3 — Core rendering sweep
- ~155 PHP + ~321 template `'EUR'` literals and ~46 raw `€`: route through rule 3. Typical fix: `renderAmount($x, 'EUR')` → `renderAmount($x, $record->getCurrency())`, or omit the currency argument (env default) when no record currency exists (e.g. `dashboard.phtml`, `TraceSearchRepository::…€`, highcharts `'{value} €'` label fed from server).
- DTO defaults (`LoyaltyPackageSettingDTO` etc.) per rule 7.

### Slice 4 — Porto/public + emails (core)
- Porto templates (13 `'EUR'` + 46 `€`, incl. `reservation/confirm.phtml`, `nfcPayment/*`) and 8 email-template literals → rule 3. NFC payment records already carry currency — render from the record.

### Slice 5 — Client foundation + write paths
- `system_setting` table + AutoDb model + cached accessor on the client; inbound handler storing the initNuc settings payload; currency accessor reads the synced setting (rule 8), EUR fallback + Trace when missing.
- Core side of the channel: initNuc outbound (`OutboundNucManager`) adds the `listSetting` payload built from core env. (Core-side edit, but lands in this slice so the channel ships whole.)
- POS payment: stop reading `$data['currency']` (`POSPaymentRequestDTO` / POS controllers) → env stamp.
- `WalletManager` `'EUR'`, GatewayAuth payment controllers' `'currency' => 'EUR'`, DTO defaults (`CardDTO`, `CounterPaymentResultDTO`, …) per rule 7. Payment-hardware DTO (`PaymentTerminalTransactionDTO`) keeps recording the response currency (rule 4), but its *fallback* becomes env, not `'EUR'`.
- Marketing ads + analysis selectors: keep (rule 4).

### Slice 6 — Client rendering sweep
- Receipt/ticket PDFs (`ReceiptPdf`, `TerminalReceiptPdf`, `EntranceTicketPdf`) → env currency via accessor.
- Seller POS templates, dashboard, `changePaymentMethod.phtml` (`$currency = 'EUR'`), v2 `_row` partials → rule 3.

### Slice 7 — Verification
- Grep both repos for remaining `'EUR'` / `€` literals outside the allowed list (CurrencyCollection, migrations, vendor, flagged static copy); zero unexplained hits.
- Run the migration report from slice 1 on both sides; attach output to the PR.
- Confirm outbound/inbound sync payloads carry currency end-to-end (gamePrice/package/kiosk payloads) with no `?? 'EUR'` left in the chain.
- Verify the settings channel (rule 8): run initNuc against a client, confirm `system_setting` holds the four currency values and the client accessor resolves them; confirm the missing-setting path opens a Trace.
