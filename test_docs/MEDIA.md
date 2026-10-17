# Media storage & serving (source of truth)

Core owns ALL media; sapiensclient/PDA store none — they only render URLs core produces.
Two backends, split by content type:

| Content | Store | Serve | Access control | Cache | Bytes via PHP |
|---|---|---|---|---|---|
| **Images** (photos, screenshots) | **Cloudflare Images** | `imagedelivery.net` | signed URLs (7-day exp) | edge | no |
| **Non-image files + Floor underlays** | **R2** (private bucket) | **`sapienscoreusercontent.com`** via a **Worker** | app-minted **HMAC token** | edge | no |

Avatars are R2 too (`MediaUploadManager::uploadAvatar`).

## Hard rule: never persist or serve a signed URL
Signed URLs expire. Persist the **storage id** (Cloudflare Images: the image id; R2: the
object key) and **sign at render**. Violating this is what broke the cash-collection
photos (they served a frozen Images URL). Shared home: `App\Service\Media\MediaUrlResolver`
(Images) and `App\Service\Media\MediaSigner` (R2).

## R2 access model (the Worker)
The R2 bucket stays **private** (no public access, no r2.dev). The only reader is a
Cloudflare **Worker** bound to `sapienscoreusercontent.com`:

- App mints `https://sapienscoreusercontent.com/<key>?exp=<epoch>&sig=<hex>` via
  `MediaSigner::signR2Key()`, where `sig = HMAC-SHA256("<key>\n<exp>", MEDIA_SIGNING_SECRET)`.
- The Worker (`cloudflare/media-worker/`) recomputes the HMAC, checks `exp`, then serves
  the object from R2 with edge caching. Invalid/expired token → 403.
- **Dedicated user-content domain on purpose** (like `googleusercontent.com`): cookieless,
  sandboxed from `*.sapienscore.com`, so uploaded HTML/SVG can't touch the app session.
- **One domain + one bucket for every customer.** Tenant isolation is the object key
  prefix — `generateRemotePath` = `{ownerId}/{category}/{Y/m}/{file}` — plus the token.
- The Worker caches by **object key** (token stripped), so a fresh per-render token doesn't
  hurt cache hits. Bytes go R2 → edge → browser, never through PHP.

### Why not the alternatives
Public custom domain (unguessable keys) = capability URLs, no expiry/revocation. Presigned
S3 URLs = no edge cache. PHP proxy = every byte through the app. The Worker gives private +
cached + no-PHP-bytes at once. It is **serverless** (no server to run).

## Config (per env, in `.env`)
- `CLOUDFLARE_R2_PUBLIC_URL` = `https://sapienscoreusercontent.com` (the media domain — NOT
  the `…r2.cloudflarestorage.com` S3 endpoint, which is private/auth-only and 400s in a browser).
- `MEDIA_SIGNING_SECRET` = a random secret, **identical** to the Worker's secret.
- Dev: point at a dev subdomain/bucket (`dev.sapienscoreusercontent.com`) or leave R2 off.

## Cloudflare setup (one-time)
1. Add zone `sapienscoreusercontent.com` to Cloudflare.
2. Keep the R2 bucket **private**.
3. `cd cloudflare/media-worker`, set `bucket_name` in `wrangler.toml`, then:
   - `wrangler secret put MEDIA_SIGNING_SECRET` (paste the same secret as the app)
   - `wrangler deploy`
4. Confirm the route `sapienscoreusercontent.com/*` points at the Worker.

## App code map
- `App\Service\Media\MediaSigner::signR2Key($key)` — signs an R2 URL.
- `App\Service\Media\MediaUrlResolver` — re-signs Cloudflare Images at render.
- `FloorManager::formatLevelForApi` — signs the underlay's R2 key (done; Floor canvas fixed).
- **TODO (next):** Trace non-image attachments and avatars — store the full R2 **key** at
  upload (currently `basename`/frozen url) and sign via `MediaSigner` in their serializers.

## Status
- Cloudflare Images expiry (re-sign on render): DONE (`MediaUrlResolver`, collection fixed).
- R2 signer + Worker + Floor underlay: DONE (this change) — needs the Worker deployed + env set.
- R2 wiring for Trace docs + avatars: pending (store key + sign in serializers).
- Client/PDA consuming core-signed URLs + NUC-offline expiry strategy: pending.
