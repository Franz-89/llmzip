-- ============================================================
-- July 2026 Odoo correction — PHASE 1: diagnostic / generator queries
--
-- Context: Odoo type-5 (loyalty card usage) entries allocated BEFORE the
-- 2026-07-24 fix (commit 14f56ab3f, deployed with that night's release)
-- included action=3 LCTs (counter sales paid with card credit) whose VAT
-- is ALSO booked in the type-3 entries -> Odoo double-count. SII is fine.
-- Business days >= 2026-07-23 were allocated post-fix (D-2 cron) = clean
-- by construction; the detector below verifies per entry instead of
-- trusting the date, because the posting backlog / late allocations can
-- flip individual days either way.
--
-- Recipe (June playbook, docs/odoo_june_correction_v4.sql), differences:
--   * NO online-phantom absorption -> remove the FULL action-3 amount
--     (June under-removed x0.945; July removal is exact).
--   * Removal recomputed as "allocator on the clean set": per dirty move
--     new_vat = round(usage - usage/(1+rate/100), 2), new_base = usage - new_vat,
--     deltas = old stored values - new values (uses the entry's own vatRate).
--   * Batch B (type-3 10% -> 21% reclass) still applies for Jul 1-22:
--     SII-as-filed declared the card-spend at flat 21% via t5, so Odoo's
--     t3 10% lines must reclass to 21% to match the filing, like June.
--
-- Run CORE queries on the sapienscore production Postgres,
-- ODOO queries on the Odoo Postgres. Save each result as CSV in docs/tr/
-- (suggested names in each section). Then I generate
-- docs/odoo_july_correction.sql from them.
-- ============================================================


-- ############################################################
-- CORE DB
-- ############################################################

-- ===== C0: total July exposure for org 1 (headline number) =====
-- Scope decision: ONLY id_organization = 1 is corrected (like June).
-- save as docs/tr/july-c0.csv
SELECT ROUND(SUM(t.final_credit_vat_postponed_amount)::numeric, 2) AS action3_postponed_july,
       COUNT(*) AS n_lct
FROM loyalty_card_transaction t
JOIN location_ l ON l.id_location = t.id_location
WHERE l.id_organization = 1
  AND t.status = 2                       -- LoyaltyCardTransactionEngine::STATUS_CONFIRMED
  AND t.action = 3                       -- ACTION_PAYMENT_LOCATION
  AND t.final_credit_vat_postponed_amount > 0
  AND t.created_at >= '2026-07-01 00:00:00+02'
  AND t.created_at <  '2026-08-01 00:00:00+02';


-- ===== C1: type-5 dirty-entry detector + Batch A generator input =====
-- One row per July type-5 odoo_journal_entry (org 1), with the LCT sums
-- recomputed both ways. verdict:
--   DIRTY   entry total == full sum incl action-3  -> needs correction
--   clean   entry total == usage-only sum          -> already correct
--   MISMATCH-> neither matches: investigate (if systematic, day-bucketing
--             is off — re-run with created_at::date UTC bucketing instead
--             of the Madrid-local bucketing below)
-- save as docs/tr/july-c1.csv
WITH lct AS (
    SELECT t.id_location,
           (t.created_at AT TIME ZONE 'Europe/Madrid')::date AS d,
           ROUND(SUM(t.final_credit_vat_postponed_amount)::numeric, 2) AS total_all,
           ROUND(COALESCE(SUM(t.final_credit_vat_postponed_amount) FILTER (WHERE t.action <> 3), 0)::numeric, 2) AS total_usage,
           ROUND(COALESCE(SUM(t.final_credit_vat_postponed_amount) FILTER (WHERE t.action = 3), 0)::numeric, 2) AS total_action3,
           COUNT(*) FILTER (WHERE t.action = 3) AS n_action3
    FROM loyalty_card_transaction t
    JOIN location_ loc ON loc.id_location = t.id_location AND loc.id_organization = 1
    WHERE t.status = 2
      AND t.final_credit_vat_postponed_amount > 0
      AND t.created_at >= '2026-07-01 00:00:00+02'
      AND t.created_at <  '2026-08-01 00:00:00+02'
    GROUP BY 1, 2
)
SELECT e.id_odoo_journal_entry,
       e.id_location,
       e.from_date::date AS day,
       e.odoo_id,
       e.status,
       (e.detail::jsonb->'allocationInfo'->>'totalAmount')::numeric      AS entry_total,
       (e.detail::jsonb->'allocationInfo'->>'baseAmount')::numeric       AS entry_base,
       (e.detail::jsonb->'allocationInfo'->>'vatAmount')::numeric        AS entry_vat,
       (e.detail::jsonb->'allocationInfo'->>'vatRate')::numeric          AS entry_vat_rate,
       (e.detail::jsonb->'allocationInfo'->>'transactionCount')::int     AS entry_count,
       l.total_all, l.total_usage, l.total_action3, l.n_action3,
       CASE
           WHEN COALESCE(l.total_action3, 0) = 0 THEN 'no-action3'
           WHEN ABS((e.detail::jsonb->'allocationInfo'->>'totalAmount')::numeric - l.total_all)   <= 0.02 THEN 'DIRTY'
           WHEN ABS((e.detail::jsonb->'allocationInfo'->>'totalAmount')::numeric - l.total_usage) <= 0.02 THEN 'clean'
           ELSE 'MISMATCH'
       END AS verdict
FROM odoo_journal_entry e
LEFT JOIN lct l ON l.id_location = e.id_location AND l.d = e.from_date::date
WHERE e.type = 5                          -- OdooJournalEntry::TYPE_LOYALTY_CARD_USAGE
  AND e.id_organization = 1
  AND e.from_date >= '2026-07-01' AND e.from_date < '2026-08-01'
ORDER BY e.from_date, e.id_location;
-- NOTE rows with verdict=DIRTY and odoo_id IS NULL (never posted): those are
-- NOT corrected in Odoo — cleanest fix is delete the core entry + re-allocate
-- with the fixed code. List them separately in your reply if any.


-- ===== C2: July pre-cutover type-3 entries (Batch B input: 10%->21% reclass) =====
-- save as docs/tr/july-c2.csv
SELECT e.id_odoo_journal_entry,
       e.id_location,
       e.from_date::date AS day,
       e.odoo_id,
       e.status,
       e.detail::jsonb->'allocationInfo' AS allocation_info
FROM odoo_journal_entry e
WHERE e.type = 3                          -- TYPE_LOYALTY_CARD_PAYMENT
  AND e.id_organization = 1
  AND e.from_date >= '2026-07-01' AND e.from_date < '2026-07-23'
ORDER BY e.from_date, e.id_location;


-- ===== C3: SII-as-filed July per-day totals (verification target) =====
-- t5 Jul 1-22 should ~= lct total_all per day (flat default rate);
-- from Jul 23 t5 ~= total_usage and t2 grows by the card-paid sales.
-- save as docs/tr/july-c3.csv
SELECT (s.detail::jsonb->'siiDetail'->>'issueDate') AS issue_date,
       s.type,
       s.schedule_status,
       ROUND(SUM((s.detail::jsonb->'siiDetail'->>'totalAmount')::numeric), 2) AS total,
       COUNT(*) AS n
FROM sii_schedule s
WHERE s.status = 1                        -- active (not soft-deleted)
  AND s.id_organization = 1
  AND s.type IN (2, 5)
  AND (s.detail::jsonb->'siiDetail'->>'issueDate') >= '2026-07-01'
  AND (s.detail::jsonb->'siiDetail'->>'issueDate') <  '2026-08-01'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
-- How C3 is used (SII = the reference, it was filed correctly):
--   * rows with schedule_status <> 3 (sent) are NOT "as-filed" — if any July
--     t2/t5 rows are still pending/error, flag them before correcting Odoo.
--   * expected cutover signature in the data: t5 per-day drops and t2 jumps
--     around issue_date 2026-07-23 (card-paid sales moved from t5 to t2).
--   * final verification identity per VAT rate for July after correction:
--     SII(t2 + t5) == Odoo(t2 + t3 + t5), with t5-vs-t5 differing by the
--     till-spend (in SII t5, in Odoo t3) — by design.


-- ===== C3b: SII-as-filed July per VAT RATE (the correction TARGET) =====
-- Expands siiDetail.listVatAmountVatRateBased (rate => vatAmount/vatBaseAmount,
-- built by SiiPaymentManager::addValueToListVatAmount). This is the per-rate
-- as-filed truth Odoo must match after batches A+B (June's to-the-cent method).
-- schedule_status = 3 only: sent rows ARE the filing.
-- save as docs/tr/july-c3b.csv
SELECT (s.detail::jsonb->'siiDetail'->>'issueDate') AS issue_date,
       s.type,
       r.key AS vat_rate,
       ROUND(SUM((r.value->>'vatBaseAmount')::numeric), 2) AS base,
       ROUND(SUM((r.value->>'vatAmount')::numeric), 2) AS vat,
       COUNT(*) AS n
FROM sii_schedule s,
     jsonb_each(s.detail::jsonb->'siiDetail'->'listVatAmountVatRateBased') r
WHERE s.status = 1
  AND s.id_organization = 1
  AND s.schedule_status = 3
  AND s.type IN (2, 5)
  AND (s.detail::jsonb->'siiDetail'->>'issueDate') >= '2026-07-01'
  AND (s.detail::jsonb->'siiDetail'->>'issueDate') <  '2026-08-01'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;


-- ############################################################
-- ODOO DB  (run AFTER C1/C2 — paste the odoo_id lists from the CSVs)
-- ############################################################

-- ===== O1: dirty type-5 moves — line shape + preconditions =====
-- :DIRTY_T5_MOVE_IDS = odoo_id of every C1 row with verdict=DIRTY and odoo_id set
-- Expect per move: 1 debit line acct 869 (advance), credit lines 1153 (revenue)
-- + 896 (VAT). Flag anything with reconcile links or inalterable hash.
-- save as docs/tr/july-o1.csv
SELECT l.move_id, l.id AS line_id, l.account_id, l.name,
       l.debit, l.credit, l.balance, l.tax_base_amount,
       l.amount_residual, l.full_reconcile_id,
       (SELECT COUNT(*) FROM account_analytic_line al WHERE al.move_line_id = l.id) AS analytic_rows
FROM account_move_line l
WHERE l.move_id IN (/* :DIRTY_T5_MOVE_IDS */)
ORDER BY l.move_id, l.account_id;

-- O1b: precondition violations (expect 0 rows)
SELECT m.id, m.state, m.inalterable_hash
FROM account_move m
WHERE m.id IN (/* :DIRTY_T5_MOVE_IDS */)
  AND (m.state <> 'posted' OR m.inalterable_hash IS NOT NULL);


-- ===== O2: type-3 moves — 10% and 21% revenue/VAT lines (Batch B input) =====
-- :T3_MOVE_IDS = odoo_id of every C2 row with odoo_id set
-- save as docs/tr/july-o2.csv
SELECT l.move_id, l.id AS line_id, l.account_id, l.name,
       l.debit, l.credit, l.balance, l.tax_base_amount,
       (SELECT COUNT(*) FROM account_analytic_line al WHERE al.move_line_id = l.id) AS analytic_rows
FROM account_move_line l
WHERE l.move_id IN (/* :T3_MOVE_IDS */)
  AND l.account_id IN (1153, 896)         -- 700000 revenue / 477000 VAT
  AND l.name IN ('10.00 %', '21.00 %')
ORDER BY l.move_id, l.account_id, l.name;
-- Moves with ONLY 10% lines (no 21% host line) get the June treatment:
-- excluded from in-move reclass, residual closed on a separate host move (v6 style).


-- ============================================================
-- Known crumbs — recognize, do not re-investigate:
--  * ~EUR 267.55 of June Nayax entries were auto re-dated by Odoo to
--    2026-07-31 (SII carries them in June) -> expected July Odoo>SII crumb.
--  * Online top-ups completed within ~2 days before the 2026-07-25 deploy
--    of the type-7 filter may have been double-declared by pre-filter
--    type-7 runs (micro-cleanup, check Jul 22-24 type-7 vs type-12 overlap).
-- ============================================================
