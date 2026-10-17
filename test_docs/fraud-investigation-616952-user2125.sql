-- ============================================================
-- USER 2125 (Yusselith) INVESTIGATION
-- ============================================================

-- 1. ALL OPERATIONS by user 2125 — what has this user been doing across ALL cards?
SELECT
    lco.type,
    CASE lco.type
        WHEN 1 THEN 'REDEEM'
        WHEN 2 THEN 'JOIN'
        WHEN 3 THEN 'REPLACE'
        WHEN 5 THEN 'ACTIVE'
        WHEN 6 THEN 'REWARD'
        WHEN 7 THEN 'TICKET'
        WHEN 11 THEN 'RESET_CARD'
        WHEN 12 THEN 'VOUCHER'
        ELSE lco.type::text
    END as type_label,
    COUNT(*) as nr_operations,
    COUNT(DISTINCT lco.id_loyalty_card_primary) as nr_distinct_cards
FROM loyalty_card_operation lco
WHERE lco.created_by = 2125
GROUP BY lco.type
ORDER BY nr_operations DESC;

-- 2. ALL REDEEM operations by user 2125 vs other users (same period Oct 2025 - Mar 2026)
SELECT
    lco.created_by as user_id,
    COUNT(*) as nr_redeems,
    SUM(lco.balance_ticket) as total_tickets_redeemed,
    COUNT(DISTINCT lco.id_loyalty_card_primary) as nr_distinct_cards,
    MIN(lco.created_at) as first_redeem,
    MAX(lco.created_at) as last_redeem
FROM loyalty_card_operation lco
WHERE lco.type = 1
AND lco.created_at >= '2025-10-01'
AND lco.created_at <= '2026-03-27'
GROUP BY lco.created_by
ORDER BY total_tickets_redeemed DESC;

-- 3. ALL REWARD (ticket redemption) operations by user 2125 vs others (same period)
SELECT
    lco.created_by as user_id,
    COUNT(*) as nr_rewards,
    COUNT(DISTINCT lco.id_loyalty_card_primary) as nr_distinct_cards,
    MIN(lco.created_at) as first_reward,
    MAX(lco.created_at) as last_reward
FROM loyalty_card_operation lco
WHERE lco.type = 6
AND lco.created_at >= '2025-10-01'
AND lco.created_at <= '2026-03-27'
GROUP BY lco.created_by
ORDER BY nr_rewards DESC;

-- 4. USER 2125 REWARD operations detail — which cards, what products, how many tickets
SELECT
    lco.id_loyalty_card_primary as card_id,
    lc.card_number,
    lco.balance_ticket as tickets_after,
    lco.created_at,
    lco.detail::text
FROM loyalty_card_operation lco
LEFT JOIN loyalty_card lc ON lc.id_loyalty_card = lco.id_loyalty_card_primary
WHERE lco.created_by = 2125
AND lco.type = 6
ORDER BY lco.created_at;

-- 5. USER 2125 JOIN operations — did this user join cards?
SELECT
    lco.id_loyalty_card_primary as target_card,
    lco.id_loyalty_card_secondary as source_card,
    lco.balance_credit,
    lco.balance_bonus,
    lco.balance_courtesy,
    lco.balance_ticket,
    lco.created_at,
    lco.detail::text
FROM loyalty_card_operation lco
WHERE lco.created_by = 2125
AND lco.type = 2
ORDER BY lco.created_at;

-- 6. THE 1 EUR CARD PAYMENT — find it in payment_location_transaction
-- Payment location 148106, paid 1 EUR via card (payment_method_location = 2)
-- Who processed it? What time? What device?
SELECT
    pl.id_payment_location,
    pl.id_location,
    pl.id_loyalty_card,
    pl.source_created_at,
    pl.created_at,
    pl.created_by as pl_created_by,
    plt.id_payment_location_transaction,
    plt.amount_paid,
    plt.change_amount,
    plt.payment_method_location,
    plt.source,
    plt.id_source,
    plt.created_by as plt_created_by,
    plt.source_created_at as plt_source_created_at,
    plt.detail::text as plt_detail,
    pl.detail::text as pl_detail
FROM payment_location pl
JOIN payment_location_transaction plt ON plt.id_payment_location = pl.id_payment_location
WHERE pl.id_payment_location = 148106;

-- 7. WHO CREATED the payment_location 148106? Check the created_by
SELECT
    pl.id_payment_location,
    pl.created_by,
    pl.source_created_at,
    pl.detail::text
FROM payment_location pl
WHERE pl.id_payment_location = 148106;

-- 8. WHAT ELSE did the user who created payment 148106 do on that day?
-- First get the created_by from query 7, then use it here
-- For now, check all activity around 2025-05-09 16:58 (the payment time)
SELECT
    pl.id_payment_location,
    pl.id_loyalty_card,
    lc.card_number,
    pl.amount,
    pl.source_created_at,
    pl.created_by,
    pli.action,
    pli.id_action
FROM payment_location pl
JOIN payment_location_item pli ON pli.id_payment_location = pl.id_payment_location
LEFT JOIN loyalty_card lc ON lc.id_loyalty_card = pl.id_loyalty_card
WHERE pl.created_by = (SELECT created_by FROM payment_location WHERE id_payment_location = 148106)
AND pl.source_created_at::date = '2025-05-09'
ORDER BY pl.source_created_at;

-- 9. USER 2125 — all payment_locations created by this user (did they process sales?)
SELECT
    DATE(pl.source_created_at) as sale_date,
    COUNT(*) as nr_sales,
    SUM(pl.amount) as total_amount,
    COUNT(DISTINCT pl.id_loyalty_card) as nr_distinct_cards
FROM payment_location pl
WHERE pl.created_by = 2125
GROUP BY DATE(pl.source_created_at)
ORDER BY sale_date;

-- 10. CARDS that user 2125 interacted with via REWARD — check their bonus patterns
-- Are there other cards like 616952 (high bonus, low credit)?
SELECT
    lc.id_loyalty_card,
    lc.card_number,
    lc.balance_credit,
    lc.balance_bonus,
    lc.balance_courtesy,
    lc.balance_ticket,
    lc.status,
    lc.created_at,
    (SELECT COUNT(*) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lc.id_loyalty_card) as total_transactions,
    (SELECT COALESCE(SUM(pre_credit_amount), 0) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lc.id_loyalty_card) as lifetime_credit_used,
    (SELECT COALESCE(SUM(pre_bonus_amount), 0) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lc.id_loyalty_card) as lifetime_bonus_used
FROM loyalty_card_operation lco
JOIN loyalty_card lc ON lc.id_loyalty_card = lco.id_loyalty_card_primary
WHERE lco.created_by = 2125
AND lco.type = 6
GROUP BY lc.id_loyalty_card, lc.card_number, lc.balance_credit, lc.balance_bonus, lc.balance_courtesy, lc.balance_ticket, lc.status, lc.created_at
ORDER BY lc.balance_bonus DESC;

-- 11. COMPARE user 2125 vs all other users — REWARD ticket totals
-- Who redeems the most tickets overall?
SELECT
    lco.created_by as user_id,
    COUNT(*) as nr_reward_operations,
    COUNT(DISTINCT lco.id_loyalty_card_primary) as nr_distinct_cards
FROM loyalty_card_operation lco
WHERE lco.type = 6
AND lco.created_at >= '2025-01-01'
GROUP BY lco.created_by
ORDER BY nr_reward_operations DESC
LIMIT 20;

-- 12. AROUND THE 1 EUR PAYMENT (2025-05-09 ~16:58) — what was happening at location 20?
-- All payment_locations at location 20 within 1 hour of the suspicious payment
SELECT
    pl.id_payment_location,
    pl.id_loyalty_card,
    lc.card_number,
    pl.amount,
    pl.type,
    pl.status,
    pl.source_created_at,
    pl.created_by,
    pli.action,
    pli.id_action
FROM payment_location pl
JOIN payment_location_item pli ON pli.id_payment_location = pl.id_payment_location
LEFT JOIN loyalty_card lc ON lc.id_loyalty_card = pl.id_loyalty_card
WHERE pl.id_location = 20
AND pl.source_created_at >= '2025-05-09 16:00:00'
AND pl.source_created_at <= '2025-05-09 18:00:00'
ORDER BY pl.source_created_at;
