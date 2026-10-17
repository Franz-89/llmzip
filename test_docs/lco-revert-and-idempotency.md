# Guide — `loyalty_card_operation` sync: universal idempotency + REVERT delta re-application

**Audience:** sapienscore agent.
**Counterpart:** sapiensclient is adding a new `OPERATION_REVERT` LCO type as part of the PDA "customer issue" remediation feature (see also `pda-game-location-operation.md`). This guide is the matching cloud-side work.
**Scope:** two separable deliverables — (1) universal idempotency on LCO sync, (2) REVERT-specific delta re-application + back-reference on the original transaction.

The two deliverables can ship independently. Idempotency is a pure bug-fix that benefits every existing LCO type and has no client coordination cost. REVERT requires the new enum value and is the first LCO type that's truly event-sourced on the cloud side.

---

## 1. Why this exists

Today's `InboundLoyaltyCardOperationManager::syncOperation` does two things wrong:

1. **No idempotency.** Every sync call inserts a fresh `loyalty_card_operation` row. A NUC retry creates a duplicate. Today this is audit noise (cloud balance is overwritten by the parallel `LoyaltyCardSync` regardless), but for any operation that wants to be the actual source of truth on the cloud (REVERT, eventually all of them), duplicates would double-apply balance deltas.

2. **No re-application.** The LCO row is stored as a pure record; the cloud card's balance comes from `LoyaltyCardSync` (which overwrites absolutes). This is the opposite of how `topUpCard` works — there, the cloud calls the **same** `SellerLoyaltyCardManager::topUpCard` that the local side ran, deriving the new balance from the deltas. We want REVERT to follow the topup model: same method on both sides, idempotent on the source tuple.

This guide implements (1) for everyone and (2) just for REVERT. Other LCO types continue to behave as today; their migration to the event-sourced model is a separate effort.

---

## 2. Deliverable A — Universal LCO idempotency

### 2.0 `id_source` is permanent lineage, not just a dedup key

Every LCO synced from a NUC is stored on the cloud with **two ids**:
- `id_loyalty_card_operation` — the cloud's own PK.
- `id_source` — the client's `id_loyalty_card_operation` value, kept forever.

This is non-negotiable for tracking. Any cloud LCO row must always be answerable to *"where did you come from?"* via its `id_source` (+ `source` + `id_location` to disambiguate the NUC). The idempotency dedup in §2.2 leverages this triple, but the columns exist for lineage first and dedup second — they remain populated and meaningful long after the dedup check is gone from memory.

When a downstream system (dashboard, reconciliation tool, support ticket) asks *"the customer mentions LCO #4521 on their receipt — find it on the cloud,"* the answer is a `WHERE id_source = 4521 AND id_location = X` query. That works because we never lose the origin id.

### 2.1 Add a `getLocalSourceEquivalent` finder on `LoyaltyCardOperation`

Mirror the existing pattern from `PaymentLocation::getLocalSourceEquivalent` and `PaymentTerminalTransaction::getLocalSourceEquivalent`. Signature:

```php
public static function getLocalSourceEquivalent(int $source, int $idSource, int $idLocation): self
```

Returns the existing row if `(source, id_source, id_location)` already exists, else an empty instance (`getId() === null`). Same return shape as the other two equivalents so the dedup pattern reads identically.

### 2.2 Dedup before insert in `InboundLoyaltyCardOperationManager::syncOperation`

Add a check at the top, before `LoyaltyCardOperation::create()`:

```php
$alreadySync = LoyaltyCardOperation::getLocalSourceEquivalent(
    $operationData['source'],
    $operationData['idLoyaltyCardOperation'],
    $data['idLocation']
);

if ($alreadySync->getId()) {
    $result->setSuccess(true);
    $result->setMessage('LCO already synced (idempotent skip).');
    $result->setData(['idLoyaltyCardOperation' => $alreadySync->getId()]);
    return $result;
}
```

**Important:** the skip must short-circuit the entire receiver path — no balance touch, no `loyalty_card_operation_product` insert, nothing. The whole `syncOperation` call is a no-op when the source tuple is already known.

### 2.3 No other behavior change

Everything that runs today on first delivery keeps running. The dedup is the only difference. This deliverable touches **no enum, no migration, no other handler.**

---

## 3. Deliverable B — `OPERATION_REVERT` + delta re-application

### 3.1 Enum addition

File: `App/Model/NoDb/Loyalty/LoyaltyCardOperationType.php`

```php
const OPERATION_REVERT = 18;
const OPERATION_REVERT_TXT = 'loyalty_card_operation.type.operation_revert';
```

Add the rendering switch case in `renderType()` (icon suggestion: `rotate-left`; sapiensclient uses the same).

The integer **must** be `18`. Sapiensclient ships with the same constant value.

### 3.2 Back-reference columns on `loyalty_card_transaction`

Migration: add to the cloud's `loyalty_card_transaction` table (matching what sapiensclient is adding to its own table):

```sql
ALTER TABLE loyalty_card_transaction
    ADD COLUMN id_revert_loyalty_card_operation bigint NULL;
ALTER TABLE loyalty_card_transaction
    ADD COLUMN revert_at timestamp with time zone NULL;

CREATE INDEX ON loyalty_card_transaction(id_revert_loyalty_card_operation)
    WHERE id_revert_loyalty_card_operation IS NOT NULL;
```

Model: add getters/setters on `App/Model/Loyalty/LoyaltyCardTransaction.php` for these two columns following the existing convention.

These two columns are the denormalized "this transaction has been refunded" marker. Anyone reading the transaction sees it directly — no JOIN to `loyalty_card_operation` required. The pointer is to the cloud's own LCO id (not the source/NUC id) — the LCO insert in §3.4 gives us that id.

### 3.3 Delta semantics of REVERT

For `type = OPERATION_REVERT`, the LCO's balance fields are **positive deltas to add back** to the card (the customer paid; we're returning their value). Specifically:

- `balanceCredit` — credit to restore (positive)
- `balanceBonus` — bonus to restore (positive)
- `balanceCourtesy` — courtesy to restore (positive)
- `balanceTime` — time to restore in seconds (positive)
- `balanceTicket` — not used for REVERT (tickets aren't part of a transaction's `paidWith`)

Sapiensclient also passes `idSource = originalLoyaltyCardTransaction.id` and includes `detail.previousState` snapshotting the card's pre-revert balances for audit.

### 3.4 Receiver flow for REVERT in `InboundLoyaltyCardOperationManager::syncOperation`

After the universal idempotency check (§2.2) and the LCO insert, branch on type:

```php
if ((int)$operationData['type'] === LoyaltyCardOperationType::OPERATION_REVERT) {
    self::applyRevertSideEffects($loyaltyCardOperation, $operationData, $data['idLocation']);
}
```

`applyRevertSideEffects` does:

1. **Load the cloud card** from `idLoyaltyCardPrimary`. If not found: log + return (treat as orphan; idempotent dedup means we won't loop on it).

2. **Apply the deltas** — same shape as `SellerLoyaltyCardManager::topUpCard`:
   ```php
   $card->setBalanceCredit($card->getBalanceCredit() + $balanceCredit);
   $card->setBalanceBonus($card->getBalanceBonus() + $balanceBonus);
   $card->setBalanceCourtesy($card->getBalanceCourtesy() + $balanceCourtesy);
   $card->setBalanceTime($card->getBalanceTime() + $balanceTime);
   $card->store();
   ```

3. **Update the original transaction back-reference** — resolve the cloud `loyalty_card_transaction` from the original `id_source` field on the LCO payload:
   ```php
   $cloudOriginalTx = LoyaltyCardTransaction::getLocalSourceEquivalent(
       $operationData['source'],
       $operationData['idSource'],
       $data['idLocation']
   );
   if ($cloudOriginalTx->getId()) {
       $cloudOriginalTx->setIdRevertLoyaltyCardOperation($loyaltyCardOperation->getId());
       $cloudOriginalTx->setRevertAt(Helper::getNowServer());
       $cloudOriginalTx->store();
   }
   ```

   Note: `id_revert_loyalty_card_operation` is the **cloud** LCO id (the row we just inserted). Sapiensclient's local copy of the same column points to the local LCO id. Each side points to its own LCO id — that's correct, neither system needs to dereference the other's PKs.

   The lineage trail when you need to bridge: `cloud_tx.id_revert_loyalty_card_operation` → `cloud_lco.id_loyalty_card_operation` → `cloud_lco.id_source` = `client_lco.id_loyalty_card_operation`. The bridge is always `id_source` on the cloud LCO (see §2.0).

4. **Do NOT propagate to other systems beyond what the existing receiver does.** This receiver is responsible only for the cloud's internal state. Anything downstream (analytics, dashboards) reads from the rows we just wrote.

### 3.5 What sapiensclient does NOT send for REVERT

For REVERT specifically, sapiensclient will **not** fire `LoyaltyCardSync` (the absolute-balance sync). The LCO receiver above is the single source of truth for the cloud's card balance update on revert.

If you receive a `LoyaltyCardSync` for a card whose latest activity was a REVERT, it's a code path from another track* method (e.g. the operator did REVERT then immediately a manual ticket adjustment) — handle as today, no special-case logic.

---

## 4. What sapiensclient is doing (for awareness)

Not your scope, but the picture helps:

1. PDA → sapiensclient `POST /api/v1/pda/game-location-operation/create-customer-issue-remediation` with `idLoyaltyCardTransaction` + the chosen resolution.
2. Sapiensclient `LoyaltyCardOperationManager::trackRevert($card, $originalTx, ...)`:
   - Computes positive deltas from `$originalTx`'s `paidWith` breakdown.
   - Creates the local LCO (`type=OPERATION_REVERT`).
   - Updates the local card's balances (adds deltas).
   - Writes the back-reference columns on the local original transaction.
   - Fires **only** `LoyaltyCardOperationSync` (no `LoyaltyCardSync`).
3. Sapiensclient `GameLocationOperationManager` writes the `game_location_operation` row with `resolution_target_type=LOYALTY_CARD_OPERATION`, `id_resolution_target=local LCO id`, then fires `GameLocationOperationSync` (separate cloud guide).

---

## 5. Acceptance checklist

### Deliverable A — Universal idempotency (separable PR)
- [ ] `LoyaltyCardOperation::getLocalSourceEquivalent(int, int, int): self` exists and follows the pattern of `PaymentLocation::getLocalSourceEquivalent` / `PaymentTerminalTransaction::getLocalSourceEquivalent`.
- [ ] `InboundLoyaltyCardOperationManager::syncOperation` calls it before insert; returns success + existing id when found, short-circuits the whole receiver path.
- [ ] Every cloud LCO row written by the receiver populates `id_source` (the client's `idLoyaltyCardOperation`) and `source` / `id_location` — confirm via DB inspection on a freshly synced row that these columns are populated, not just relied on for dedup.
- [ ] Replay test: send the same LCO payload twice. Cloud has exactly one row. No double-insert into `loyalty_card_operation_product`. No extra balance application.
- [ ] PHP lint clean.

### Deliverable B — REVERT + back-reference (depends on A)
- [ ] `LoyaltyCardOperationType::OPERATION_REVERT = 18` constant + TXT + `renderType()` case.
- [ ] Migration adds `id_revert_loyalty_card_operation` + `revert_at` on `loyalty_card_transaction` with index on the first.
- [ ] Model: getters/setters for both new columns on `LoyaltyCardTransaction`.
- [ ] `InboundLoyaltyCardOperationManager::syncOperation` branches on `type == OPERATION_REVERT` after insert and calls `applyRevertSideEffects` (or equivalent private method).
- [ ] Side-effects: card balance delta-add (credit, bonus, courtesy, time), original transaction back-reference write.
- [ ] Replay test: send a REVERT LCO twice. Card balance increases by the deltas exactly once (the second call hits the idempotency skip from Deliverable A). Original transaction back-reference is set once, not overwritten.
- [ ] Missing-card / missing-original-tx cases log + return success (do not 4xx).
- [ ] PHP lint clean.

---

## 6. Out of scope

- Migrating MANUAL_TICKET / REWARD / REPLACE / etc. to delta-application. They keep today's behavior (store-only on receive, balance comes from `LoyaltyCardSync`). When we decide to migrate them, the pattern is already laid out by this guide.
- Changes to `loyalty-card/sync` (absolute-balance sync). Stays as-is.
- PDA endpoint, action list, Android UI — those live entirely on sapiensclient + the app.
