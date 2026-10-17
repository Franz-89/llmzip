# Behavioural (signal-driven) pricing — parked design notes

**Status: PARKED (2026-06-29). Nothing built.** This is the starting point for when we
come back. Read it before re-opening the topic — we already worked through the traps.

---

## Where it fits

The pricing engine has two layers by design:

- **ABSOLUTE / deterministic** — clock-driven (weekday, time-band, date-range, holiday,
  specific-date). **Built.** Resolves at read-time; fully previewable on a calendar.
- **RELATIVE / behavioural** — driven by a **live signal**, not the clock. **Not built.**

Behavioural rules are just rules whose trigger is a signal. `RuleCondition` already reserves
`CONDITION_IDLE = 20` and `CONDITION_OFF_PEAK = 21`.

---

## Why we did NOT build the simple "idle" version

"No play for 30 min → discount" overlaps heavily with what already exists: a clock off-peak
rule, plus operators already know their chronically dead machines and can target them by hand.
Its marginal value over the shipped feature set is low — it would probably go unused. We
agreed to skip absolute time-idle.

---

## The safe lifecycle model (designed — reuse it for whatever signal we pick)

A naive "idle → cheap, played → revert" toggle **flaps** and is dangerous (prices bounce on
every touch; a customer sees €2 and pays €4). Never build that. Instead, a behavioural discount
is a **window with hysteresis**:

- **Trigger** — signal crosses a threshold (e.g. idle ≥ N min). For idle: **hard floor 5 min,
  default 30**.
- **Hold** — once fired, the discount holds for an operator-set **duration (min 5 min)**,
  *regardless of plays*. A play does **not** revert it. It's "revive a dead machine for a
  burst", not "bait one fish".
- **Settle gap (the key fairness guard)** — **a price never rises on an active machine.** Any
  *increase* (including the window reverting to full price) waits for a **quiet gap (default
  2 min, enforced)** with no play, so the hike always lands in a dead moment. Every play resets
  the timer. *Decreases* apply instantly (only good news for the customer).
- **Cooldown** — after revert, a gap before it can fire again.
- **Max firings/day** — anti-gaming bound, so regulars can't just wait it out.
- Plus: the **guardrail floor** still clamps, and a behavioural condition can be **AND-ed with
  clock conditions** (e.g. off-peak hours only) so it never fires at peak.

**Accepted tradeoff:** a *continuously* busy machine stays discounted past its nominal window
(it only reverts once it goes quiet for the settle gap). Usually fine — busy = a volume win —
and it self-corrects when plays stop. Add a hard "max-extension cap" only if a venue needs it.

---

## The BETTER vision (what's actually worth building)

The real value is real-time **context** that clock rules fundamentally cannot express:

1. **Relative under-use / demand redirection** — *"35 of 40 machines are turning over every
   few minutes, these 5 aren't → discount the 5 to pull customers toward them."* Load-balancing
   live demand. **The data already exists** (per-machine play telemetry via daemon-core). This
   is the strongest signal and the one most worth building.
2. **Interest without conversion (proximity)** — someone walks up to a long-idle game and
   *doesn't* play; the second time it happens, fire an instant discount with a light / visual
   cue. Converts demonstrated interest into a play. Depends on the **PaymentTerminal proximity
   sensor (currently unused; range/reliability unknown)** — exploratory fast-follow, not V1.

---

## Hard dependencies (why it's parked, not built)

- **Measurement first.** None of this is provable without the price-change audit
  (`pricing_change_event`) + a reporting view. Behavioural pricing without measurement is flying
  blind — you can't tell if it redirected demand or just made plays cheaper.
- **A clean real-time usage signal** (per-machine activity / occupancy) is the input the good
  signals (relative demand) need.

---

## Recommended sequencing when we return

1. **Measure loop must already exist** — it proves value and *shows which machines are
   chronically dead*, which is exactly what tells you whether demand-redirection is worth it for
   a given venue.
2. Build behavioural V1 around **relative under-use (demand redirection)**, NOT absolute idle.
3. Reuse the **safe lifecycle model** above (window + settle-gap + cooldown + max/day + floor).
4. Proximity + visual nudge = an experiment after that.

## UI fit (when built)

- Behavioural conditions slot into the existing **`ConditionEditor`** as new condition types,
  each with parameter inputs (idle → minutes; relative-demand → threshold).
- Lifecycle knobs (hold, settle, cooldown, max/day) are **rule-level settings**, shown only when
  the rule has a behavioural condition.
- The **preview** shows clock-eligibility and flags the live gate (*"+ only when idle ≥ 30 min"*);
  it cannot predict the live signal, and shouldn't pretend to.

## Honest verdict (from the discussion)

Worth building **as a targeted, optional, measurable experiment** — "revive specific underused
machines during off-peak, and measure if it worked" — **not** as an always-on "AI dynamic
pricing" headline. Venue-dependent value; real risk is customer perception, mitigated by the
settle-gap + modest discounts + tight scoping.
