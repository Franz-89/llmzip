# Task: Vendus receipt file storage — stop the unbounded local sediment

## Problem

Every Portuguese Vendus document (FR receipt, FT invoice, NC credit note) is stored
as **two files** on the core server's `data_user_storing` docker volume, and nothing
ever deletes them:

- `.myhtml` — the printable HTML returned base64-encoded by the Vendus API
  (`APIVendusManager` writes it right after document generation).
- `.pdf` — rendered from that HTML with mPDF (`APIVendusManager::generatePdf`,
  double-pass render for thermal-paper height).

Path comes from `VendusInvoice::getStoragePath()`:
`public/assets/storing/adminlte/{receipt|invoice|credit}/Y/n/d/<filename>.{myhtml,pdf}`
(dir name per type from `VendusDocumentType::getStorageName`).

## Measured state (2026-08-21, beast-souldpark)

- `adminlte/receipt/` = **47 GB**, `adminlte/invoice/` = 1.7 GB, `adminlte/credit/` = 387 MB
- 461,782 `vendus_invoice` rows since 2024-12-13 → **~100 KB per document** (both files)
- Current rate ~29k documents / 30 days → **~3 GB/month**, accelerating as Portugal grows
- The volume lives on the production primary's disk (878 GB, currently 22% used) —
  not urgent, but pure sediment with no cleanup path.

## Constraints

- These are fiscal documents (AT-certified, ATCUD/QR) — the **content must stay
  retrievable for the legal retention period (10 years in PT)**. Deleting is not an option;
  relocating is.
- Consumers to keep working:
  - `VendusInvoiceController` (admin UI download/view — uses `getStoragePath`)
  - `APIVendusManager::generatePdf` reads the `.myhtml` back to build the PDF
  - The client (sapiensclient) fetches receipt content for printing via the gateway
    API (`ReceiptController` / `FinderController`) — check what they actually read
    (DB fields vs files) before assuming.
- The project already has an R2 media layer: `MediaUploadManager` + `MediaUrlResolver`
  (Cloudflare R2, signed 7-day URLs, re-sign on render — see docs + memory
  `project_media_layer`). Supplier invoices already sync to R2
  (`supplierInvoiceLocationFileR2Sync` cron) — that's the closest precedent to copy.

## Suggested direction (validate, don't assume)

1. **Stop pre-rendering the PDF** unless something actually requires a file on disk —
   the PDF can be rendered on demand from the `.myhtml` (or served as HTML). That
   alone halves the growth.
2. **Move the archive to R2**: new documents upload on creation; a backfill command
   migrates the 47 GB history (year/month batches, verify then delete local).
   Follow the supplier-invoice R2 sync pattern.
3. `getStoragePath()` becomes the single seam: keep the method, make it resolve to
   R2 (or a local cache) so all consumers keep working.

## Verify before designing

- On beast: per-year breakdown + pdf/html size split:
  `sudo sh -c 'du -sh /var/lib/docker/volumes/souldpark_data_user_storing/_data/adminlte/receipt/*'`
  and avg file sizes for `*.pdf` vs `*.myhtml`.
- Confirm what the client-side print path reads (files via gateway, or DB columns
  `qrcode`/`detail`) — if it never reads the files, the archive is core-only.
- Check `VendusInvoiceRaw` (DB) already stores request/response — the `.myhtml` may
  be redundant with what's in the DB (3.2 GB `vendus_invoice_raw` table).

## Non-goals

- No change to Vendus API integration or document generation logic.
- No deletion of fiscal content anywhere — relocation only.
