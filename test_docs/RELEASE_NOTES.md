# Release notes

How customers find out what changed, for every product we ship: core, client,
kiosk, PDA.

## The model

A release note is **an ordinary documentation entry** in the reserved
`release-note` category on sapienscore-technologies, with `min_version` set to
the version it ships with and `target_app` set to the product it describes.

There is no separate release entity, and nothing to write at release time in any
repo. You write the note in the CMS whenever you want; **publishing it (status
draft → live) is the trigger**. Nothing else announces anything.

## What a user sees

Two bounds, and they mean different things:

```
RELEASE_NOTE_FROM_<APP>  <=  min_version  <=  VERSION
        floor: when they joined        ceiling: what they run
```

- **Ceiling** — the install's own `VERSION` (`includes/config-common.php`). A note
  never announces a version the customer does not run yet. Applied by the API for
  core and client. **Kiosk and PDA have no ceiling**: the APK rolls out fleet-wide
  and device versions only reach us at the next handshake, which can lag a
  rollout by hours. What gates them is when you publish.
- **Floor** — `RELEASE_NOTE_FROM_<APP>` in the install's `.env`, the version the
  customer joined on, so the archive never predates the relationship. Written
  once at onboarding, never touched again. Absent means no floor.

```
RELEASE_NOTE_FROM_CORE=2.3.6
RELEASE_NOTE_FROM_CLIENT=2.7.2
RELEASE_NOTE_FROM_KIOSK=1.0.7
RELEASE_NOTE_FROM_PDA=1.0.7
```

Versions come from `includes/config-common.php` (core, client) and
`app/build.gradle.kts` `versionName` (kiosk = `sapiens-kiosk`, PDA =
`sapienspro`).

These live in the per-customer `.env`
(`docker-compose-setting/customers/<customer>/core/.env`), **not** in
`config-common.php` — that file ships inside the image, identical for everyone.
`src/env.php` turns every `.env` key into an uppercase constant, so no loader
code is involved.

Add these keys when provisioning a new customer. Forgetting them means the new
customer sees the whole archive.

## Where it shows

| Product | Read on | Surface |
|---|---|---|
| core | core | `/documentation/release-note`, own sidebar entry with an unread counter |
| client | client | same page, single product, no modal, nothing on the sell screen |
| kiosk | core | a tab on core's page — the operator is the reader, never the guest |
| PDA | core | a tab on core's page |

No modal anywhere. The counter is the discovery mechanism: it counts notes the
user has never opened, and opening one clears it. Read state is the existing
`documentation_view` table — the same `track()` that already runs when any doc is
fetched, so there is no separate "mark as read" path.

## Authoring rules

- **`min_version` is required** and must be a plain dotted number (`2.5.1`).
  Anything else (`v2.5`, `1.0.7-beta`) is treated as "no version" and the note
  shows to everyone.
- **Never set `max_version`** on a release note. A release note is not withdrawn
  at a later version, and a ceiling on it would hide it from newer installs.
- `target_app` picks the product tab. `both` puts a note on core and client.
- `role_required` works as it does for any doc — don't pop an Odoo VAT fix to
  cashiers.
- Link to knowledge-base articles from the note body; doc-links resolve normally.

## Implementation

**technologies**
- `DocumentationRepository::buildVersionWhere()` — bounds compared element-wise
  as `int[]`, because a string compare puts `2.10.0` below `2.9.0`. Rows whose
  version is not a plain dotted number are treated as unbounded so one bad value
  can never break the cast for the whole query.
- `getFilteredList()` also accepts a category **slug** (not just an id), so the
  contract does not depend on per-install ids.
- `getBySlugWithContent()` and `search()` are version-filtered too — previously a
  direct slug or a search hit bypassed the gate entirely.
- `sqlinstall00109.sql` creates the reserved category.

**core / client**
- `App/Manager/Documentation/ReleaseNoteManager` — resolves both bounds, groups
  by product, sorts newest first, annotates read state, counts unread. Bounds are
  resolved here rather than by the API because one fetch serves every product
  tab, each with its own bounds.
- The whole category is fetched in **one** call and cached in Redis for 15
  minutes. The sidebar counter runs on every page render, so a cURL to
  technologies must never sit on the hot path. A failed call caches nothing and
  the next render retries; during a technologies outage the page is empty and the
  badge is absent.
- The knowledge base strips the reserved category (`stripReleaseNote`) — release
  notes have their own page and their own floor.

## Deliberately not done

- **No per-user "joined at" stamp.** The floor already stops the archive from
  predating the relationship. A new employee at an old customer seeing the
  backlog once is a cosmetic issue, not a correctness one — add
  `versionAtCreation` on `user.extraDetail` only if it turns out to annoy.
- **No modal, no notification.** The notification system is for events that need
  a human; a release note is an invitation to read.
- **No per-operator release targeting.** If staged rollouts ever become real, the
  right home is a "released version" per operator on technologies, next to the
  `kiosk` registry — which needs the docs API to identify the caller (today it is
  one shared `DOCS_API_KEY`).
