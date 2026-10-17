# SapiensCore — Make it real. (v3 reshape)

> Reshaped copy for the IAAPA London 2026 booklet. Goal: a layered document — a
> skimmer finds their answer in 30 seconds, a believer can go deep. Roughly half
> the length of v2. Positioning spine: **the loyalty card is the heart; everything
> else is yours to choose; and we go deeper than tools — we connect everything.**
>
> Page markers (`— p.N —`) are rough spread targets, not final pagination.

---

— cover —

## Make it real.

Product & Platform Guide · 2026 Edition
Confidential — for authorized recipients only

---

— p.1 · What it is —

## What SapiensCore actually is

SapiensCore is the operating system for an entertainment venue, built around one
thing: **the loyalty card.**

The card is the spine. Through it, one system runs your **POS** (counter, tables,
open tabs), your **cashless payments** — at the counter and on every game, loyalty
and bank cards on the same reader — your **bookings**, your **device monitoring**,
and your **accounting**. It runs on hardware we install in your venue, so it keeps
working when the internet doesn't.

Two things to be honest about up front, because they tell you whether to keep
reading:

**The card isn't optional.** It's what connects the customer to everything else —
their balance, their history, their tier, their VAT. If you don't want to run a
cashless loyalty program at all, we're probably not your system. We'd rather tell
you that now than three meetings in.

**Everything on top of it is included — and already paid for.** Think of it as a menu in
an all-you-can-eat. You pay one entrance — a flat monthly fee per location — and every
feature in this document is already on the table. Use one, use all of them, use more next
year at no extra cost. No tiers, no premium version, no per-feature unlock, no surprise on
the invoice. Keep your website, keep your accounting, bring the cards you already have
(we'll migrate them, balances included) — or fill your plate with everything we make. The
card is the one thing you must take. After that, the only question is how much you want to
use.

And one difference you'll feel on every page that follows: most vendors sell you
**tools** — a loyalty module, a monitoring dashboard, a ticketing app — that don't
talk to each other. We sell you one nervous system where everything is connected,
so there are no gaps where money, time, and trust quietly leak out. That's the
harder thing to build. It's also the only thing worth building.

---

— p.2 · The day —

## A day in your operation

Before our features, a few things that are true in most venues right now — possibly
yours. None of them is extreme. That's the point.

**Game 23 jams at 10:47 on a Tuesday.** The manager tapes a handwritten sign on it
and gets back to the queue. Does your technical team know? Maybe today. Maybe never.
Meanwhile it earns nothing, and the only record is in someone's head.

**The collector hands you less than the counters say.** Skimming? Or did the card
plays spin the same mechanical counter the coins do? You can't tell. You sign anyway.

**At 8:12pm an employee taps "top up €100," charges the terminal €10, and pockets
the difference** — or marks it "paid by card" and never charges anything. The report
says card payment. Nobody reconciles the two. You will never see it.

**Monday, 7:30am: the server died, the last backup ran the night before.** A full day
of top-ups and redemptions, gone. You spend the week reconstructing balances from
receipts and the month wondering which "reconstructed" top-ups were real.

**End of month, four systems disagree.** Bowling says one number, the cash count
another, the processor a third, Nayax a fourth. You close the books and accept the gap.

You know exactly what that list was. It isn't a horror story — it's a Tuesday, and a
Saturday, and the end of every month. Most of it isn't separate problems. It's one
problem wearing different clothes: **you can't see your operation in real time, and you
can't prove what happened when it's questioned.** Solve that properly and most of those
moments stop being normal.

The fastest way to see whether we do is to skip ahead and find your own question.

---

— p.3–7 · FAQ —

## Start here: the questions you're actually asking

No feature matrix. Just the things operators ask us, answered straight — including
where the answer is "no" or "yes, but."

### Switching from what you run today

**Can I migrate my existing loyalty cards, with their balances?**
Yes — and not in theory. We migrated **40 venues off a competitor** with every
existing customer's credit intact, and switched on **cross-country credit** they'd
never had: one card, spendable across borders. Migration is the thing operators fear
most. We've done it at scale.

**Do I have to rip everything out at once?**
No. The loyalty card is the spine; everything on top is modular. Keep your website,
your accounting, your existing cards — bring them in, replace only what's actually
weak. We've never asked a venue to go dark for a weekend to switch.

**I run Nayax / other readers. Do you replace them or work with them?**
Both, your choice. You can run a SapiensCore loyalty card on a Nayax terminal — we
built that integration. But on an arcade game specifically, our reader beats Nayax on
its own terms: **one device reads loyalty and bank cards**, it keeps working **offline**
(Nayax goes dark when its cloud or 4G drops), and it doubles as a self-service top-up
point. You don't have to take all of us to beat what you have on the floor today.

**How does a device actually get installed?**
Scan the QR code on the terminal with any phone browser, pick the location, pick the
game. The full config — WiFi, pricing, screen, mode — assembles itself and the device
is live in minutes. No technician login, no flashing builds. Moving it to another game
is the same scan.

### What the system actually runs

**Is this just loyalty, or a real POS?**
A real POS. Counter sales, **tables, open tabs, pause-a-sale** to serve the next
customer and resume. Loyalty is the entry point, not the ceiling — run your whole
counter on it if you want, or keep your till and connect.

**One reader for loyalty, Visa, Mastercard, and Apple Pay at the games?**
Yes — one device, one reader, one tap; the system detects the card type. Online and
offline. The one honest exception: EMV bank cards need internet to authorise — that's
the card networks, not us. Loyalty keeps working regardless.

**Dynamic pricing on the games?**
Yes — both deterministic (season, day, location, tier) and behavioural, with reporting
on what each rule actually earned. Not a flat price list.

**Bookings and activities?**
Yes — birthdays, bowling lanes, trampolines. One engine across online, counter, and
phone; per-channel rules; offline-capable. Customers check in with a short code, no app.

**Mobile payment without an app or a per-game fee?**
Yes. A sticker with a QR code and NFC tag on the game; the customer taps their phone,
pays with Apple/Google Pay, the game starts. No app to download, no subscription per
game, no middleman.

**Our website and accounting — included or extra?**
Included if you want them. A template-based site in your brand (bookings, top-ups,
balances, one customer account), and a self-hosted Odoo ERP we run for you. Both
optional. Already have a website you love? Keep it.

### The money you're already losing

**Am I paying VAT on credit nobody has spent?**
Almost certainly. Open your software, total the unused credit on cards, apply your VAT
rate — that's money you've already handed your tax authority on services you haven't
delivered. **Credit-VAT** postpones VAT until the credit is actually consumed. Honest
limit: it can't recover what you've already paid; it stops the bleeding from now on.
We've run it in production for years. Most accountants will tell you it can't be done.

**Can I recover the top-ups I lose at the queue?**
Yes. Every game terminal is also a self-service top-up point — short balance, tap to
top up, play, all in under thirty seconds. The €20 that used to walk out when the line
was too long stays in.

**Do I actually know what each game earns versus costs?**
Yes — on one screen. Revenue from the transactions, repair cost from the Trace attached
to that game, net per game on demand. The Saturday-with-Excel ritual disappears.

### Trust, fraud, and when things break

**Can I trust my cash counts?**
Yes, and it's solved in hardware, not hope. The PulseBox isolates the mechanical coin
counter so card plays never spin it. The counter reads X, the cash should equal X, and
any gap is a real one worth investigating — no reconciliation formulas.

**Can staff fake a card top-up?**
No. The amount is pushed to the terminal automatically; the employee can't type it,
override it, or mark "paid by card" without a real terminal confirmation. That whole
fraud surface collapses to zero by design.

**What happens when the internet goes down?**
Loyalty, game starts, POS, cash, prize redemptions, in-store bookings all keep running
— the local NUC holds the state. It syncs when the connection returns. EMV bank cards
are the only thing that pauses (the bank has to authorise). Most customers never notice.

**What if the server dies, or gets stolen?**
A spare NUC ships with every venue — plug it in, it rebuilds from the continuous cloud
copy to the last transaction, no data loss. A stolen NUC is an encrypted brick that
won't boot anywhere but its own venue. We proved the resilience for real in the 2025
Spain-wide blackout: zero data loss, zero phone calls.

### Price and commitment

**What does it cost?**
Full numbers are at the back — no contact form, no "let's schedule a call." Early-adopter
rates for anyone who starts before April 2027, locked for years.

**Am I locked in?**
No. Your Odoo instance, your cards, your data are yours and stay yours. Card payments go
**direct to Planet**, our processor partner — not through us — so we're never sitting
between you and your money.

**Is this real, or a roadmap?**
Real. Running today across dozens of venues in Spain, Portugal, and the UAE, on **3,500+
devices** and growing fast. The one thing still in active build is our Trace system —
and we'll tell you plainly what's shipped versus coming when you ask.

---

— p.8 · Proof —

## The part most vendors can't put in writing

- **40 venues migrated off a competitor** — every customer's balance preserved, cross-country credit enabled.
- **3,500+ devices live** — a mix of our terminals and our readers — expanding quickly.
- **Dozens of locations across Spain, Portugal, and the UAE**, processing thousands of transactions a day.
- **A nationwide blackout survived** with zero data loss and zero corrupted state — April 2025, all venues recovered themselves.

This isn't a prototype looking for its first believer. It's an operation looking for its
next one. When you want it, we'll show you the real thing against your own numbers — not
a demo dataset.

---

— p.9–16 · Go deeper —

## We don't just give you tools. We go deeper.

Anyone can ship a loyalty module and a monitoring dashboard. The difference is whether
they're connected — whether the system *knows your operation* or just stores rows about
it. A few places where that depth is the whole point, and one that ties them all together.

### You see, and you act

Most monitoring tells you one thing: is the device on or off. Useful, nowhere near enough —
arcade hardware is decades old and rarely raises its hand to say it's broken; you learn by
what stops happening. The PulseBox on every game sees every coin, payment, game start, and
ticket, so a machine that normally starts twenty games an hour and suddenly starts zero
shows up immediately — not when a customer complains.

It's a nervous system, not a Monday dashboard. When a game loses its PulseBox at 3pm, the
system blocks its card reader within sixty seconds (no one pays for a game that won't run),
alerts the cashier, and escalates to your tech team and you if no one acknowledges. Two
minutes later it's back; the reader re-enables itself and the alert closes. **Alerts that
open and close themselves** — so you get signal, not twenty acknowledgements a day you stop
reading.

And you don't just watch — you act, from the same screen or your phone: reboot a stuck
device, start a game (a service test, or a free play for a customer whose last one didn't
fire), block a terminal with a clear multilingual out-of-service message, push a price to
every terminal in seconds, run pin-level diagnostics. When a PulseBox is too far gone to
respond, the PDA-plus-cable bridge lets you flash firmware remotely while someone on-site
just holds the cable. If it's truly dead, replacing it is a two-cable, scan-the-QR job
anyone can do in minutes — no technician. Every command is logged: who, when, which device,
from where.

### You verify, you don't hope

Most operators run on trust — the collector, the cashier, the prize counter. Trust is
fine until something goes wrong; then it gives you nothing. You can't fire on suspicion
or recover money on a hunch. SapiensCore is built so **everything important produces its
own evidence, automatically.**

- **Cash that reconciles clean** — the PulseBox isolates the coin counter (above), so the gap between counter and cash is always a real signal, never physics.
- **Counter photographed, OCR-verified** — on collection, staff photograph the meter; OCR reads it; if the typed number disagrees, an alert fires before the cash leaves the machine. Reading the counter and counting the cash are split across people and moments, on purpose.
- **Cash tracked to the bank** — collection → safe → transport → bank, each handoff logged. If it doesn't arrive in the window, an alarm.
- **Card operations you can audit** — every loyalty operation records who, when, from which workstation, and the card's state before and after. Records alone aren't evidence; SapiensCore flags the *patterns* — 120 recovery codes redeemed onto one card isn't a customer, it's a staff-and-friend.
- **Join-chain analysis** — balances funneled card-to-card-to-card are one of the most common internal frauds. We follow the whole chain, no depth limit, in seconds.

None of this is about catching people. It clears your honest staff by default and removes
the moments where the only thing between your business and a loss is someone's personal
honour. Honour is wonderful. It isn't a control system.

### Credit-VAT — the chapter your accountant should read

A top-up isn't a sale. It's a deposit — the customer prepaying for a service they haven't
received. Yet almost every system in this industry declares VAT the moment the card is
loaded, so you pay tax on credit your customers may never spend.

When Credit-VAT is enabled, SapiensCore separates the top-up from the taxation. €20
loads €20 of credit; no VAT yet. VAT is calculated the moment that credit is *consumed*,
on the exact amount, at the right rate for the right service — game play one rate, food
another, a party room another. Bonus and courtesy balances are consumed first (the
customer's paid credit lasts longer), regular credit next, Credit-VAT last (your tax
liability stays at the legal minimum). Staff decide nothing; the customer sees one number;
your books are simply correct.

Why does almost nobody do this? You have to understand the business from the inside, the
implementation is genuinely hard, and it splits your reports in two — operational revenue
today versus taxable revenue today. Most systems can barely produce one report correctly.
We produce both from the same events. Honest limit, again: it doesn't recover the VAT
you've already paid. It stops you paying more.

### What never breaks your day

We refused the two easy paths. Cloud-only is easy to build — until a venue's internet
drops and games stop. Offline-only is easy too — but you lose the real-time visibility
that makes everything else work. We built both at once: online when it can be, offline
when it must be.

- **Real-time replication, not nightly backup** — every transaction exists in two places within seconds. "We back up every night" means "lose everything since midnight when the server dies at 4pm." Not here.
- **The spare NUC** — disaster recovery in minutes, rebuilt to the last transaction.
- **UPS, battery-aware shutdown, voltage monitoring** — we watch actual voltage, not just on/off. The machine that "keeps breaking for no reason" is sometimes the wall, not the game; we've flagged it in real venues and the failures stopped.
- **Stolen-device protection** — full-disk encryption, USB logging, remote wipe, location-aware lockdown. Walk out with a NUC, walk out with a brick.
- **Zero-trust by architecture** — nobody at SapiensCore has direct access to your venue's data. Not by policy. By design.

### Open a Trace, not a ticket

This is what "we go deeper" means, made concrete. A ticket in Trello or Jira is a blank
card — someone types the reservation number, the game model, the location, and hopes. It
doesn't *know* your operation. A **Trace** does.

When you open a Trace, you don't describe what it's about — you **select** it. Pick the
reservation, and the customer, payment, package, activity, location, staff on duty, and
related Traces from the last 30 days are already attached. Pick the game (or scan it with
the PDA) and its repair history comes with it. Two consequences from that one choice: the
data is always accurate, and everything is linked — the Trace shows up on the reservation,
the game's record, and the customer's profile at once.

That linkage is why the per-game P&L isn't magic, it's arithmetic: revenue from
transactions, cost from Traces, net on demand. It's why the same fault across three venues
gets connected instead of fixed three times. SapiensCore even opens Traces itself — a game
that should have started and didn't, a NUC on battery, a payment that won't reconcile.

And your feedback to us? Also a Trace. No separate support inbox that doesn't know your
operation. You see what we're doing about it, in the same system, with the same
accountability. That's the whole philosophy in one feature: everything connected, no gaps
where things go to die. Trace is the part we're investing in most right now — what's
shipped already changes how operators work; more lands every release. As always, included.

---

— p.17–24 · The full menu —

## Everything on the table

You pay one entrance; this is the buffet. None of it is an add-on, an upgrade, or a premium
tier — it's all in the flat monthly fee. Much of it the industry already does in some form,
so we'll keep these pages tight and just show you the depth.

### The iM25 — one device on every game

Card readers come in three flavours and none does the whole job: loyalty-only readers,
EMV-only retail terminals (Ingenico, Verifone, PAX), and Nayax — which does both but goes
dark the moment its cloud or 4G drops. So we picked hardware we liked (PAX iM25, with iM30
as the larger sibling), wrote our own app from scratch, designed a custom case, and
certified the whole thing.

One device now does the entire job — loyalty online and offline, EMV (Visa, Mastercard,
Apple/Google Pay), and top-ups at the machine — in **four modes from one app**, switched
remotely, not reflashed:

- **Arcade** — single game, fixed price, tap and play. Short balance? It offers a top-up on the spot.
- **Selector** — one terminal across 2–8 games; pick from a visual grid, see the price, pay.
- **Attended** — staff-operated rides (train, bumper cars); multi-price grid, adjustable quantity (two kids, one transaction, one card fee), tap-to-block/unblock with a service card, and a "Call Assistance" button so no staff sits at an empty attraction.
- **Kiosk** — companion to an external kiosk, or full standalone on the iM30's bigger screen.

The details you only miss when they're gone: dual card detection at hardware level,
automatic PIN handling, any orientation (portrait/landscape/reversed), self-healing with
remote reboot, rolling multilingual idle screen, offline loyalty, and **screensaver
campaigns** — every idle terminal is also a scheduled advertising surface you manage from
one place, or sell to sponsors. Installing or moving one is a QR scan: pick location, pick
game, the config pushes itself, live in minutes. One rule we don't bend: **every venue runs
the same APK** — no enterprise version, no customer-specific build. When something improves,
it improves for everyone the same week.

### The A920 Pro — the counter terminal that walks

Same architecture, the counter role. When staff ring a sale, the amount is pushed to the
A920 Pro over WiFi — the employee can't decouple the top-up from the payment. Every unit
has a real, human-readable name (not "POS 1"), any staffer uses any device, and when the
queue builds they grab it and walk the line: read a card, **sell and activate a new card on
the spot**, take the EMV payment, done — the customer never reaches the counter. Receipts
live in the system, so you can reprint even if that device is off or dead.

### The PDA — your staff's portable everything

The floor was the gap: every system covered the back office and the counter, but the person
walking the floor had paper and memory. The PDA replaces both.

- **Cash collection that produces evidence** — scan the cabinet QR to find the game, photograph the counter (OCR verifies; a mismatch alerts before the cash moves), count on the device, chain of custody logged to the bank.
- **Act from where you're standing** — scan a game or a customer card to see live state, enable a game for a demo or recovery play, and **open a Trace with a priority** that lands in the right queue with the staffer's name on it.
- **The emergency bridge** — a dead PulseBox plus one USB-C cable turns the PDA into a remote bridge: you run live logs, pin diagnostics, even a firmware flash from anywhere while someone on-site just holds the cable. Half-day callouts become five-minute sessions.

### The DW200 — your ticket station, made smart

Keep the ticket eater you already have; we add a small device on top — a card reader, a
screen, and the connection to SapiensCore. Customers convert paper to virtual tickets
straight onto a card (no counter walk, no paper voucher), check any balance, and switch
language on any screen (a real difference in tourist-heavy venues). The same hardware
doubles as a lobby balance station or a **gate/access reader** (bowling area, trampolines,
VIP zone, party room) — buy it for one role, expand it as you grow.

### Loyalty cards with depth

The card is the spine, so depth here matters most:

- **One transaction, many cards** — the 3pm family (two new cards, two top-ups of different amounts, drinks, a toy) is one payment, one receipt, one audit trail; a discount lands on the right card, not smeared across the basket. Join several half-used cards into one, replace a damaged card with full transfer, apply a voucher to one while topping up another.
- **Six balance types** — credit, credit-VAT, bonus, courtesy, time, tickets — each consumed in a fixed order that's fair to the customer (bonus first) and correct for your books (Credit-VAT last).
- **Tiers, automatically** — promotion by cumulative spend, tier discounts applied at the moment of play, configurable per organisation.
- **Relevant History** — the journey belongs to the customer, not the plastic. When cards are joined, returned, resold, or transferred, each chain stays reconstructable. Settle a balance dispute or run a fraud investigation from the same data, different lens.
- **Card supply, your call** — €0.10/card from us (fully custom, per-tier designs), bring your existing cards, or buy anywhere. No markup on plastic.

### Mobile payments — no app, no per-game fee

A sticker with a QR code and NFC tag on the game. The customer taps their phone, a page
opens instantly (no app, no signup), they pay with Apple/Google Pay, the game starts. The
flow is bulletproof: SapiensCore checks the game is online, **pre-authorises** (holds, not
charges), fires the relay, and only captures on success — releasing on failure, so the
customer is never charged for a game that didn't run. Built in: no per-game fee, no
middleman. Print your own QR codes or buy NFC cards from us at €2.00–2.50, or anywhere.

### Reservations and activities

Birthdays, bowling, trampolines — the whole lifecycle. **Three channels, one engine**
(online, counter, phone) sharing the same availability and pricing, with different rules
per channel where it matters (stricter online, a manager's overbook-by-one in store).
Availability is intelligent, not a calendar: capacity at 30-minute granularity, per-lane,
per-room, opening hours of location *and* activity, holidays, cleanup time, fair-use rules.
Holds expire automatically, pricing adapts by day/group/season, and deposits offer three
modes including an **adaptive** one that tunes the deposit % to your actual no-show
patterns. Offline-capable; every booking gets a short code, no account needed.

### Your website, your kiosks

The industry inherited a broken model: reservations from one vendor, loyalty from another,
never talking — so the customer juggles two logins (or none) and you get fragmented data.
We see **a customer, not a card**: one account, one login, holding multiple linked cards.
The included template website (in your brand: bookings, top-ups, balances, FAQ, multi-
language, SSL/CDN/DDoS-protected, content managed by your team) is optional — keep yours if
you love it. And the **kiosks sell and activate new cards on the spot**, so a walk-in with
no card is playing before they ever reach your counter.

### The platform around it

- **Accounting — full Odoo ERP, included, no lock-in.** We self-host and customise your instance and connect it bidirectionally: receipts numbered and compliant per location/year, invoices grouped, journal entries posted automatically, VAT (incl. Credit-VAT) handled. Leave us and the Odoo instance stays yours.
- **Remote desktop — no AnyDesk, no TeamViewer.** Included, web-based, 20 workstations per location (then €1/mo each). Self-hosted, no per-device licensing.
- **Multi-location, multi-company, multi-merchant** — one platform; cards global or scoped; reporting and compliance correctly separate per company; the right Stripe/processor account chosen automatically by where the transaction happens.
- **Periods** — seasonal price changes (not promotions) that adjust automatically, the same season running different dates per location; also used to schedule firmware and maintenance outside your hours.
- **Vouchers & promotions** — single or bulk, expiry, usage tracking, secret partner batches, real-time validation, tied into the website and loyalty.
- **Marketing powered by your data** — not a Mailchimp replacement, but tools that know what your customers actually played and bought: "email everyone who bought two cokes and a pizza, offer a free pizza if they top up €50." 40,000 emails/mo per location; Google/Bing ad spend and venue revenue in one view; WhatsApp, Telegram, push.

---

— p.25–30 · Pricing —

## Pricing — transparent, as promised

A word on the model first, because pricing says a lot about a vendor's intentions. Some
companies charge an entry fee, give you the software "free," and sell you cards at 5–10x
market value — then never update the software, because you didn't pay for it. Others sit
in between, with tiers, per-game fees, per-user fees, and a wall of conditions you meet
after signing. That's not us. We charge for what we actually do: build, update, and improve
the system every day, and help you find money in your own data. Not plastic.

**Location setup — one-time, per location**
- Early adopter (IAAPA London 2026): **€5,000** — start your first location before April 2027 for a guaranteed 33% off, applied to every location you ever open.
- Standard: **€7,500** (signing after March 2027).
- Both include: 2 NUCs (primary + spare), 1 UPS with data + voltage monitoring, 1 military-grade USB recovery key, and remote support for the full install.

**Monthly — per location**
- Early adopter: **€800/mo**, locked 3 years, then inflation only. Every additional location gets the same rate, even years later.
- Standard: **€1,500/mo**.
- Includes everything in this document. Bring your own venue internet (ideally with a 4G/5G backup line); we'll spec and set it up with you if you want, no lock-in.

**Hardware — pay upfront or over 3 years**
- iM25 base: **€490** · + PulseBox **€40** · + Case with LED **€30** · full setup **€560**
- PulseBox alone: **€90** (mobile QR/NFC payment on a game with no card terminal)
- Case with LED standalone (for existing iM25s): **€79**
- Maintenance, iM25/iM30 only: **€5/mo** standard, **€2.50/mo** early adopter (fixed 3 years). PulseBox has none. (Others in this space typically charge €9–10.)

**Things others charge for — we don't**
- Loyalty cards: **€0.10/card** from us (fully custom, per-tier designs), or buy anywhere. No margin on plastic.
- QR / mobile / online payments: built in, no per-game or per-transaction fee from us.
- NFC SUN anti-clone tags: under **€0.60** each, or source your own.
- Remote desktop: included for 20 workstations/location (then €1/mo each). No AnyDesk, no TeamViewer.
- VPN: custom infrastructure, no third-party subscription.
- Marketing email: 40,000/mo per location; transactional always unlimited.

**The NUC is the one thing we insist on providing** — it's certified at the highest
security level, and the encryption and firmware depend on specific hardware, so "buy
whatever you want" isn't possible there. Everything else, source it yourself.

**Payment processing goes straight to Planet**, our partner — the people behind tax-free
shopping refunds at most European airports. You get a direct relationship and guaranteed,
escrow-backed payouts; we don't sit between you and your money. The per-transaction rate
depends on your volume and mix, so we won't publish a number that wouldn't apply to you —
we'll help you negotiate it directly.

**Running at a different scale?** These are a starting point, not a wall. Much larger,
much smaller, or shaped in a way we haven't covered — tell us before assuming the numbers
are final.

---

— p.23 · Close —

## Make it real.

Everything in this document is included — not options, not add-ons, not future upgrades.
Every feature is one system, available from day one, running today across dozens of venues
and 3,500+ devices.

You don't have to use all of it — but it's all on the table for the one entrance fee, the
day you start and every year after. The loyalty card is the spine; the rest is yours to use
as much or as little as you like. What you can't get anywhere else is the depth — the part
where everything is connected and nothing leaks through the gaps.

If this didn't sound like the documents you usually get from this industry, that was the
point. So is the platform underneath it. The next step isn't a sales call. It's us showing
you the real thing, against your own numbers, whenever you're ready.

**SapiensCore** · info@sapienscore.com · sapienscore.com
