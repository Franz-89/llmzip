-- ============================================================
-- June 2026 Odoo micro-correction v6: close the 10% residual
-- Target: Odoo 10% = SII exact (78,551.62 base / 7,845.23 VAT)
--   Part A: move 5313878 (type-2, loc 199, ~Jun 20): rate reclass
--           10% -> 21%, gross 137.10 (base 124.63 + vat 12.47 out;
--           base 113.31 + vat 23.79 in). Move balanced, cash/card
--           counterpart lines (acct 849) untouched.
--   Part B: move 5154352 (type-5, loc 24, Jun 13): remove 137.10
--           gross at 21% against the advance account, so 21%
--           stays matched (net 21% change = 0).
-- End state: 10% = SII to the cent, 21% unchanged, total -137.10
-- via the non-reconciled advance account (same route as v4/v5).
-- ============================================================

-- ===== STEP 0: pre-flight (expect the current values; abort if different) =====
-- 5313878 lines: 1153/'10.00 %' credit=1176.17, 896/'10.00 %' credit=117.63 tax_base=1176.17,
--                1153/'21.00 %' credit=1789.82, 896/'21.00 %' credit=375.48 tax_base=1789.82
SELECT id, account_id, name, credit, tax_base_amount FROM account_move_line
WHERE move_id = 5313878 AND account_id IN (896, 1153);
-- 5154352 headroom: 1153 credit >= 113.31, 896 credit >= 23.79, 869 debit >= 137.10
SELECT id, account_id, debit, credit FROM account_move_line WHERE move_id = 5154352;

-- ===== STEP 1: BACKUP =====
CREATE TABLE backup_v6_move_20260729 AS
    SELECT * FROM account_move WHERE id IN (5313878, 5154352);
CREATE TABLE backup_v6_move_line_20260729 AS
    SELECT * FROM account_move_line WHERE move_id IN (5313878, 5154352);
CREATE TABLE backup_v6_analytic_20260729 AS
    SELECT * FROM account_analytic_line
    WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id IN (5313878, 5154352));

-- ===== STEP 2: TRANSACTION =====
BEGIN;

-- ---- Part A: 5313878 rate reclass (gross-neutral) ----
UPDATE account_move_line SET credit=credit-124.63, balance=balance+124.63, amount_currency=amount_currency+124.63
WHERE move_id=5313878 AND account_id=1153 AND name='10.00 %';
UPDATE account_move_line SET credit=credit-12.47, balance=balance+12.47, amount_currency=amount_currency+12.47, tax_base_amount=tax_base_amount-124.63
WHERE move_id=5313878 AND account_id=896 AND name='10.00 %';
UPDATE account_move_line SET credit=credit+113.31, balance=balance-113.31, amount_currency=amount_currency-113.31
WHERE move_id=5313878 AND account_id=1153 AND name='21.00 %';
UPDATE account_move_line SET credit=credit+23.79, balance=balance-23.79, amount_currency=amount_currency-23.79, tax_base_amount=tax_base_amount+113.31
WHERE move_id=5313878 AND account_id=896 AND name='21.00 %';

-- analytic mirrors (amount = -balance)
UPDATE account_analytic_line SET amount=amount-124.63
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5313878 AND account_id=1153 AND name='10.00 %');
UPDATE account_analytic_line SET amount=amount-12.47
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5313878 AND account_id=896 AND name='10.00 %');
UPDATE account_analytic_line SET amount=amount+113.31
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5313878 AND account_id=1153 AND name='21.00 %');
UPDATE account_analytic_line SET amount=amount+23.79
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5313878 AND account_id=896 AND name='21.00 %');

-- ---- Part B: 5154352 remove 137.10 gross at 21% ----
UPDATE account_move_line SET debit=debit-137.10, balance=balance-137.10, amount_currency=amount_currency-137.10,
       amount_residual=amount_residual-137.10, amount_residual_currency=amount_residual_currency-137.10
WHERE move_id=5154352 AND account_id=869;
UPDATE account_move_line SET credit=credit-113.31, balance=balance+113.31, amount_currency=amount_currency+113.31
WHERE move_id=5154352 AND account_id=1153;
UPDATE account_move_line SET credit=credit-23.79, balance=balance+23.79, amount_currency=amount_currency+23.79, tax_base_amount=tax_base_amount-113.31
WHERE move_id=5154352 AND account_id=896;
UPDATE account_move SET amount_total=amount_total-137.10, amount_total_signed=amount_total_signed-137.10,
       amount_total_in_currency_signed=amount_total_in_currency_signed-137.10
WHERE id=5154352;

-- analytic mirrors
UPDATE account_analytic_line SET amount=amount+137.10
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5154352 AND account_id=869);
UPDATE account_analytic_line SET amount=amount-113.31
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5154352 AND account_id=1153);
UPDATE account_analytic_line SET amount=amount-23.79
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5154352 AND account_id=896);

-- ===== STEP 3: VERIFY (all must return 0 rows except 3d) =====
-- 3a. both moves still balance:
SELECT move_id, SUM(debit)-SUM(credit) FROM account_move_line
WHERE move_id IN (5313878, 5154352) GROUP BY move_id HAVING ABS(SUM(debit)-SUM(credit)) > 0.005;
-- 3b. no negative lines:
SELECT id, move_id, debit, credit FROM account_move_line
WHERE move_id IN (5313878, 5154352) AND (debit < -0.005 OR credit < -0.005);
-- 3c. analytic == -balance on every touched line:
SELECT al.id FROM account_analytic_line al
JOIN account_move_line l ON l.id = al.move_line_id
WHERE l.move_id IN (5313878, 5154352) AND ABS(al.amount + l.balance) > 0.005;
-- 3d. host gross unchanged (expect ONE row, diff = 0.00):
SELECT ROUND(SUM(l.credit) - SUM(bk.credit), 2) AS host_credit_diff
FROM account_move_line l JOIN backup_v6_move_line_20260729 bk ON bk.id = l.id
WHERE l.move_id = 5313878;
-- 3e. residual==balance on the advance line:
SELECT id FROM account_move_line
WHERE move_id = 5154352 AND account_id = 869 AND ABS(amount_residual - balance) > 0.005;

-- ===== STEP 4: COMMIT if 3a/3b/3c/3e empty and 3d = 0.00; else ROLLBACK =====
-- COMMIT;
-- ROLLBACK;
