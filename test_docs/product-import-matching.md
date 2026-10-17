---
type: Development Guide
title: Product import — product matching and conflict resolution
description: "How an imported row is bound to an existing product, which situations are reported as resolvable conflicts in the preview, and how the choice is validated on processing."
tags: [product, import, validation, preview, conflict]
status: active
source_kind: hand-written
timestamp: "2026-07-30T00:00:00Z"
---

# Product import — product matching and conflict resolution

The product import runs in two phases: a server-rendered **preview** the user edits, and a
**transactional processing** of the surviving rows. Both phases have to agree on which
existing product an imported row refers to — otherwise the preview shows a green row that
the processing refuses, rolling the whole save back.

## Single matching entry point

`App\Manager\Product\Import\ProductImportMatchManager::resolveMatch()` is the only place
that decides what a row points at. It is a pure function of the row plus the candidate
products, and it returns an `App\DTO\ProductImportMatchDTO` (match type, resolved product
id, candidates).

Candidates are collected by `ProductImportContextManager::getListCandidate()` — every
product of the owner that shares the row's bound id, picked id, name, barcode or customer
id. The preloaded context keeps **all** products per identifier; collapsing them to one per
key is what used to make an ambiguous row look resolved.

Both flows reach it through `ProductImportManager::setCurrentValue()`, so the preview
annotation and the processing decision cannot drift.

## Match outcomes

| Situation | Outcome |
|---|---|
| Name and barcode both belong to the same product | `TYPE_EXACT` — unambiguous, used as is, even if other products share the barcode |
| One product owns the row's only identifier | `TYPE_SINGLE` — the row updates that product |
| The user picked a product in the preview | `TYPE_SELECTED` — the pick is re-validated, then used |
| No candidate at all | `TYPE_NONE` — the row creates a product |
| Several products share the barcode | `TYPE_CONFLICT_BARCODE` |
| Name points at one product, barcode at another | `TYPE_CONFLICT_NAME_BARCODE` |
| Name matches a product carrying another barcode | `TYPE_CONFLICT_BARCODE_CHANGED` |
| The row's customer id belongs to another product | `TYPE_CONFLICT_CUSTOMER_ID` |
| The picked product is not a candidate any more | `TYPE_CONFLICT_SELECTION` |

A conflict never binds a product: ambiguity is reported, never guessed.

`product.name` carries a global unique constraint (`product_name_key`), so a name can only
ever match one product — "several products share the name" is not a reachable state and has
no outcome of its own.

## Resolving identity is not updating attributes

A match answers **which product the row refers to**. It does not give the row the right to
hand that product the identifiers of a *different* one.

Off the selection path this is already true by construction: `getMatchByPick()` refuses a
row whose name, barcode or customer id belongs to a product other than the one it picked —
the row becomes a conflict and nothing is written. The explicit pick used to skip that
check entirely, so a row could be resolved onto product A while still carrying the name of
product B, and the processing then renamed A to B's name.

`resolveMatch()` therefore returns, together with `TYPE_SELECTED`, the list of identifiers
the picked product must not inherit (`ProductImportMatchDTO::getListFieldLocked()`):

| Identifier | Locked when it belongs to another product | Why |
|---|---|---|
| `productName` | yes | `product.name` is globally unique — the update dies on the constraint |
| `customerId` | yes | `Product::create()` refuses a duplicate, and two products sharing one are indistinguishable to the next import |
| `barcode` | no | several products may legitimately share a barcode, and re-barcoding a picked product is the point of the resolution |

`ProductImportManager::setCurrentValue()` applies the lock by writing the referenced
product's own value back onto the row, before anything reads it — so the preview diff, the
stored process result and the update itself all show the value that is really kept. When
the identifier is free, the import still applies it: picking a product and giving it a new
name or barcode is a rename, and that behaviour is unchanged.

## Preview

`ProductImportManager::preview()` orders the checks so a conflict is the *last* thing a row
can be:

1. duplicates inside the imported batch;
2. row validation (`verifyPreviewDTO`) — a blocking error wins, the row is read only;
3. match conflict — `STATUS_IMPORT_CONFLICT`, the row stays editable and resolvable.

A conflicting row has no product bound, so the stock actions skip their "product does not
exist" check for it (`verifyStockDTO($dto, $actionType, $skipProductCheck)`) — otherwise
that error would hide the conflict the user can still resolve.

The card (`templates/adminlte/v2/product/import/module/_compareCard.phtml`) renders the
conflict message, the barcode carried by the file, and a select of the candidates with
their database barcodes. Picking one writes `idProductSelected` into the row payload and
re-renders the card through `/product/import/render-cards/{idLocation}`. Unresolved rows
carry `data-product-import-conflict="1"` and are left out of the save payload.

### Candidates already used by the import

`ProductImportManager::excludeTakenCandidate()` drops from the offered candidates every
product another row of the same import already refers to. Two rows binding the same product
is refused on save by `verifyListDuplicate()`, so offering it would only turn the card green
and break the save afterwards. When nothing is left to offer the card says so instead of
rendering an empty select — the row has to be edited or removed.

`renderCards` only receives the edited rows, so the client sends the products the untouched
rows hold as `listIdProductTaken[]`.

## Processing

`ProductImportValidationManager::verifyProductConflict()` throws on any row whose match is
a conflict. It runs in all three actions (create/update, stock movement, stock reset).

Because the processing re-runs `resolveMatch` on the payload the browser posts, a
`idProductSelected` coming from the client is validated again: the product must still exist,
belong to the location owner, not be deleted, and still be one of the row's candidates.
A stale or foreign id yields `TYPE_CONFLICT_SELECTION` and the row is refused.

## Consequences

- Confirming an ambiguous row is a per-row action; a file that renames or re-barcodes many
  products needs one pick per row.
- An explicit pick is honoured even when it produces a second product with the same barcode
  — the user resolved the ambiguity, and the schema has no uniqueness constraint on
  `product.barcode`.
- A picked product keeps its own name and customer id when the row carries one that belongs
  to another product. The row is not refused for it: the pick already said what the row
  refers to, and renaming the *other* product is not something an import can do.
- The update path stores the barcode uppercased, like `Product::create()` does — every
  lookup (import context query, `Product::getByBarcodeNOwner()`, the matcher's barcode key)
  searches for it that way.

Tests: `tests/Product/Import/ProductImportMatchTest.php` (`php tests/run.php`).
