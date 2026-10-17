-- ============================================================
-- FRAUD INVESTIGATION: Loyalty Card ID 616952
-- ============================================================

-- 1. CARD OVERVIEW - Current state of the card
SELECT
    lc.id_loyalty_card,
    lc.card_number,
    lc.balance_credit,
    lc.balance_bonus,
    lc.balance_courtesy,
    lc.balance_time,
    lc.balance_ticket,
    lc.status,
    lc.created_at,
    lc.created_by
FROM loyalty_card lc
WHERE lc.id_loyalty_card = 616952;

-- 2. ALL JOIN OPERATIONS - Cards joined INTO this card or FROM this card
SELECT
    lco.id_loyalty_card_operation,
    lco.type,
    CASE lco.type
        WHEN 2 THEN 'JOIN'
        WHEN 3 THEN 'REPLACE'
        WHEN 6 THEN 'REWARD'
        ELSE lco.type::text
    END as type_label,
    lco.id_loyalty_card_primary,
    lco.id_loyalty_card_secondary,
    lco.balance_credit,
    lco.balance_bonus,
    lco.balance_courtesy,
    lco.balance_time,
    lco.balance_ticket,
    lco.status,
    lco.created_by,
    lco.created_at,
    lco.source_created_at,
    lco.detail::text
FROM loyalty_card_operation lco
WHERE lco.id_loyalty_card_primary = 616952
   OR lco.id_loyalty_card_secondary = 616952
ORDER BY lco.created_at;

-- 3. ALL SOURCE CARDS that were joined into 616952 - what was their balance before join?
SELECT
    lco.id_loyalty_card_secondary as joined_from_card,
    lco.balance_credit as credit_transferred,
    lco.balance_bonus as bonus_transferred,
    lco.balance_courtesy as courtesy_transferred,
    lco.balance_time as time_transferred,
    lco.balance_ticket as ticket_transferred,
    lco.created_at as join_date,
    lco.created_by as done_by_user,
    lc2.card_number as source_card_number,
    lc2.created_at as source_card_created_at,
    lc2.status as source_card_status
FROM loyalty_card_operation lco
LEFT JOIN loyalty_card lc2 ON lc2.id_loyalty_card_primary = lco.id_loyalty_card_secondary
WHERE lco.id_loyalty_card_primary = 616952

ORDER BY lco.created_at;

-- 4. TRANSACTION HISTORY - What was this card used for? Focus on balance types
SELECT
    action,
    COUNT(*) as nr_transactions,
    COALESCE(SUM(amount), 0) as total_amount,
    COALESCE(SUM(pre_credit_amount), 0) as total_credit_used,
    COALESCE(SUM(pre_bonus_amount), 0) as total_bonus_used,
    COALESCE(SUM(pre_courtesy_amount), 0) as total_courtesy_used,
    COALESCE(SUM(pre_time_second), 0) as total_time_used,
    MIN(created_at) as first_transaction,
    MAX(created_at) as last_transaction
FROM loyalty_card_transaction
WHERE id_loyalty_card = 616952
GROUP BY action
ORDER BY action;

-- 5. TOPUP HISTORY - How much real money was put on this card?
SELECT
    id_loyalty_card_transaction,
    amount,
    pre_credit_amount,
    pre_bonus_amount,
    pre_courtesy_amount,
    id_location,
    created_at,
    detail::text
FROM loyalty_card_transaction
WHERE id_loyalty_card = 616952
AND action = 1
ORDER BY created_at;

-- 6. DAILY PLAY PATTERN - Show usage over time
SELECT
    DATE(created_at) as play_date,
    COUNT(*) as plays,
    SUM(amount) as total_spent,
    SUM(pre_credit_amount) as credit_used,
    SUM(pre_bonus_amount) as bonus_used,
    SUM(pre_courtesy_amount) as courtesy_used
FROM loyalty_card_transaction
WHERE id_loyalty_card = 616952
GROUP BY DATE(created_at)
ORDER BY play_date;

-- 7. WHO PERFORMED THE JOINS? Check if same user does many joins
SELECT
    lco.created_by as user_id,
    COUNT(*) as nr_joins,
    SUM(lco.balance_credit) as total_credit_joined,
    SUM(lco.balance_bonus) as total_bonus_joined,
    SUM(lco.balance_courtesy) as total_courtesy_joined,
    MIN(lco.created_at) as first_join,
    MAX(lco.created_at) as last_join
FROM loyalty_card_operation lco
WHERE lco.id_loyalty_card_primary = 616952
AND lco.type = 2
GROUP BY lco.created_by;

-- 8. SUSPICIOUS PATTERN: Cards joined that had ONLY bonus (never played = tourist abandoned cards)
SELECT
    lco.id_loyalty_card_secondary as source_card,
    lc2.card_number,
    lco.balance_credit as credit_at_join,
    lco.balance_bonus as bonus_at_join,
    lco.balance_courtesy as courtesy_at_join,
    lco.created_at as join_date,
    (SELECT COUNT(*) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lco.id_loyalty_card_secondary) as source_card_total_transactions,
    (SELECT COUNT(*) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lco.id_loyalty_card_secondary AND action = 1) as source_card_plays,
    lc2.created_at as source_card_created
FROM loyalty_card_operation lco
LEFT JOIN loyalty_card lc2 ON lc2.id_loyalty_card = lco.id_loyalty_card_secondary
WHERE lco.id_loyalty_card_primary = 616952
AND lco.type = 2
ORDER BY lco.balance_bonus DESC;

-- 9. FULL TIMELINE: Operations and transactions interleaved
(SELECT
    'OPERATION' as event_type,
    CASE type WHEN 2 THEN 'JOIN' WHEN 3 THEN 'REPLACE' WHEN 6 THEN 'REWARD' ELSE type::text END as event_detail,
    balance_credit as amount_credit,
    balance_bonus as amount_bonus,
    balance_courtesy as amount_courtesy,
    created_by,
    created_at,
    id_loyalty_card_secondary as related_card
FROM loyalty_card_operation
WHERE id_loyalty_card_primary = 616952)
UNION ALL
(SELECT
    'TRANSACTION' as event_type,
    'action=' || action as event_detail,
    pre_credit_amount as amount_credit,
    pre_bonus_amount as amount_bonus,
    pre_courtesy_amount as amount_courtesy,
    0 as created_by,
    created_at,
    NULL as related_card
FROM loyalty_card_transaction
WHERE id_loyalty_card = 616952)
ORDER BY created_at;
