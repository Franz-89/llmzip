# Membership — early notes (separate workstream)

Status: **concept notes** for a future feature, captured so a separate agent can pick it up.
Not designed in detail, not built. Related to — but distinct from — Tiers and Dynamic Pricing
(`/DYNAMIC_PRICING.md`).

## What it is

Membership is a broader view on Tiers. Where a **Tier** is an automatic loyalty level earned by
cumulative spend (a flat % discount applied at transaction), a **Membership** is an
operator-defined identity group with its own perks, used **instead of / alongside** tiers.

Examples the operator wants to express:
- **Employee** — 10% on coffee; or the first coffee of the day free; AND a discount on games when
  they play with their personal card *as if they were a customer*.
- **Partner deal** — a deal with a nearby car company: their employees get an extra 5% on whatever.

So a membership can carry **multiple, heterogeneous perks** (per-product %, free-item-per-day,
game-play discount), not just a single global %.

## Relationship to the pricing engine

To the price-resolution engine, Tier and Membership are the **same kind of thing**: an
**identity-based modifier applied at transaction time by the card-holder's identity**. The engine
must treat identity modifiers as a pluggable set — **tier must not be hard-coded as the only one.**

Key requirement already baked into the pricing design:
- Each identity modifier carries **operator-controlled applicability**, decided per membership:
  - does it apply to **deterministic** prices?
  - does it apply to **behavioural** prices? (a business decision — e.g. should "employee 10%"
    stack on top of an idle −50%? the operator decides per membership.)
- This is why `pricing_rule` exposes an "applies?" flag for identity modifiers rather than assuming
  tier.

## Open questions for the membership workstream

- Data model: `membership` + `membership_member` (card/user link) + per-membership perk list
  (product-scoped %, free-item rules, game-play discount). Reuse the scope-selector vocabulary
  (`SELECTOR_*`) where perks are scoped to products/games?
- Stacking rules: tier + membership + behavioural — order and caps. (Guardrails still clamp.)
- Eligibility: how a card/user is assigned a membership (manual, partner import, employee roster).
- Public/POS surfacing: like tiers, perks should be **shown on the terminal**, not a surprise.
- Reporting: membership-attributed discounts join the same `pricing_change_event` / transaction
  reporting so uplift and cost are measurable.

## Do-not-preclude checklist for the pricing build

- [ ] Identity-modifier layer is a set, not a single tier hook.
- [ ] Per-modifier "applies to deterministic / behavioural" applicability flags exist.
- [ ] Guardrails clamp the final price regardless of how many modifiers stacked.
- [ ] Terminal display can render more than the fixed base/VIP/Platinum rows.
