-- ============================================================
-- FRAUD INVESTIGATION: Loyalty Card ID 1674522
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
WHERE lc.id_loyalty_card = 1674522;

-- 2. ALL OPERATIONS - Cards joined INTO this card or FROM this card
SELECT
    lco.id_loyalty_card_operation,
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
WHERE lco.id_loyalty_card_primary = 1674522
   OR lco.id_loyalty_card_secondary = 1674522
ORDER BY lco.created_at;

-- 3. ALL SOURCE CARDS joined into 1674522 - what was transferred?
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
LEFT JOIN loyalty_card lc2 ON lc2.id_loyalty_card = lco.id_loyalty_card_secondary
WHERE lco.id_loyalty_card_primary = 1674522
AND lco.type = 2
ORDER BY lco.created_at;

-- 4. TRANSACTION HISTORY - Summary by action type
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
WHERE id_loyalty_card = 1674522
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
WHERE id_loyalty_card = 1674522
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
WHERE id_loyalty_card = 1674522
GROUP BY DATE(created_at)
ORDER BY play_date;

-- 7. WHO PERFORMED THE JOINS? Check if same user does many joins
SELECT
    lco.created_by as user_id,
    COUNT(*) as nr_joins,
    SUM(lco.balance_credit) as total_credit_joined,
    SUM(lco.balance_bonus) as total_bonus_joined,
    SUM(lco.balance_courtesy) as total_courtesy_joined,
    SUM(lco.balance_ticket) as total_ticket_joined,
    MIN(lco.created_at) as first_join,
    MAX(lco.created_at) as last_join
FROM loyalty_card_operation lco
WHERE lco.id_loyalty_card_primary = 1674522
AND lco.type = 2
GROUP BY lco.created_by;

-- 8. SUSPICIOUS PATTERN: Source cards - how many transactions did they have before being joined?
SELECT
    lco.id_loyalty_card_secondary as source_card,
    lc2.card_number,
    lco.balance_credit as credit_at_join,
    lco.balance_bonus as bonus_at_join,
    lco.balance_courtesy as courtesy_at_join,
    lco.balance_ticket as ticket_at_join,
    lco.created_at as join_date,
    (SELECT COUNT(*) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lco.id_loyalty_card_secondary) as source_card_total_transactions,
    (SELECT COUNT(*) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lco.id_loyalty_card_secondary AND action = 1) as source_card_topups,
    lc2.created_at as source_card_created
FROM loyalty_card_operation lco
LEFT JOIN loyalty_card lc2 ON lc2.id_loyalty_card = lco.id_loyalty_card_secondary
WHERE lco.id_loyalty_card_primary = 1674522
AND lco.type = 2
ORDER BY lco.balance_bonus DESC;

-- 9. FULL TIMELINE: Operations and transactions interleaved
(SELECT
    'OPERATION' as event_type,
    CASE type WHEN 1 THEN 'REDEEM' WHEN 2 THEN 'JOIN' WHEN 3 THEN 'REPLACE' WHEN 5 THEN 'ACTIVE' WHEN 6 THEN 'REWARD' WHEN 7 THEN 'TICKET' WHEN 11 THEN 'RESET_CARD' WHEN 12 THEN 'VOUCHER' ELSE type::text END as event_detail,
    balance_credit as amount_credit,
    balance_bonus as amount_bonus,
    balance_courtesy as amount_courtesy,
    balance_ticket as amount_ticket,
    created_by,
    created_at,
    id_loyalty_card_secondary as related_card,
    detail::text
FROM loyalty_card_operation
WHERE id_loyalty_card_primary = 1674522)
UNION ALL
(SELECT
    'TRANSACTION' as event_type,
    'action=' || action as event_detail,
    pre_credit_amount as amount_credit,
    pre_bonus_amount as amount_bonus,
    pre_courtesy_amount as amount_courtesy,
    0 as amount_ticket,
    0 as created_by,
    created_at,
    NULL as related_card,
    detail::text
FROM loyalty_card_transaction
WHERE id_loyalty_card = 1674522)
ORDER BY created_at;

-- 10. PURCHASES ON THIS CARD - PaymentLocation (top-ups / package purchases)
SELECT
    pl.id_payment_location,
    pl.type,
    pl.status,
    pl.id_location,
    pl.amount,
    pl.source_created_at,
    pl.created_at,
    pl.created_by,
    pli.action,
    pli.id_action,
    pli.quantity,
    pli.unit_price,
    pli.subtotal,
    pli.vat_amount,
    pli.total_amount,
    pli.detail::text as item_detail,
    plt.amount_paid as paid_amount,
    plt.change_amount,
    plt.payment_method_location
FROM payment_location pl
JOIN payment_location_item pli ON pli.id_payment_location = pl.id_payment_location
LEFT JOIN payment_location_transaction plt ON plt.id_payment_location = pl.id_payment_location
WHERE pl.id_loyalty_card = 1674522
ORDER BY pl.created_at;

-- 11. WHAT PACKAGES WERE PURCHASED? Show package details with bonus amounts
SELECT
    pl.id_payment_location,
    pl.source_created_at,
    pl.created_at,
    pl.created_by,
    plt.amount_paid as paid_amount,
    plt.payment_method_location,
    pli.action,
    pli.id_action,
    pli.total_amount,
    lcp.id_loyalty_card_package,
    lcp.name as package_name,
    lcp.detail->'setting'->>'credit' as package_credit,
    lcp.detail->'setting'->>'bonus' as package_bonus,
    lcp.detail->'setting'->>'courtesy' as package_courtesy,
    lcp.detail->'setting'->>'ticket' as package_ticket
FROM payment_location pl
JOIN payment_location_item pli ON pli.id_payment_location = pl.id_payment_location
LEFT JOIN payment_location_transaction plt ON plt.id_payment_location = pl.id_payment_location
LEFT JOIN loyalty_card_package lcp ON lcp.id_loyalty_card_package = pli.id_action AND pli.action = 1
WHERE pl.id_loyalty_card = 1674522
ORDER BY pl.created_at;

-- 12. TOTAL MONEY LOADED VIA PURCHASES
SELECT
    COUNT(DISTINCT pl.id_payment_location) as nr_purchases,
    SUM(plt.amount_paid) as total_money_paid,
    SUM(CASE WHEN NULLIF(lcp.detail->'setting'->>'credit', '') IS NOT NULL THEN (lcp.detail->'setting'->>'credit')::numeric * pli.quantity ELSE 0 END) as total_credit_loaded,
    SUM(CASE WHEN NULLIF(lcp.detail->'setting'->>'bonus', '') IS NOT NULL THEN (lcp.detail->'setting'->>'bonus')::numeric * pli.quantity ELSE 0 END) as total_bonus_loaded,
    SUM(CASE WHEN NULLIF(lcp.detail->'setting'->>'courtesy', '') IS NOT NULL THEN (lcp.detail->'setting'->>'courtesy')::numeric * pli.quantity ELSE 0 END) as total_courtesy_loaded,
    SUM(CASE WHEN NULLIF(lcp.detail->'setting'->>'ticket', '') IS NOT NULL THEN (lcp.detail->'setting'->>'ticket')::numeric * pli.quantity ELSE 0 END) as total_tickets_loaded
FROM payment_location pl
JOIN payment_location_item pli ON pli.id_payment_location = pl.id_payment_location
LEFT JOIN payment_location_transaction plt ON plt.id_payment_location = pl.id_payment_location
LEFT JOIN loyalty_card_package lcp ON lcp.id_loyalty_card_package = pli.id_action AND pli.action = 1
WHERE pl.id_loyalty_card = 1674522
AND pl.type = 1
AND pl.status = 1;

-- 13. WAS THIS CARD JOINED INTO ANOTHER CARD? (card as secondary)
SELECT
    lco.id_loyalty_card_operation,
    lco.type,
    CASE lco.type WHEN 2 THEN 'JOIN' WHEN 3 THEN 'REPLACE' ELSE lco.type::text END as type_label,
    lco.id_loyalty_card_primary as target_card,
    lco.balance_credit,
    lco.balance_bonus,
    lco.balance_courtesy,
    lco.balance_ticket,
    lco.created_by,
    lco.created_at,
    lco.detail::text
FROM loyalty_card_operation lco
WHERE lco.id_loyalty_card_secondary = 1674522
ORDER BY lco.created_at;

-- 14. REWARD/REDEEM operations - prize redemptions
SELECT
    lco.id_loyalty_card_operation,
    lco.type,
    CASE lco.type WHEN 1 THEN 'REDEEM' WHEN 6 THEN 'REWARD' ELSE lco.type::text END as type_label,
    lco.balance_credit,
    lco.balance_bonus,
    lco.balance_courtesy,
    lco.balance_ticket,
    lco.created_by,
    lco.created_at,
    lco.detail::text
FROM loyalty_card_operation lco
WHERE lco.id_loyalty_card_primary = 1674522
AND lco.type IN (1, 6)
ORDER BY lco.created_at;

-- 15. CROSS-CHECK: Other cards with same card_number (replacements/duplicates)?
SELECT
    lc.id_loyalty_card,
    lc.card_number,
    lc.balance_credit,
    lc.balance_bonus,
    lc.balance_courtesy,
    lc.balance_ticket,
    lc.status,
    lc.created_at
FROM loyalty_card lc
WHERE lc.card_number = (SELECT card_number FROM loyalty_card WHERE id_loyalty_card = 1674522)
ORDER BY lc.created_at;

-- 16. USERS WHO OPERATED ON THIS CARD - identify all staff involved
SELECT
    lco.created_by as user_id,
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
    MIN(lco.created_at) as first_operation,
    MAX(lco.created_at) as last_operation
FROM loyalty_card_operation lco
WHERE lco.id_loyalty_card_primary = 1674522
GROUP BY lco.created_by, lco.type
ORDER BY lco.created_by, lco.type;

-- ============================================================
-- DEEP CHAIN TRACING: Follow the source cards
-- ============================================================

-- 17. RECURSIVE CHAIN: Find ALL cards in the join chain (up to 5 levels deep)
-- This traces: which cards were joined into 1674522, and which cards were joined into THOSE cards, etc.
WITH RECURSIVE chain AS (
    -- Level 0: cards joined directly into 1674522
    SELECT
        lco.id_loyalty_card_primary as target_card,
        lco.id_loyalty_card_secondary as source_card,
        lco.balance_credit as balance_credit,
        lco.balance_bonus as balance_bonus,
        lco.balance_courtesy as balance_courtesy,
        lco.balance_ticket as balance_ticket,
        lco.created_by as created_by,
        lco.created_at as created_at,
        lco.detail::text as detail,
        1 as depth
    FROM loyalty_card_operation lco
    WHERE lco.id_loyalty_card_primary = 1674522
    AND lco.type = 2

    UNION ALL

    -- Levels 1-4: cards joined into the source cards
    SELECT
        lco.id_loyalty_card_primary as target_card,
        lco.id_loyalty_card_secondary as source_card,
        lco.balance_credit as balance_credit,
        lco.balance_bonus as balance_bonus,
        lco.balance_courtesy as balance_courtesy,
        lco.balance_ticket as balance_ticket,
        lco.created_by as created_by,
        lco.created_at as created_at,
        lco.detail::text as detail,
        c.depth + 1
    FROM loyalty_card_operation lco
    JOIN chain c ON lco.id_loyalty_card_primary = c.source_card
    WHERE lco.type = 2
    AND c.depth < 5
)
SELECT
    chain.depth,
    chain.target_card,
    chain.source_card,
    lc.card_number as source_card_number,
    chain.balance_credit,
    chain.balance_bonus,
    chain.balance_courtesy,
    chain.balance_ticket,
    chain.created_by,
    chain.created_at,
    chain.detail
FROM chain
LEFT JOIN loyalty_card lc ON lc.id_loyalty_card = chain.source_card
ORDER BY chain.depth, chain.created_at;

-- 18. For each SOURCE CARD in the chain: card overview (balance, status, creation)
SELECT
    lc.id_loyalty_card,
    lc.card_number,
    lc.balance_credit,
    lc.balance_bonus,
    lc.balance_courtesy,
    lc.balance_ticket,
    lc.status,
    lc.created_at,
    lc.created_by,
    (SELECT COUNT(*) FROM loyalty_card_operation o WHERE o.id_loyalty_card_primary = lc.id_loyalty_card AND o.type = 2) as nr_joins_received,
    (SELECT COUNT(*) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lc.id_loyalty_card) as nr_transactions,
    (SELECT COUNT(*) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lc.id_loyalty_card AND action = 1) as nr_topups,
    (SELECT COALESCE(SUM(amount), 0) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lc.id_loyalty_card AND action = 1) as total_topup_amount
FROM loyalty_card lc
WHERE lc.id_loyalty_card IN (
    -- All source cards joined directly into 1674522
    SELECT id_loyalty_card_secondary FROM loyalty_card_operation
    WHERE id_loyalty_card_primary = 1674522 AND type = 2
)
ORDER BY lc.created_at;

-- 19. For each DIRECT SOURCE CARD: did it also receive joins? (2nd level feeder cards)
SELECT
    lco_l1.id_loyalty_card_secondary as direct_source_card,
    lc1.card_number as direct_source_card_number,
    lco_l2.id_loyalty_card_secondary as feeder_card,
    lc2.card_number as feeder_card_number,
    lco_l2.balance_credit as feeder_credit,
    lco_l2.balance_bonus as feeder_bonus,
    lco_l2.balance_courtesy as feeder_courtesy,
    lco_l2.balance_ticket as feeder_ticket,
    lco_l2.created_by as feeder_join_by,
    lco_l2.created_at as feeder_join_date,
    (SELECT COUNT(*) FROM loyalty_card_transaction t WHERE t.id_loyalty_card = lco_l2.id_loyalty_card_secondary) as feeder_total_transactions
FROM loyalty_card_operation lco_l1
JOIN loyalty_card_operation lco_l2 ON lco_l2.id_loyalty_card_primary = lco_l1.id_loyalty_card_secondary AND lco_l2.type = 2
LEFT JOIN loyalty_card lc1 ON lc1.id_loyalty_card = lco_l1.id_loyalty_card_secondary
LEFT JOIN loyalty_card lc2 ON lc2.id_loyalty_card = lco_l2.id_loyalty_card_secondary
WHERE lco_l1.id_loyalty_card_primary = 1674522
AND lco_l1.type = 2
ORDER BY lco_l1.id_loyalty_card_secondary, lco_l2.created_at;

-- 20. FULL CHAIN SUMMARY: Total bonus/credit/tickets flowing into 1674522 from ALL levels
WITH RECURSIVE chain AS (
    SELECT
        lco.id_loyalty_card_secondary as source_card,
        lco.balance_credit as balance_credit,
        lco.balance_bonus as balance_bonus,
        lco.balance_courtesy as balance_courtesy,
        lco.balance_ticket as balance_ticket,
        1 as depth
    FROM loyalty_card_operation lco
    WHERE lco.id_loyalty_card_primary = 1674522
    AND lco.type = 2

    UNION ALL

    SELECT
        lco.id_loyalty_card_secondary,
        lco.balance_credit as balance_credit,
        lco.balance_bonus as balance_bonus,
        lco.balance_courtesy as balance_courtesy,
        lco.balance_ticket as balance_ticket,
        c.depth + 1
    FROM loyalty_card_operation lco
    JOIN chain c ON lco.id_loyalty_card_primary = c.source_card
    WHERE lco.type = 2
    AND c.depth < 5
)
SELECT
    depth as chain_level,
    COUNT(*) as nr_joins,
    COUNT(DISTINCT source_card) as nr_unique_source_cards,
    SUM(balance_credit) as total_credit,
    SUM(balance_bonus) as total_bonus,
    SUM(balance_courtesy) as total_courtesy,
    SUM(balance_ticket) as total_ticket
FROM chain
GROUP BY depth
ORDER BY depth;

-- 21. ALL STAFF across the entire chain - who touched any card in the network?
WITH RECURSIVE chain AS (
    SELECT 1674522::bigint as card_id, 0 as depth
    UNION ALL
    SELECT lco.id_loyalty_card_secondary, c.depth + 1
    FROM loyalty_card_operation lco
    JOIN chain c ON lco.id_loyalty_card_primary = c.card_id
    WHERE lco.type = 2 AND c.depth < 5
)
SELECT
    lco.created_by as user_id,
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
    COUNT(DISTINCT lco.id_loyalty_card_primary) as nr_distinct_cards,
    MIN(lco.created_at) as first_operation,
    MAX(lco.created_at) as last_operation
FROM loyalty_card_operation lco
WHERE lco.id_loyalty_card_primary IN (SELECT card_id FROM chain)
GROUP BY lco.created_by, lco.type
ORDER BY nr_operations DESC;
