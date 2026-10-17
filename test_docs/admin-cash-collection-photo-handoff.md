# Handoff — Cash collection admin: surface the PDA counter photo

**Audience:** sapienscore agent extending the existing `GameAcceptorCollection` admin.
**Status:** PDA-side flow is **live**. The pieces this admin reads (file_upload row + denormalised pointers on `game_acceptor_collection.detail`) are produced today by the production PDA cash-collection submit. This brief is the **read** side — surfacing what the operator already captures.

---

## 1. Why this exists

When a PDA operator now logs a counter reading they:
- Type the counter value.
- Take **one mandatory photo** of the counter face.
- Optionally add a comment.
- Hit submit.

That creates a `game_acceptor_collection` row in `status = PENDING / status_cash = PENDING` and uploads the photo to Cloudflare Images (with R2 + local fallbacks). Until this admin surfaces it, the photo is invisible to the owner / accountant — they only see the numbers. This brief closes that gap.

---

## 2. Prerequisites — all SHIPPED

| Piece | Where it landed |
| --- | --- |
| PDA cash-collection submit endpoint | `App/Controller/Pda/V1/Cash/CashCollectionController.php` (POST `/api/v1/pda/cash-collection/submit`) |
| Server-side row + photo orchestration | `App/Manager/Pda/Cash/PdaCashCollectionManager.php::submit()` (one IC transaction) |
| Generic PDA → Cloudflare photo uploader | `App/Service/Pda/PdaCloudPhotoUploader.php` (Cloudflare Images → R2 → local fallback) |
| New file_upload category | `FileUpload::CATEGORY_PDA_PHOTO_CASH_COLLECTION = 'pdaPhotoCashCollection'` |
| Permission gate | `User::hasPermission(Permission::GAME_ACCEPTOR_COUNTER)` checked on submit |
| Action visibility on PDA | NUC `GameLocation::acceptCoins()` + `ScanIdentifyManager::ACTION_COUNTER_READING` |

**You do not need to touch any of the above.** This admin extension is read-only over the data they produce.

---

## 3. What to build

You're **extending `App/Controller/Admin/Game/GameAcceptorCollectionController.php`** and its associated templates — not creating a new admin page. The existing list + detail flow stays in place; new fields slot in.

### 3.1 List page extensions

Add to the existing collection list:

- **📷 column** — small icon when `detail.idFileUploadPhoto IS NOT NULL`. Clicking opens the photo in a lightbox / modal (or opens the detail page focused on the Evidence panel — whichever is cheaper).
- **Operator column** (if not already present) — name of the PDA user who captured the collection. Source: `detail.pda.idPdaUser`.
- **"Has photo only" filter toggle** in the existing filter bar.
- **"Captured via PDA" filter toggle** — rows where `detail.pda.source = 'pda'`. Useful for separating PDA-driven captures from any future manual / legacy entries.

### 3.2 Detail page extensions

Add a new **Evidence panel** to the existing detail layout, **positioned above the financial / accounting panels** (the photo is context for the numbers, not a footnote).

**Evidence panel content (when `detail.idFileUploadPhoto IS NOT NULL`):**

- The captured photo. Load the row from `file_upload` by id and render via the existing `FileUpload::getFileDTO()` URL.
  - For `storageIdent = 'cloudflare-images'` the URL is already a fully-qualified `imagedelivery.net` link (signed if `CLOUDFLARE_IMAGES_SIGNING_KEY` is set).
  - For `storageIdent = 'cloudflare'` (R2) it's the public R2 URL.
  - For `storageIdent = 'local'` it's a relative path under `public/assets/storing/pda/...` — render via the same admin helper used for trace attachments.
- The thumbnail (`fileDTO->getThumbnail()`) when present (Cloudflare Images returns one; R2/local do not, render full image scaled).
- **`capturedAt`** — when the operator pressed the shutter. Source: `file_upload.detail.pda.capturedAt` (ISO 8601, UTC) — render in location TZ.
- **Operator** — user name + avatar. Source: `detail.pda.idPdaUser` on the collection row (same value also in `file_upload.detail.pda.idPdaUser` — use whichever is cheaper to join).
- **Comment** (optional) — `file_upload.detail.pda.comment` if the operator added one.
- **Storage chip** — small label showing `storageIdent` value (`cloudflare-images` / `cloudflare` / `local`). Useful for support when triaging "why doesn't this photo load."

> **No Operation-link panel.** Cash collection v1 deliberately does **not** create a `game_location_operation` row (different from remediation). Don't add a link — there's nothing to link to.

If the row has no `detail.idFileUploadPhoto` (legacy / pre-PDA-flow rows, or any manual entry going forward), gracefully skip the Evidence panel — leave the detail page exactly as it is today.

---

## 4. Data model

**Read paths only. No schema changes from this brief.**

### 4.1 `game_acceptor_collection.detail` JSON — keys produced by the PDA flow

```jsonc
{
  "idFileUploadPhoto": 1234,           // -> file_upload row
  "photoStorage": "cloudflare-images", // 'cloudflare-images' | 'cloudflare' | 'local'
  "pda": {
    "source": "pda",                   // discriminator: rows created via PDA
    "sourceUuid": "f3a1-...",          // idempotency UUID from the PDA capture
    "capturedAt": "2026-06-28T14:21:09Z",
    "idPdaUser": 126
  }
}
```

### 4.2 `file_upload.detail` JSON — for the linked photo row (category = `pdaPhotoCashCollection`)

```jsonc
{
  "file": {                            // FileDTO::getStoreArray() — render via getFileDTO()
    "path": "https://imagedelivery.net/.../public",
    "type": "image/jpeg",
    "name": "f3a1-....jpg",
    "storageIdent": "cloudflare-images",
    "originalFileName": "f3a1-....jpg",
    "size": 318210,
    "uploadedAt": "2026-06-28T14:21:11+00:00",
    "thumbnail": "https://imagedelivery.net/.../thumbnail"
  },
  "pda": {
    "idOperation": 4567,               // = id_game_acceptor_collection
    "sourceUuid": "f3a1-...",
    "capturedAt": "2026-06-28T14:21:09Z",
    "idLocation": 36,
    "idPdaUser": 126,
    "comment": "label peeling near coin slot",
    "externalId": "abc...-cloudflare-image-id"   // null when storage != cloudflare-images
  }
}
```

### 4.3 Tables involved (all read-only from this brief's perspective)

| Table | Role | Notes |
| --- | --- | --- |
| `game_acceptor_collection` | The collection record. Existing. | New denormalised keys land in `detail` (see 4.1). |
| `file_upload` | The photo. | `category = 'pdaPhotoCashCollection'`. FileDTO + PDA routing metadata in `detail` (see 4.2). |
| `user_` | The operator. | Resolved via `detail.pda.idPdaUser`. |

---

## 5. Reference patterns to copy

- **List + filter scaffolding:** the existing `GameAcceptorCollectionController` already has the list page — extend in place, don't rebuild.
- **Photo rendering helper:** `App/Manager/FileManager::renderGenericImg($file, $keyFile)` gates on admin permission — reuse rather than building a new `<img>` template.
- **Cloudflare-Images URL rendering:** `App/Manager/Trace/TraceAttachmentManager` already handles the three storage backends (images / R2 / local) when surfacing trace attachments — mirror its rendering logic if `renderGenericImg` doesn't already cover it.
- **Lightbox / modal:** check whichever lightbox is already used in the admin (likely something in the adminlte vendor bundle). Don't introduce a new JS library.

---

## 6. Don't do

- **Don't fork the existing admin.** Extend it. A second list page for "collections with photos" splits the operator's workflow.
- **Don't add new tables.** Everything is read paths over the `detail` keys produced by the live PDA flow.
- **Don't render the photo to non-admin users.** Same gate the existing admin uses for sensitive data.
- **Don't break older rows.** Any collection logged before the PDA flow shipped will have no `detail.idFileUploadPhoto` or `detail.pda.*`. The Evidence panel must skip silently.
- **Don't try to back-fill historical rows.** Pre-PDA collections simply don't have photos — that's the truth, not a bug.
- **Don't try to create / mutate the file_upload row.** It's already created server-side under one IC transaction with the collection row; touching it from the admin will fight the existing write path.
- **Don't add a Trace / GLO cross-link panel.** v1 cash collection has no `game_location_operation` row by design.

---

## 7. Acceptance checklist

- [ ] List page shows 📷 indicator for rows with `detail.idFileUploadPhoto`.
- [ ] List page has a "Has photo only" filter toggle.
- [ ] List page has a "Captured via PDA" filter toggle (`detail.pda.source = 'pda'`).
- [ ] List page shows operator name column for PDA-captured rows (`detail.pda.idPdaUser`).
- [ ] Detail page renders Evidence panel (photo + thumbnail + capturedAt + operator + optional comment + storage chip) when the photo pointer is present.
- [ ] Detail page handles all three `storageIdent` values (`cloudflare-images`, `cloudflare`, `local`).
- [ ] Evidence panel is absent on legacy rows (no `idFileUploadPhoto`) — page renders identically to today.
- [ ] Photo is admin-gated using the existing helper (non-admin users see neither the column nor the panel).
- [ ] Existing accounting / Odoo / SII panels and behaviour are untouched.
- [ ] PHP lint clean (`php -l`).

---

## 8. Project-specific technical guidance

> *(salvatore to fill in: which template files to extend, where to register the lightbox JS, controller method signatures for filter additions, how `detail` JSON is currently accessed in the admin templates, naming conventions for the new filter param, etc.)*
