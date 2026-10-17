-- ============================================================
-- June 2026 Odoo micro-correction v5
-- Absorbs the 24 late-posted Jun-16 Nayax entries (gross 1,305.78,
-- base 1,079.17 / vat 226.61) that landed AFTER the v4 calibration.
-- Applied to a single type-5 move: 5154352 (loc 24, 2026-06-13).
-- Restores June 21% to: base 1,441,338.54 / vat 302,158.90 (= SII exact).
-- ============================================================

BEGIN;

-- counterpart (438000, account 869): debit -1305.78 (+ residuals)
UPDATE account_move_line SET debit=debit-1305.78, balance=balance-1305.78,
       amount_currency=amount_currency-1305.78,
       amount_residual=amount_residual-1305.78,
       amount_residual_currency=amount_residual_currency-1305.78
WHERE move_id=5154352 AND account_id=869;

-- revenue (700000, account 1153): credit -1079.17
UPDATE account_move_line SET credit=credit-1079.17, balance=balance+1079.17,
       amount_currency=amount_currency+1079.17
WHERE move_id=5154352 AND account_id=1153;

-- output VAT (477000, account 896): credit -226.61, tax base follows
UPDATE account_move_line SET credit=credit-226.61, balance=balance+226.61,
       amount_currency=amount_currency+226.61,
       tax_base_amount=tax_base_amount-1079.17
WHERE move_id=5154352 AND account_id=896;

-- move totals
UPDATE account_move SET amount_total=amount_total-1305.78,
       amount_total_signed=amount_total_signed-1305.78,
       amount_total_in_currency_signed=amount_total_in_currency_signed-1305.78
WHERE id=5154352;

-- analytic mirrors (amount = -balance)
UPDATE account_analytic_line SET amount=amount+1305.78
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5154352 AND account_id=869);
UPDATE account_analytic_line SET amount=amount-1079.17
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5154352 AND account_id=1153);
UPDATE account_analytic_line SET amount=amount-226.61
WHERE move_line_id IN (SELECT id FROM account_move_line WHERE move_id=5154352 AND account_id=896);

-- ===== VERIFY =====
-- balances (expect 0 rows):
SELECT move_id, SUM(debit)-SUM(credit) FROM account_move_line
WHERE move_id=5154352 GROUP BY move_id HAVING ABS(SUM(debit)-SUM(credit)) > 0.005;
-- no negative lines (expect 0 rows):
SELECT id, debit, credit FROM account_move_line
WHERE move_id=5154352 AND (debit < -0.005 OR credit < -0.005);
-- residual==balance (expect 0 rows):
SELECT id FROM account_move_line
WHERE move_id=5154352 AND account_id=869 AND ABS(amount_residual-balance) > 0.005;
-- analytic == -balance (expect 0 rows):
SELECT al.id FROM account_analytic_line al
JOIN account_move_line l ON l.id=al.move_line_id
WHERE l.move_id=5154352 AND ABS(al.amount + l.balance) > 0.005;

-- COMMIT only if all four checks return 0 rows; else ROLLBACK
-- COMMIT;
-- ROLLBACK;
