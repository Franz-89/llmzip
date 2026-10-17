---
name: user-docs
description: Create, translate, or edit end-user guides for the documentation CMS (sapienscore-technologies). Use when asked to write a user guide, document a feature for customers, translate a guide to es/pt, update live documentation, or capture guide screenshots. Covers the house writing style, the live-DB edit protocol, and the Playwright screenshot toolchain.
---

# User documentation guides — full playbook

End-user guides ("how do I use the cash register", "what are clusters") live in the
**sapienscore-technologies** CMS. This skill covers the complete lifecycle: writing in
the house style, per-language screenshots, uploading/editing directly in the live DB,
and keeping repo source files in sync.

Read `snippets.html` in this skill folder for the exact copy-paste HTML blocks.

## Where everything lives

**Live content — production DB** (credentials in `~/.config/sapiens/docs-db.env`, never commit them):

```bash
set -a; source ~/.config/sapiens/docs-db.env; set +a
docker exec -i -e PGPASSWORD sapienscore-technologies-database-1 \
  psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -v ON_ERROR_STOP=1
```

(Any local postgres container works as the client; `psql` is not installed on the host.)

- `documentation` — one row per guide: `slug`, `id_documentation_category`, `target_app`
  (`core`/`client`/`both`), `role_required` (70=customer service … 100=sys), `status`
  (1 draft, 2 live, 3 deleted), `sort_order`.
- `documentation_translation` — one row per locale: `id_documentation`, `locale`
  (`en`/`es`/`pt`, sometimes more), `title` (numbered: `"2.0 Institutional clusters"`),
  `content` (raw HTML, TinyMCE-managed), `video_url`. UNIQUE on (id_documentation, locale).
- `documentation_category` — `slug` + per-locale names. List existing categories before
  inventing one.

**Repo source files** (the working copies; live DB is authoritative once uploaded):

- `sapienscore/docs/new/<topic>/{en,es,pt}/NN-slug.html` + `{lang}/img/*.png`
- `sapiensclient/docs/new/<topic>/…` (e.g. `cash`) — same layout
- `../../../test_docs/new/<topic>/_automation/` — Playwright screenshot scripts (see below)

**Images**: uploaded manually by the user through the CMS → Cloudflare Images URLs
(`https://imagedelivery.net/GsPRZXOY_RZTgV8SOGAdKw/<id>/original`).
**Screenshots are ALWAYS per-language** — the UI is captured once per locale, so each
locale's row references its own uploads. When a language's image isn't uploaded yet,
either reference the EN URL as a graceful interim or use `src="PLACEHOLDER-<name>.png"`
with the `<figcaption>` already written — the user swaps the src after uploading.
Never invent an imagedelivery URL.

**Cross-references**: `<a class="doc-link" data-doc-id="NN">Title</a>` where NN is the
target's `id_documentation`. Resolve every link — an empty `data-doc-id=""` is a dead
link. Same id across all locales of a link.

## House writing style (non-negotiable — match existing guides)

Look at the live cash guides (ids 68–75) or cluster guides (76–79) as reference. The
shape of every chapter:

1. Two lead paragraphs, gray (`color: #5d6d7e`): **Audience:** … then **Purpose:** …
2. Blue **Quick summary** callout with 3–5 bullets.
3. `<h2>` sections (`border-bottom: 2px solid #e5e8eb; padding-bottom: 6px;`).
4. Figures: `<figure>` + `<img>` + gray `<figcaption>` describing what the reader sees,
   with concrete numbers ("expected 150,00 €, counted 140,00 €").
5. Colored callouts (exact markup in `snippets.html`):
   - blue `#2980b9` — info / how it works
   - orange `#e67e22` — caution / why-it-matters
   - red `#c0392b` — never-do-this
   - purple `#8e44ad` — concept notes AND "Real case" stories
   - green `#27ae60` — closing checklist
6. At least one **Real case** per chapter: recurring cast **Milo & Lola (cashiers),
   Rocco (manager)**, structured as **Situation / Actions / Result**, always ending with
   the habit that prevents the problem.
7. A **Who does what** section (cashiers vs manager) where relevant.
8. Green **Checklist** callout to close.

Tone: direct second person ("you"), concrete euro amounts, explains *why* the system
behaves as it does, never blames the user. Screenshots referenced in flow, not dumped.

Language conventions: accented characters as HTML entities (`&oacute;`, `&ecirc;`,
`&mdash;`, `&laquo;…&raquo;`) — always WITH the trailing semicolon. UI names in the text
must match the app's actual translated labels for that locale (check the translation
files / running app, don't guess). ES uses «encargado», tú-form; PT uses «gestor»,
tu-form, «gaveta/cofre».

TinyMCE normalizes markup on save (strips indentation, splits the Audience/Purpose
paragraph). When editing LIVE content, match the normalized style (no leading
indentation); for new repo files either style is fine.

## Protocol: editing LIVE guides (the default for existing content)

Live rows drift from repo files (the user edits in the CMS) — **always edit the live
content, never overwrite it with repo files.**

1. **Backup first, always**: `COPY (SELECT * FROM documentation_translation WHERE …)
   TO STDOUT WITH (FORMAT csv, HEADER true)` → save to the session scratchpad.
2. Pull each row's `content` with `psql -At` into one file per (doc, locale).
3. Edit the pulled files locally (surgical edits; keep untouched text byte-identical).
4. Check no malformed entities: scan for `&[a-zA-Z]+` not followed by `;`.
5. Write back in ONE transaction with dollar-quoting (assert the tag doesn't occur in
   the content first):

```sql
BEGIN;
UPDATE documentation_translation
SET content = $DOCEDIT$…full html…$DOCEDIT$, modified_at = NOW()
WHERE id_documentation = NN AND locale = 'xx';
-- verification SELECT of ids + length(content) before COMMIT
COMMIT;
```

6. Never touch `status`; never DELETE; only the rows in scope.
7. Beware pre-existing data bugs: a locale row can contain the WRONG language (a
   mis-paste — e.g. doc 73 pt held Spanish once). Sanity-check the first line of every
   pulled row actually reads as its locale.

## Protocol: creating a NEW guide

1. Write the EN chapter(s) as repo files first (`../../../test_docs/new/<topic>/en/NN-slug.html`),
   following the style above. Get the user's sign-off on EN before translating.
2. Translate to es/pt as sibling files — same structure, figure-for-figure,
   link-for-link. Translate the content, not word-by-word; keep the cast names.
3. Screenshots per language via the `_automation` toolchain (below) into
   `{lang}/img/`. The user uploads them to the CMS and provides/creates the pages.
4. To insert directly in the DB: create the `documentation` row (slug, category id,
   target_app, role_required, sort_order, status 1 draft until reviewed), then one
   `documentation_translation` INSERT per locale (title numbered like siblings).
   Map `img/*.png` srcs → uploaded URLs (or PLACEHOLDER-), fill all `data-doc-id`.
5. Mirror final content back to the repo files so sources don't drift too far.

## Screenshot automation (Playwright)

Pattern lives in `../../../test_docs/new/cash/_automation/` (sapiensclient) and
`../../../test_docs/new/cluster/_automation/` (sapienscore) — copy `lib.mjs` + a `cap-*.mjs` for new
topics. Key conventions:

- Drives the LOCAL DEV stack (client: `client.local:8070`; docker `client-dev-*` /
  `core-dev-*` containers). Login = avatar + PIN (`Shop Manager`/1234 manager,
  `Test C2`/1212 cashier — avatar names change; auto-detect by listing
  `button.v2-login-avatar` texts on failure).
- Workstation identity is seeded via `workstation_uuid` cookie+localStorage — query the
  dev DB `workstation` table for a current uuid; the one hardcoded in `lib.mjs` goes
  stale after reseeds.
- Playwright comes from the npx cache: symlink per `_automation/README.md`.
- One run per language: `setLang(page, 'es'|'en'|'pt')` then capture into that
  language's `img/` dir. Modal shots = `page.locator(modal + ' .modal-dialog').screenshot()`;
  TomSelect-wrapped selects are set via `el.tomselect.setValue(v)`; hidden `<option>`s
  need `waitForSelector(..., { state: 'attached' })`.
- Fill forms with realistic scenario data matching the guide's story (same amounts).
- Seed required DB state directly in the dev DB (UPDATE a session's `closed_at`, INSERT
  a discrepancy with `sync = 1` so it never syncs up) and CLEAN UP after the run.
- Screenshots must not show absurd demo values (a 900 000 € drawer) — normalize the dev
  data first.

## Safety rules (hard)

- Production DB: backup before any write; single transaction; `ON_ERROR_STOP=1`;
  verification SELECT inside the transaction; UPDATE/INSERT only, never DELETE.
- Credentials stay in `~/.config/sapiens/docs-db.env` — never in the repo, never in
  a committed file.
- Dev DB seeding is fine, but roll back or delete what you seeded, and set `sync = 1`
  on seeded client rows so they don't propagate to core.