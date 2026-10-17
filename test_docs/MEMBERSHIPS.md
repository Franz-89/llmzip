# Memberships — assignment (source of truth)

Built 2026-07-24. A **membership** is a `loyalty_tier` with `type = 2`
(`LoyaltyTier::TYPE_MEMBERSHIP`): a **granted** discount profile — never
earned, no threshold, no ladder. Everything downstream already existed before
this feature:

- The card carries it in `loyalty_card.id_membership`, independent from the
  earned `id_loyalty_tier`. **Max ONE membership per card** (locked decision) —
  a new grant replaces the old one.
- `LoyaltyTierDiscountManager::resolveBestPercentForCard` takes the best-of
  (earned tier vs membership) at transaction time on both repos.
- `id_membership` rides the card sync snapshot to the NUC — offline parity is
  free, nothing new syncs.
- Deal-end kill switch: discount resolution skips non-LIVE tiers, so pausing
  the membership (status) disables it everywhere at once.

This feature is the **write path** (nothing assigned memberships before), for
**customer-type users only** — staff/employee memberships (`employee_only`,
`auto_assign`, `min_user_level`, still dormant) will be a separate system.

## Assignment paths

### 1. Direct admin assign — tier detail tabs

`/loyalty-tier/detail/{id}` (Vue island) for an EXISTING membership shows tabs
**Settings | Members | Codes**:

- **Members** — every card carrying the membership
  (`LoyaltyMembershipManager::getListMember`), assign by card number
  (`LoyaltyCard::getOneByCardNumberNOwner`), per-row revoke.
- **Codes** — claim-code CRUD (create / disable, usage counters).

API: `/local/api/v1/loyalty-tier/{id}/member` (GET/POST/DELETE) and
`/{id}/code` (GET/POST/DELETE) in `LoyaltyTierApiController`, membership-type
gated. Island keys are registered in the `loyalty_tier` TranslationBlock.

### 2. Claim codes — the B2B case (BMW: "all your employees get X")

`loyalty_tier_code` (sqlinstall00404): admin-TYPED readable code
(normalized **uppercase A-Z0-9 only, 4–24 chars** — a deal code should
survive being said out loud), `max_use` (0 = unlimited), `nr_use`,
`valid_until`, optional `email_domain`, status active/disabled. An ACTIVE
code is **globally unique** (partial unique index); disabling frees the name.

Claim flow (zero pre-registration):

1. Customer picks up a normal card at the venue, scans its QR → Orbit card
   page (`/card/{track}`), passes the existing possession gate (card number).
2. Enters the code in the membership block → `POST
   /api/v1/card/{track}/membership` (`CardController::membershipClaim`,
   possession-gated via `canView`, NO login required).
3. `LoyaltyMembershipManager::claimByCode` validates (active, not expired,
   uses left, tier LIVE + type + owner match) → stamps `id_membership`,
   bumps `nr_use`, enqueues the card snapshot sync.

**Email-domain codes** are the one case needing an account: the claimer must
be logged in with an email on that domain (`code_needs_account` /
`code_wrong_domain` errors).

The card page shows the active membership label (`buildCardPayload`
`membership` key) instead of the claim form once one is on the card.

## Audit

Every grant/revoke writes `loyalty_card_tier_history` with **`kind = 2`**
(`LoyaltyCardTierHistory::KIND_MEMBERSHIP`; kind 1 = the earned-tier ladder):
`previous_id_loyalty_tier` = old membership (0 = none), `id_loyalty_tier` =
new (0 = revoked), `is_admin`, `comment = 'code:XXXX'` for code claims.

## Deliberately NOT in this slice

- Staff auto-assign (dormant tier fields) — separate future system.
- Per-member expiry — the tier-status kill switch covers deal end.
- A public `/m/{code}` landing page — the code is entered on the card page
  the customer already has open; add the deep link later if deals want a
  scannable poster.
- Event gate enforcement (`eventSetting.idMembership`) — now meaningful,
  still a future wire-up at event card activation.
