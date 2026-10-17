-- ============================================================
-- BONUS ORIGIN INVESTIGATION: Loyalty Card #616952
-- Where did the 637+ EUR of bonus come from?
-- ============================================================

-- 1. PURCHASES ON THIS CARD - PaymentLocation (top-ups / package purchases)
-- action=1 is LOYALTY_CARD_PACKAGE - this is where bonus gets added via purchase
SELECT
    pl.id_payment_location,
    pl.type,
    pl.status,
    pl.id_location,
    pl.source_created_at,
    pl.created_at,
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
WHERE pl.id_loyalty_card = 616952
ORDER BY pl.created_at;

-- 2. WHAT PACKAGES WERE PURCHASED? Show package details with bonus amounts
SELECT
    pl.id_payment_location,
    pl.source_created_at,
    pl.created_at,
    plt.amount_paid as paid_amount,
    plt.change_amount,
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
WHERE pl.id_loyalty_card = 616952
ORDER BY pl.created_at;

-- 3. TOTAL BONUS LOADED VIA PURCHASES
SELECT
    COUNT(DISTINCT pl.id_payment_location) as nr_purchases,
    SUM(pl.amount) as total_money_paid,
    SUM(CASE WHEN NULLIF(lcp.detail->'setting'->>'credit', '') IS NOT NULL THEN (lcp.detail->'setting'->>'credit')::numeric * pli.quantity ELSE 0 END) as total_credit_loaded,
    SUM(CASE WHEN NULLIF(lcp.detail->'setting'->>'bonus', '') IS NOT NULL THEN (lcp.detail->'setting'->>'bonus')::numeric * pli.quantity ELSE 0 END) as total_bonus_loaded,
    SUM(CASE WHEN NULLIF(lcp.detail->'setting'->>'courtesy', '') IS NOT NULL THEN (lcp.detail->'setting'->>'courtesy')::numeric * pli.quantity ELSE 0 END) as total_courtesy_loaded,
    SUM(CASE WHEN NULLIF(lcp.detail->'setting'->>'ticket', '') IS NOT NULL THEN (lcp.detail->'setting'->>'ticket')::numeric * pli.quantity ELSE 0 END) as total_tickets_loaded
FROM payment_location pl
JOIN payment_location_item pli ON pli.id_payment_location = pl.id_payment_location
LEFT JOIN payment_location_transaction plt ON plt.id_payment_location = pl.id_payment_location
LEFT JOIN loyalty_card_package lcp ON lcp.id_loyalty_card_package = pli.id_action AND pli.action = 1
WHERE pl.id_loyalty_card = 616952
AND pl.type = 1
AND pl.status = 1;

-- 4. PAYMENT METHOD USED for each purchase (cash? card? loyalty?)
SELECT
    pl.id_payment_location,
    pl.source_created_at,
    plt.id_payment_location_transaction,
    plt.amount_paid,
    plt.change_amount,
    plt.payment_method_location,
    plt.status,
    plt.detail::text as transaction_detail
FROM payment_location pl
JOIN payment_location_transaction plt ON plt.id_payment_location = pl.id_payment_location
WHERE pl.id_loyalty_card = 616952
ORDER BY pl.created_at, plt.id_payment_location_transaction;

-- 5. CHECK IF THIS CARD WAS THE TARGET OF JOINS FROM OTHER CARDS
-- (checking via loyalty_card_transaction where another card's balance was transferred)
-- Some systems track joins as transactions, not just operations
SELECT *
FROM loyalty_card_transaction
WHERE id_loyalty_card = 616952
AND action != 1
ORDER BY created_at;

-- 6. CHECK CARD HISTORY IN LOYALTY_CARD itself — was balance modified directly?
SELECT
    lc.id_loyalty_card,
    lc.card_number,
    lc.balance_credit,
    lc.balance_bonus,
    lc.balance_courtesy,
    lc.balance_time,
    lc.balance_ticket,
    lc.status,
    lc.detail::text,
    lc.created_at,
    lc.modified_at
FROM loyalty_card lc
WHERE lc.id_loyalty_card = 616952;

-- 7. CHECK ALL OPERATIONS AGAIN but show the balance BEFORE and AFTER each operation
-- The RESET (type 11) captured previousState - check what was there before reset
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
        ELSE lco.type::text
    END as type_label,
    lco.balance_credit,
    lco.balance_bonus,
    lco.balance_courtesy,
    lco.balance_ticket,
    lco.created_by,
    lco.created_at,
    lco.detail::text
FROM loyalty_card_operation lco
WHERE lco.id_loyalty_card_primary = 616952
ORDER BY lco.created_at;

-- 8. CROSS-CHECK: Were there any OTHER cards with same card_number (replacements)?
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
WHERE lc.card_number = '1717787'
ORDER BY lc.created_at;

-- 9. ANY OPERATIONS where this card was the SECONDARY (meaning it was joined INTO another card, or replaced)
SELECT
    lco.id_loyalty_card_operation,
    lco.type,
    CASE lco.type WHEN 2 THEN 'JOIN' WHEN 3 THEN 'REPLACE' ELSE lco.type::text END as type_label,
    lco.id_loyalty_card_primary as target_card,
    lco.balance_credit,
    lco.balance_bonus,
    lco.balance_courtesy,
    lco.created_by,
    lco.created_at,
    lco.detail::text
FROM loyalty_card_operation lco
WHERE lco.id_loyalty_card_secondary = 616952
ORDER BY lco.created_at;

-- 10. TIER RULES - did the tier give bonus automatically on plays/topups?
SELECT
    lt.id_loyalty_tier,
    lt.name,
    lt.detail::text
FROM loyalty_tier lt
WHERE lt.id_loyalty_tier = 2;
