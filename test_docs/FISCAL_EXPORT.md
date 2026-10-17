# Fiscal data & export study — mall information request (Guimarães, June 2026)

Study date: 2026-09-03. Trigger: the shopping mall (centro comercial) asked the
Guimarães venue for June 2026 sales documentation. This doc maps what Sapiens
holds, what it does not, and the export tooling to build — so this class of
request becomes routine instead of manual.

The mall asked for three things:

1. Daily sales list with payment-method breakdown (cash / card / other), and
   later a sample of daily register closures ("Z").
2. An Excel list of all simplified invoices (facturas simplificadas) for the
   month, with sales-channel detail (in-store / online-pickup / in-store online
   terminal / delivery) and returns detail (same-store / other-store / online).
3. Card sales through the in-store Multibanco terminals (they pull this from
   the bank themselves).

---

## 1. Daily sales by payment method — WE HAVE THIS, export is missing

**Data: complete, on core.** Every POS tender lands in
`payment_location_transaction.payment_method_location` (cash=1, card=2,
voucher=4, external=5, loyalty=6, discount=9, payment-terminal=10 …), joined to
`payment_location` for `id_location`, `type` (income/refund), `source`
(counter/kiosk) and `source_created_at` (venue wall clock). The TimescaleDB
continuous aggregate `mv_payment_location_base` (sqlinstall00324) carries
day × method × register; `ArrayPaymentLocationCounter::getDailyBreakdown()`
already returns per-day cash / card / EMV / kiosk / Nayax / online, and
`GET /reporting/sales-comparison/daily` serves almost exactly the mall's grid.

**What's missing is only the export button** (see §5).

Caveats to state when publishing figures:

- **"Sales" spans four streams** summed only in the breakdown code: counter POS
  (`source=LOCATION`), kiosk (`source=KIOSK`), online/Stripe (`payment_item`,
  no method column — implicitly "online card"), and standalone card-terminal /
  Nayax rows with no linked sale. Decide explicitly which streams the mall
  report includes.
- **Two payment-method enums conflict on code 11**: the client writes
  `SellerPaymentMethodLocation` (11 = OTHER), core's `PaymentMethod` reads
  11 = ONLINE. Cash/card (1/2) are unambiguous; the "other" bucket is not.
  Fix before shipping a per-method export (small, but a correctness issue).
- `amount_cash` nets `change_amount`; `amount_card` does not (correct, but
  explain it if the mall reconciles to the cent).
- **Three notions of "a day" exist**: MV buckets in DB session tz,
  `AccountingReportManager` uses the location timezone,
  `DayClosureManager` uses `business_day_cutoff_hour`. Pick one (location
  timezone, calendar day, matches bank statements) and say so on the export.
- For audit-grade numbers read the base tables, not the MV (refresh lag on
  late NUC syncs) — this is why `AccountingReportManager` already does so.

### Z closures — data exists on core, document does not

- **The per-till Z-equivalent is `cash_register_session`**, mirrored from every
  NUC to core (sqlinstall00392) with opening fund, sales, movements, expected
  vs **counted** cash (`total_real_amount`), discrepancy, open/close times and
  confirmation status. Companion tables (`cash_movement`,
  `cash_discrepancy_justification`, `cash_safe_check`) are mirrored too.
- **A per-location day-closure recap exists on core as a computed view**
  (`DayClosureManager::getArgsByLocationNDate`, `GET /cash/day-closure`) —
  cash/card per register, movements, discrepancies, action items.
- **No printable/immutable Z document exists.** The client's `day_closure`
  table (expected/actual/difference, closed_at/by, sync flags) is dead code:
  no writer, no reader, no sync manager, no core table. Everything shown today
  is recomputed from mutable rows — a re-run months later can differ if late
  syncs or adjustments landed.
- When handing over "counted cash", filter sessions to
  `status IN (CONFIRMED, CONFIRMED_WARNING)` — `CONFIRMED_AUTOMATICALLY`
  means the amount was assumed, not counted.

**Build for the follow-up ask**: an export (CSV + printable view) of the
day-closure recap per day, fed by the same computed manager. Longer term,
decide whether to finally wire `day_closure` as an immutable signed snapshot
written at closure time — that is the only way "the Z we hand out in
September" is guaranteed to equal "the Z we hand out in December".

---

> **UPDATE (official request text, 2026-09):** the mall's item 2 actually asks
> for the **SAF-T** of June 2026; the Excel invoice listing is only the
> fallback ("SE NÃO TIVEREM O SAFT"). Vendus is AT-certified, so the SAF-T is
> downloaded from the venue's **Vendus back-office** — no development needed.
>
> **SAF-T scope caveat (verified on prod 2026-09-03):** the Vendus account
> serves EIGHT PT venues (~476k documents) and they ALL share one document
> series (`FR 01P2026/…`) because our integration never sets
> `registerId`/`storeId` (default register for everything). The SAF-T is
> per-NIF — correct to hand over whole — but nothing inside it identifies the
> Guimarães documents. The ONLY number→venue mapping is our
> `vendus_invoice.id_location`, which makes the listing CSV export below the
> mandatory companion annex to any SAF-T handover.
>
> **Follow-up worth deciding (not built):** configure a Vendus store/register
> per venue and set `registerId`/`storeId` on outgoing documents (the request
> DTO already supports both). Each venue then gets its own series and future
> SAF-Ts become store-attributable. Changes fiscal numbering series — do it
> deliberately, with the accountant, ideally at a year boundary.
>
> **BUILT (2026-09-03):** `/invoice/vendus/list` filters (location/date/type)
> + CSV listing export with totals + month-ZIP of stored PDFs
> (`VendusInvoiceController::exportCsv/downloadZip`,
> `APIVendusManager::ensurePdfFile`); ESP receipt CSV export
> (`/receipt/export`, `ReceiptController`); core `receipt.type` column +
> status repair (sqlinstall00435 — also fixes the `setStatus('status')` bug
> that left 825k mirror rows with status 0); accounting-report Excel export
> re-enabled; shared `react/src/utils/exportUtils.ts` (downloadCsv/
> downloadXlsx) replacing the four inline CSV copies; sales-comparison daily
> grid CSV export (mall item 1).

## 2. Simplified invoices (facturas simplificadas) — TWO regimes, country-gated

There are **two document systems**, selected per sale by the location's
country (`SellController.php:776` on the client):

- **ESP → the client-side `receipt` series** (see §2a). Issued locally on the
  NUC on EVERY POS sale (the cart's `documentType` defaults to 'receipt', so
  the `document` param is always sent), numbered `PREFIX/YEAR/N` from
  `location.invoice_prefix`, credit notes as a separate `PREFIX/YEAR/NC/N`
  series on refunds. PDF rendered at issue time (`ReceiptPdf`).
- **PRT (and everything non-ESP) → Vendus** documents issued by core at
  sale-sync time (see §2b). The comment in the code is explicit: "Generate
  credit note receipt (ESP only — Vendus handles it via API)".

**Open question that decides everything for Guimarães**: by code, a PRT
location gets Vendus documents, not local receipts. Verify empirically on prod
which regime Guimarães actually ran in June (whichever count is non-zero):

```sql
SELECT COUNT(*) FROM receipt        WHERE id_location = :gm AND receipt_date >= '2026-06-01' AND receipt_date < '2026-07-01';
SELECT COUNT(*) FROM vendus_invoice WHERE id_location = :gm AND date         >= '2026-06-01' AND date         < '2026-07-01';
```

### 2a. The `receipt` system (client-issued, mirrored to core)

Tables: client `receipt` (sqlinstall00132 + `type` in 00152), **core mirror
`receipt`** (sqlinstall00264, hypertable on `source_created_at`, synced via
`OutboundReceiptManager` → `/receipt/sync` → `InboundReceiptManager`).

Per row: full numbered fiscal identity (prefix, progressive per year, unique
number), `total_amount`, `subtotal`, `vat_amount`, `receipt_date`, `issued_by`,
status (active/voided/deleted), `id_payment_location` link — **and
`detail jsonb` carries the complete document**: `items[]` (name, qty, unit
price, per-line vatRate/vatAmount/subtotal, vat-postponed flags, loyalty card
number) and `payments[]` (method code, amount, change), plus organization
info. A monthly Excel of simplified invoices for an ESP venue is a
straightforward query over core's `receipt` + its `detail`.

**Gap found**: core's `receipt` table has **no `type` column** and core's
`Receipt` model silently drops the `type` the sync sends — receipt vs credit
note is only recoverable on core by parsing `/NC/` out of `receipt_number`.
Fix: add the column (migration), populate on sync, backfill from the number.

### 2b. The Vendus system (core-issued, for PRT)

The fiscal record lives on core in two tables:

- `vendus_invoice` — normalized: number, type, date, gross, net, ATCUD, hash,
  QR, `id_location` (added sqlinstall00145 — older rows may be NULL),
  `id_credit_note` self-link, status (active/cancelled).
- `vendus_invoice_raw` — the API round-trip audit (this is the ~3GB table; the
  bulk is base64 receipt HTML). VAT detail and payment method exist **only**
  here, inside our request JSON, as Vendus letter codes (`NOR/INT/RED/ISE`)
  and opaque payment-method ids.

### The FS/FR trap (resolve FIRST, before building anything)

**Core has never issued a Fatura Simplificada (FS).** Consumer walk-in sales
produce **FR (Fatura-Recibo)**; company sales produce FT; cancellations
produce NC. Under AT rules FS and FR are distinct document types with separate
series. So either:

- the mall/accountant accepts "the consumer sales documents" = our FR list
  (most likely — confirm in writing), or
- someone issued FS directly in the Vendus portal, outside Sapiens — in which
  case core has no record and only the Vendus API can produce the list.

### Known integrity gaps to check for June before trusting any number

1. **Partial refunds generate NO credit note** (`SellController` cancels only
   exact-amount refunds; `@TODO implement partial refund`). June partial
   refunds → original FR still stands at full value, no NC.
2. **Latent fatal**: `InboundSellerManager::handleVendusPaymentMethodChange()`
   calls `VendusInvoice::getIdCompany()`, which does not exist — the path
   creates the NC then dies before the replacement invoice. Check June for
   cancelled originals with an NC and no reissue. (Fix the bug regardless.)
3. Rows with `id_location IS NULL` (pre-00145) and `vendus_invoice_raw`
   rows stuck at status=1 (request sent, no document recorded).
4. All documents land in Vendus's default store/register (`registerId`/
   `storeId` never set) — inside Vendus the venues are only distinguishable by
   the notes field; on our side `vendus_invoice.id_location` is the key.

### Recommended path: core as index, Vendus API as source of truth

The SDK (`vendus-sdk-php`) supports `documents->list` / `documents->get`, and
core already contains **unused** request/response DTOs for exactly this
(`VendusDocumentListRequestDTO` / `...ResponseDTO`). The detail response gives
what our schema never captured: `taxes[]` (base/amount/rate), `payments[]`
(title/amount), `items[]`, `client{}`, `related_docs[]` (FT↔NC linkage).

Pull June with `since`/`until` (paged), reconcile on `vendus_id` against
`vendus_invoice`, and build the Excel from the API payload. This also answers
the FS question empirically (the API reports which types the account issued).
Gotcha: `VendusRequestMode::getByServerRole()` sends `mode=tests` unless the
server role is production/souldpark — run the pull on prod or force the mode.

### The mall's channel taxonomy, mapped honestly

| Mall category | Our reality |
|---|---|
| Sales made in the store | FR/FT from POS + kiosk sales |
| Online, picked up in store | Online reservations/top-ups paid via Stripe (Vendus `ACTION_PAYMENT`, method ONLINE) — "pickup" doesn't apply; it's activation at the venue |
| In-store via own internet terminal | Kiosk sales (if the mall counts them here rather than "in store") |
| Delivery | N/A — no delivery channel exists |
| Returns from other stores | N/A — refunds are same-venue only |
| Returns of online purchases | Stripe refunds (`payment.type=REFUND`) + postponed top-up rules |

State the N/A lines explicitly in the reply — precision beats defensiveness.

---

## 3. Card / Multibanco — the bank has it; our cross-check is strong

`payment_terminal_transaction` (mirrored to core, hypertable) is
bank-reconciliation grade: masked PAN, card scheme, credit/debit
(`card_type` / `card_function_id`), merchant id, terminal id, auth codes,
amounts, per-transaction timestamps, linkage to the sale
(`id_payment_location`). This lets us cross-check the bank's Multibanco list
transaction by transaction.

Caveat: **Multibanco is not modeled as a payment method** anywhere in Sapiens
(and `APIVendusManager` collapses CARD and PAYMENT_TERMINAL into Vendus's
generic card). Debit-vs-credit is derivable only from the terminal transaction
fields.

---

## 4. What the client (NUC) holds that core does not

- Rendered receipt PDFs (`ReceiptPdf`, `TerminalReceiptPdf`) — presentation
  only; the fiscal document is core-side Vendus. Receipt rows sync to core.
- Nothing else fiscal. The client has no Vendus tables and no API key.

Conclusion: **the mall request is answerable from core (+ Vendus API) alone**;
nothing needs to be pulled from the venue NUC.

---

## 5. Export tooling plan

Current state: `xlsx` (npm) is used by exactly one page; four pages carry
copy-pasted CSV helpers in two incompatible dialects; **the accounting report
has a complete 3-sheet Excel export already written and commented out**
(`AccountingReportDashboard.tsx`, disabled in b76af2e7f); no server-side Excel
exists anywhere (no PhpSpreadsheet), and no reporting API emits a file.

Build order (each step independently shippable):

1. **Re-enable the accounting-report Excel export** (uncomment + sanity pass).
   Note: `xlsx@0.18.5` has a known CVE on *parsing*; we only write — nil
   exposure, but pin the note in the PR.
2. **Shared helper `react/src/utils/exportUtils.ts`**: `downloadCsv(rows,
   filename, {delimiter})` (default `;` + EU decimals — operators open these
   in ES/PT Excel) and `downloadXlsx(sheets, filename)` lifted from the
   accounting page. Replace the four inline copies. Reuse existing
   `common.action.export_csv` translations.
3. **Export on the sales-comparison daily grid** — this alone answers mall
   request 1 with zero new backend.
4. **Fiscal document export** — the only genuinely new build, covering BOTH
   regimes behind one surface (location's regime picked automatically):
   - ESP: query core `receipt` + `detail` (items/VAT/payment methods all
     there). Include the core `type` column fix (§2a gap).
   - PRT: v1 `text/csv` over `vendus_invoice` (follow the
     `CardGeneratorController` streaming pattern); v2 the Vendus-API-backed
     monthly pull for authoritative VAT/payment/related-docs detail (uses the
     dead list DTOs).
   - PRT document ZIP: every Vendus document is ALREADY stored on core disk
     as `.myhtml` + generated PDF (`VendusInvoice::getStoragePath(true)`,
     `assets/storing/admin/<docType>/<Y>/<m>/<d>/<filename>.pdf`, written by
     `APIVendusManager::generatePdf` at creation). A month-ZIP is: select
     `vendus_invoice` by location+range → collect storage paths → zip → stream
     (VoucherBulkController tempfile pattern). Regenerate any missing PDF from
     its `.myhtml` via the existing mPDF path. Surface: add location + month
     filters and the two buttons (listing export, ZIP) to the existing
     `/invoice/vendus` admin list, which today has no filters at all.
   - Guimarães = id_location 4 (PRT, Vendus regime).
5. **Day-closure export** (when the mall asks): CSV + print view over the
   computed recap; separately decide on persisting `day_closure` snapshots.
6. **Hygiene fixes surfaced by this study**: unify the payment-method enum
   (code 11 conflict), fix `getIdCompany()` fatal, implement partial-refund
   credit notes, consider setting Vendus `registerId` per location.
