# Sapiens Platform — What's New (March 2026)

Hi everyone,

Grab a coffee (or something stronger), because we've been busy. Really busy. Here's everything that's new, improved, or fixed. We tried to keep it short but... there's a lot. Sorry not sorry.

---

## 1. Reservations — Now With Superpowers

### Online Reservations Have Their Own Rules
You can now set **different rules for online reservations** compared to in-shop. But first, let's clear up how this works — because it's important:

**Online and in-shop share the same physical capacity.** If you have 10 bowling lanes, you have 10 lanes — period. What we've added is the ability to set a **lower online cap** on that same pool.

Here's a real example with 10 lanes and online cap set to 3:

| What happened | In-shop staff sees | Online customer sees |
|---------------|-------------------|---------------------|
| Nothing booked yet | 10 available | 3 available |
| 2 lanes booked (in-shop) | 8 available | 1 available |
| 3 lanes booked (any source) | 7 available | **Fully booked** |
| 8 lanes booked (in-shop) | 2 available | **Fully booked** |

The online customer sees at most 3 available, but as total bookings (from ANY source) increase, that number goes down. In-shop bookings eat into the online availability — because those lanes are physically taken. Meanwhile, in-shop staff always see the real remaining capacity.

**Why is this useful?** It lets you control how much of your capacity you expose online, while always keeping room for walk-ins and staff bookings. No overbooking was ever possible, and it still isn't — this just gives you tighter control over the split.

What you can configure separately for online:
- **Different capacity** — show fewer rooms/lanes/slots online, keep the rest for walk-ins
- **Different maximum people per time slot** — online customers can book up to X people, while in-shop staff can go up to Y
- **Different booking windows** — for example, online must book 2 hours in advance, but in-shop can book same-day
- **Day-by-day schedule** — online can have different opening hours than in-shop if needed

All of this is configurable per Activity Package. No code changes, no workarounds — just settings.

### VIP Lanes & VIP Packages
You can now designate some of your lanes (or rooms) as **VIP**. These are managed separately from regular capacity, and Activity Packages can be flagged as VIP to require them.

Here's how the settings work — using bowling as an example with 10 total lanes, 2 of which are VIP:

**VIP lane individual use (ON/OFF)**
This controls how VIP lanes are allocated:
- **ON (Individual)** — each VIP lane is tracked separately. If you have 2 VIP lanes, two different VIP birthday parties can each get one. Multiple VIP bookings can coexist.
- **OFF (Block)** — all VIP lanes are treated as one block. As soon as one VIP party books, ALL VIP lanes are reserved for them. One VIP booking per time slot — the birthday kid gets the whole VIP area to themselves. No sharing with strangers.

**Allow VIP overflow (ON/OFF)**
This controls what happens to VIP lanes when no VIP booking is using them:
- **OFF** — VIP lanes are strictly reserved for VIP packages. If regular lanes are full but VIP lanes are empty, a non-VIP customer is still told "fully booked". The VIP lanes sit empty, waiting for a VIP.
- **ON** — non-VIP bookings can overflow into unused VIP lanes. So if your 8 regular lanes are full but the 2 VIP lanes are free, a regular customer can still book. As soon as a VIP package comes in, VIP lanes are prioritised for them.

*Scenario: Saturday afternoon, 8 regular lanes booked, 2 VIP lanes empty, no VIP parties today. With overflow ON, regular customers can still book — Sapiens gives them a VIP lane. With overflow OFF, the website says "fully booked" and those 2 VIP lanes stay empty.*

**VIP packages** — An Activity Package (like "VIP Birthday Party") can be marked as `requireVipLane`. When a customer books this package, Sapiens checks VIP lane availability instead of regular lanes. If VIP is full, the package shows as unavailable — even if regular lanes are free.

### Max Reservation Rules (Time-Based Limits)
You can now create rules like: "Maximum 3 reservations between 10:00–12:00 on Saturdays". This prevents a situation where all your slots get gobbled up in one peak window. You define the time range, the day of the week, and the maximum — Sapiens handles the rest.

### Public Website — Helping Customers Help Themselves
The Porto booking website now shows **colour-coded availability**:
- Green = plenty of space, come on in
- Yellow/Orange = filling up, better book soon
- Red/Full = sorry, this slot is taken

Customers see this in real-time. It naturally pushes people toward less busy times (which is exactly what we want) and nobody wastes time trying to book a slot that's already full.

### Large Party & Group Bookings — Handled From Sapiens
Large groups no longer need special manual handling at the shop. Sapiens takes care of it:

- **Reservations for 10+ people** automatically trigger deposit options — the customer can pay a deposit upfront and the rest later. For groups of 20+, the deposit percentage increases (50% instead of 30%).
- **Discounts work properly** — apply a percentage or fixed amount discount directly on any reservation. No more "change the price to force a discount, sell it, change the price back" dance. Just enter the discount type (percentage or fixed amount) and Sapiens calculates the final price.
- **Reservation modifications are tracked** — when a reservation is edited (change of date, time, number of people), Sapiens keeps the original linked to the new version. Payment history carries across, so you always know what was paid and when, even after multiple changes.
- **Voucher/promo codes** can be applied to any reservation, online or in-shop, for automatic discount calculation

### Cancellations & Refunds — No More Stripe Dashboard Adventures
Any reservation can now be **cancelled directly from Sapiens**. No need to go hunting in Stripe.

Here's how it works:
- Click cancel, **write a comment explaining why** (mandatory — so there's always a paper trail)
- Sapiens cancels the reservation and **automatically sends a cancellation email** to the customer
- For online reservations, you can also **trigger a refund** in the same step. Sapiens talks to Stripe, processes the refund, and updates everything. You never need to open Stripe.

Scenario: A customer calls to cancel their birthday party. The staff member opens the reservation in Sapiens, clicks "Cancel & Refund", writes "Customer requested cancellation — scheduling conflict", and that's it. The customer gets their money back and a cancellation email. Total time: 30 seconds.

---

## 2. Payment Terminal & PulseBox — The Smart Way

### Game Types
Games in Sapiens now have three types, each with different behaviour:

- **Physical** — a real arcade machine that exists in the venue. One price, coin acceptor, PulseBox to activate it. The classic.
- **Virtual** — a game that doesn't have a physical machine (e.g. a VR experience managed by staff, or an attraction). Still tracked and priced, but no coin acceptor.
- **Attended** — a game operated by staff, supporting **multiple prices**. This is the new one. Think of a trampoline park where the staff selects "30 min — 8 EUR", "1 hour — 12 EUR", or "Family Pack — 35 EUR" from the terminal screen. Each price has its own code, description, and colour for easy identification.

### The Philosophy: The Game Is The Boss
This is fundamentally different from Nayax. With Nayax, you configure each device independently. With Sapiens, **the Game is the centre of everything**.

You set up a Game with its prices, its visual design, and its technical settings. Then you assign a Payment Terminal or PulseBox to a Game Location. Sapiens automatically generates the right configuration for the device and pushes it. That's it.

**Here's a concrete example of why this matters.** Say you have a trampoline park with one price: "30 min — 8 EUR". The Payment Terminal is in "tap to play" mode — customer taps their card, 8 EUR is charged, done.

Now the business decides to offer three prices: 30 min, 1 hour, and Family Pack. With Nayax, you would have to: go into the Nayax portal, reconfigure the device to show a selection screen, define the three prices on the device, test it, etc. With Sapiens: **you just add the prices in the Game settings.** That's literally it. Sapiens detects that the game now has multiple prices, automatically switches the terminal from "tap to play" to "select then pay" mode, generates the selection screen with the right prices, colours and descriptions, and pushes it to the device. The terminal reloads and it's live. You changed a business setting — Sapiens handled the technical consequence.

**The killer feature:** want to move a terminal from Game A to Game B? Just reassign it. Sapiens instantly pushes the new configuration — prices, design, everything. No technician visit. No reconfiguration. One click. If the device is offline, it picks up the new configuration automatically the moment it's turned back on.

The same applies to PulseBox. Move it to a different machine? Sapiens automatically loads the correct configuration for that game type. Even if it's a completely different type of machine, Sapiens highlights the differences so the technician can see exactly what's going to change before confirming.

**The bigger point:** once a game type is configured, it's configured forever. Nobody needs to remember "what was the pulse timing for the claw machines again?" or "how many pulses does the basketball game need?". Sapiens remembers. Move a PulseBox to any machine of the same type and it just works. Move it to a different type and Sapiens shows you what's different. Configure once, forget forever.

### Everything Is Separate (On Purpose)
Different people manage different things, so we separated them:

- **Prices** — managed by the business team in Game / Game Location settings. Multiple prices per game are supported (standard, premium, happy hour, kids, etc.), each with its own code, description, and colour.
- **Design** — managed by the marketing team. Colours, logos, button styles, background images. Organised in "Skin Versions" that can be applied across locations or per game.
- **Technical settings** — managed by the technical team. Pulse timing, acceptor configuration, operational parameters.

Each team works independently. Changing a logo doesn't affect the price. Changing a price doesn't break the pulse timing. Everyone stays in their lane (pun intended).

### Remote Control — Real-Time, From Anywhere
All Payment Terminals and PulseBoxes are **connected in real-time** via WebSocket. This means:
- Configuration changes are **pushed instantly** to the device. No waiting, no manual sync, no walking to the machine.
- You can see if a terminal is online or offline from Sapiens at any time.
- Need to change the price of a game at 3pm on a Saturday because you want to run a flash promotion? Change it in Sapiens — the terminal updates within seconds. Done from your phone if you want.
- Design updates (new logo, new colours for Christmas?) are pushed the same way.
- Need to change pulse timing on a PulseBox? Change it remotely. Takes effect immediately.

Sapiens uses smart hashing to detect when a configuration actually changed. If nothing changed, it doesn't bother the device. If something did change, the device gets a reload command immediately. If the device happens to be off, it picks up the changes the moment it powers on.

*Scenario: It's Friday evening, the venue is packed, and the owner decides to add a "Friday Night Special" price to the trampoline. They open Sapiens on their laptop, add the price, and within seconds every terminal serving that game shows the new option. No technician. No reboot. No downtime.*

This opens the door to things like: time-based pricing (happy hour prices that activate automatically), seasonal designs, instant promotions, or adjusting pulse timing on the fly — all controlled remotely, all in real-time.

### Four Operational Modes
Each Payment Terminal runs in one of four modes. You pick the mode per Game Location.

**Attended Mode** — A staff member operates the terminal. They see all available prices on screen, pick the right one, and the customer taps their card. Perfect for venues with active staff who want control over what's being sold.

*Scenario: A family arrives at the trampoline park. The staff member sees they have 3 kids and 2 adults. They select "Family Package — 5 people" from the terminal, the family taps their loyalty card, done.*

**Arcade Mode** — Fully automatic. The customer walks up, taps their card, the game starts. One price, no choices, no staff needed. The machine does everything.

*Scenario: A kid walks up to a claw machine, taps their card, the machine activates. Simple.*

**Selector Mode** — The customer sees multiple games on the terminal screen and picks one. Then they tap to pay. Good for areas where one terminal serves several machines.

*Scenario: A corner with 4 arcade machines and one terminal. The customer picks "Space Invaders" from the screen, taps their card, and that specific machine activates.*

**Kiosk Mode** — Full self-service. The customer browses games, sees prices, pays, gets a receipt. No staff interaction at all.

### Receipts — Current and Future
The terminal can generate **thermal receipts** for every transaction. This is currently built but **switched off on the device** while we finalise the customer experience.

**What's coming next (and it's exciting):** We're building a feature where the customer scans a QR code **once** and opts in to automatic receipt collection. That's it. One scan. From that moment on, every time they play a game, the terminal briefly shows a confirmation — "hey, we got you, this is on your receipt" — so the customer knows it's being tracked.

The beauty of it: **the customer doesn't need to scan anything ever again.** They don't need to think about receipts while they're playing. They play 5 games, 10 games, 20 games — doesn't matter. At the end of the day (or the week), they get **one single consolidated receipt** covering everything they played. No pocket full of 20 tiny receipts. One document. Clean.

This is especially important for Portugal where receipts are legally required. One receipt with all games is infinitely easier for the customer than chasing paper after every play.

**And here's the best part: it's fully retroactive.** The customer doesn't even need to opt in at the beginning. They can play all day long, remember at the very end "oh, I need a receipt", scan the QR code once, and recollect everything they played that day into one receipt. Played 15 games this morning without scanning anything? No problem — scan now, select those 15 transactions, one receipt. Nothing is ever lost.

### Multi-Ticket Payout
Some arcade games don't pay all tickets at once. They pay them in chunks while you play — 50 tickets here, 30 there, 20 more at the end. Our firmware (sapiens-pulse) now handles this properly.

Previously, only the first batch of tickets was credited. Now, when "Allow multi ticket payout" is enabled on a game, **all ticket chunks are accumulated** on the same transaction. Every chunk is logged with its timestamp, session ID, and amount — so if a customer claims they got 5,000 tickets and you see only 3,000, you can trace exactly what happened.

This feature is **off by default**. You enable it per game, only on machines that actually pay tickets in chunks. If something goes wrong, disable it and it goes back to the old behaviour. Safe rollout.

### Service Cards (Preview)
We've built (but currently commented out) the ability to **block service cards from working on games**. The idea: service cards would only work for monitoring purposes (checking status, blocking/unblocking attractions) but could not be used to play games. This prevents staff from using service cards for personal play. When we're ready to activate it, it's a simple switch.

---

## 3. Game & Game Location Management

### Multiple Prices Per Game
Games (especially Attended type) now support **multiple active prices**, each with:
- A code (for reference and reporting)
- A description (what the customer or staff member sees on screen)
- A colour (for easy identification on the terminal)
- A sort order (control which price appears first)

When you add or remove prices, the terminal adapts automatically — no manual device reconfiguration needed (see section 2 above).

### Price History
Every price change is recorded. You can see what the price was on any given date, who changed it, and when. Useful for auditing and for understanding revenue trends.

### Moving Games — Enforced and Tracked
This is a big one. We've all had the situation: someone physically moves a game machine from one location to another, swaps a Nayax device, and nobody updates the system. Revenue shows up under the wrong location, collection reports are wrong, and nobody knows what happened until weeks later.

**Sapiens now enforces this by design.** If a game is physically moved but Sapiens is not updated, **the device simply won't work**. The terminal or PulseBox checks its assigned Game Location against the configuration, and if they don't match, it refuses to operate. This is intentional.

The fix is simple: one click in Sapiens to update the Game Location to the new physical location. But that click must happen. No more ghost moves.

### Effective Dates — When Did Things Actually Change?
Every change to a Game Location now requires an **effective date**:
- **Change location** — when did the machine physically move? Enter the date.
- **Change status** (active, inactive, maintenance) — when did this status take effect?
- **Change coin acceptor** — when was the acceptor added, removed, or modified?

If you don't enter a date, you can't save. This is critical for two reasons:

**1. Historical reports are now correct.** The Collection area (where staff counts coins from machines) now shows games at a location **only if they were actually there on that date**. Moved a machine last Tuesday? Monday's collection report shows it at the old location. Wednesday's shows it at the new one. Exactly as it should be.

Previously, the system used the current location for all dates — so if you moved a machine and then tried to do last week's collection, the machine would appear at the wrong location. That's fixed.

**2. Full change history.** Every change is recorded with its effective date. You can view the timeline and compare any two versions side by side — the system highlights what changed. Want to know where a machine was 3 months ago? It's all there.

---

## 4. New Reports

### Game Location Performance Report
A full dashboard for analysing how a specific game location is performing:
- **Summary cards** — total plays, total revenue, unique players, confirmed vs denied plays at a glance
- **Period comparison** — compare with previous period, previous year, or custom range. Each KPI shows a green/red arrow so you instantly see if things are going up or down.
- **Daily trend chart** — interactive Highcharts graph showing plays, revenue, and unique players over time
- **Hourly distribution** — when is the game most popular? 10am? 3pm? Now you know.
- **Revenue by source** — loyalty card, Nayax, EMV terminal, and coin collection, each with transaction count and total. Only sources with actual data are shown.
- **Recent transactions table** — the latest transactions for this game location, with status colour coding
- **Price history** — see all price changes for this game location over time

Filter by location and specific game location, with flexible date ranges.

### Accounting Report
Built specifically for the accounting team and for reporting sales to the shopping centre.

**Important: this report shows accounting revenue, not operational revenue.** These are different by nature. For example: when a customer tops up their loyalty card with 50 EUR, that's a sale in operational terms. But in accounting terms, it's not revenue yet — it becomes revenue only when the customer actually uses that credit to play games. Since there's always some unused credit sitting on cards, the accounting report will always be slightly lower than other reports. This is correct and expected.

You select a date range and the report **splits it by individual day**, showing for each day:

- **Regular Sales** — in-shop card and cash payments (with voucher adjustments applied — if a sale was partially paid via a pre-paid voucher, that portion is deducted to avoid double-counting)
- **Loyalty Card Usage** — credit actually spent on games (the VAT-postponed amount). This is where the top-up revenue gets recognised — when the credit is used, not when it's loaded.
- **Cash Collection** — coins collected from game acceptors (the approved accounting value from collections)
- **Online Payments** — Stripe payments from the public website (reservations, online top-ups)
- **Nayax Transactions** — card payments through Nayax terminals on games
- **Refunds** — shown as negative amounts, deducted from the day total

Each revenue type shows: **gross amount, VAT breakdown by rate, and net amount**. Running totals accumulate across the period. European number format (comma as decimal separator).

**Excel export** — the report can be downloaded as an Excel file (.xlsx) with three sheets:
1. **Daily Breakdown** — one row per day, one column per revenue type, plus VAT base, VAT amount, and daily total
2. **VAT by Type** — period totals broken down by revenue type and VAT rate, with transaction counts
3. **Daily VAT Detail** — the full detail: every day × every revenue type × every VAT rate

All numbers use European format (comma decimal). Ready to hand over to the accountant or paste into a shopping centre report template.

*Scenario: The shopping centre asks for last week's revenue breakdown. The accountant opens the report, selects Monday to Sunday, and gets 7 rows — one per day — each with the split by revenue type, VAT amounts, and daily totals. Grand totals at the bottom. Downloads the Excel, sends it. Done in 2 minutes.*

### Sales Comparison Dashboard
A comprehensive comparison tool with three views: **Weekly, Monthly, and Year-to-Date**.

For each period it shows:
- **Per-location breakdown** — every location as a row, sortable by any column
- **Per revenue source** — Sapiens Cash, Sapiens Card, Online, Nayax, EMV, Cash Collection — each with its own amount and percentage change vs the comparison period
- **Grand totals** — across all locations and all sources
- **Percentage change indicators** — green arrow up or red arrow down for each value, so you instantly see what's growing and what's declining

A summary version also appears on the main dashboard for a quick glance.

*Scenario: The operations manager wants to know if the new online booking feature is driving more revenue. They open the Sales Comparison, select Monthly, and immediately see that "Online" is up 45% vs last month across all locations. Meanwhile "Sapiens Cash" is down 10% — customers are shifting to online. Data-driven decisions in 5 seconds.*

### Loyalty Card Report
Detailed analysis of loyalty card activity per location:
- Total transactions, revenue, and balance usage broken down by type (credit, bonus, courtesy, time)
- Period comparison with previous period or previous year
- Transaction trend over time
- All data cached for fast loading

### Staff Performance Report
Tracks what each staff member sold and when. Data is automatically refreshed every 20 minutes, so the report is always up to date.

---

## 5. Seller Interface (Point of Sale)

### Payment Terminal Transactions — Full Visibility
New dedicated page showing **all Payment Terminal transactions in real-time**:
- Filter by date
- See amount, status, card last 4 digits
- Each transaction is **linked to the corresponding sale** — click to jump to the sale, or from the sale click to see the terminal transaction. Both ways.
- **Reprint receipts** at any time from the transaction detail

### POS Terminal Transactions
Same thing for POS terminal transactions (physical card readers at the counter):
- Real-time list with date filtering
- Status clearly colour-coded (green = approved, red = declined)
- Receipt reprinting available
- Linked to the corresponding sale ticket

---

## 6. Performance Improvements
The main dashboard now loads **significantly faster**. All the heavy number-crunching (payment counters, Nayax totals, loyalty card stats) is now cached for 20 minutes. The Sales Comparison is cached for 30 minutes. For most users, the dashboard loads in under a second.

---

## 7. Bug Fixes & Other Improvements

- **Historical collection reports** — when you view collections for a past date, Sapiens now correctly shows the games that were at that location on that date (not where they are today). Moved a machine last week? The old reports still show it in the right place.
- **PulseBox activation** — now correctly handles different operational modes. Arcade and Selector modes activate the PulseBox (physical game needs pulses). Attended and Kiosk modes use the Payment Terminal directly (no pulses needed).
- **Reservation check-in** — fixed the Add Guests and Change Room buttons that weren't responding after check-in.
- **Receipt printing** — fixed Euro symbol compatibility across different thermal printer models.
- **Translation updates** — fixes and new translations across English, Spanish, and Portuguese.
- **Materialized view refresh** — a new scheduled job ensures all reporting data is refreshed every 20 minutes automatically. No more stale reports.

---

That's it. For now. More coming soon.

*— The Sapiens Team*
