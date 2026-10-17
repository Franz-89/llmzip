# Sapiens Platform — What's New (Spring 2026)

Hi everyone,

Grab a coffee. Actually, make it a double. We've been busy for the last two months and this document got... long. We tried to keep it short. We failed. But everything here is real, running in production, and making your life easier. So pour that coffee, sit down, and let's go.

*(If you're short on time, read the bold bits. If you're curious, read everything. If you work in accounting, skip to the VAT section — you'll thank us.)*

---

# Part 1 — March

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
You can now designate some of your lanes as **VIP**. These are managed separately from regular capacity, and Activity Packages can be flagged as VIP to require them.

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
The booking website now shows **colour-coded availability**:
- 🟢 Green = plenty of space, come on in
- 🟡 Yellow/Orange = filling up, better book soon
- 🔴 Red/Full = sorry, this slot is taken

Customers see this in real-time. It naturally pushes people toward less busy times (which is exactly what we want) and nobody wastes time trying to book a slot that's already full. Not that it was possible before, but giving a clear information on availability it naturally pushes revervations up.

### Large Party & Group Bookings — Managed Directly From Core
Group reservations can now be created and confirmed **directly from Core** — no need to ask the shop to do it, no need to connect to their PC.

Here's what changed:

- **External Payment option** — when creating a reservation, you can now select "External Payment". This confirms the reservation immediately without requiring the customer to pay through Sapiens. The payment happens outside the system (e.g., bank transfer). The reservation is created, confirmed, and the customer is notified — all in one step.
- **Discounts** — you can apply a percentage or fixed amount discount during creation. Important: discounts are only available on reservations created through Core with External Payment. A shop cannot autonomously decide to apply a random discount on a walk-in reservation.
- **Reservation modifications are tracked** — when a reservation is edited, Sapiens keeps the original linked to the new version. Payment history carries across.
- **Voucher/promo codes** can be applied to any reservation, online or in-shop, for automatic discount calculation

*Scenario: A company calls to book a birthday party for 25 kids. You open Core, create the reservation, select External Payment, apply a 10% group discount, confirm. The customer gets the confirmation email. They pay via bank transfer. Done — you never touched the shop's system.*

### Cancellations & Refunds — No More Stripe Dashboard Adventures
Online reservations can now be **cancelled and refunded directly from Core**. No need to go hunting in Stripe.

- Click cancel, **write a comment explaining why** (mandatory — paper trail)
- Sapiens cancels the reservation and **automatically sends a cancellation email** to the customer
- You can **trigger a refund** in the same step. Sapiens talks to Stripe, processes the refund, and updates everything. You never need to open Stripe.

**Important:** cancellations and refunds for online reservations are only available from Core — not from the shop. No shop should autonomously decide to cancel or refund an online payment. This is a deliberate design choice to protect revenue and maintain accountability.

*Scenario: A customer calls to cancel their birthday party. You open Core, find the reservation, click "Cancel & Refund", write "Customer requested cancellation", and that's it. Money back, email sent. 30 seconds.*

### Customer Profiles — Find Anyone, Act on Anything
The **Customer tab** is now active in Core. You can find any customer using the global search bar (top-left of every page) — just type their email.

This has **retroactive effect**: we've been collecting customer emails since day one. Every online reservation, every account creation — it's all there.

In a customer's profile you'll find:
- **Basic data** — name, email, contact info
- **All their reservations** — with the ability to act on them directly (cancel, modify, view payment history)
- **All their payments** — with the ability to **issue a refund without cancelling the reservation**

That last point is important. Sometimes a refund is due — maybe there was a service issue — but the reservation itself should stay active. Sapiens now supports this: refund the amount, keep the booking.

--- The

## 2. Payment Terminal & PulseBox — The Smart Way

### Game Types
Games in Sapiens now have three types:

- **Physical** — a real arcade machine. One price, coin acceptor, PulseBox to activate it. The classic.
- **Virtual** — a game without a physical machine (VR experience, attraction). Still tracked and priced, but no coin acceptor.
- **Attended** — operated by staff, supporting **multiple prices**. Think trampoline park: "30 min — 8€", "1 hour — 12€", "Family Pack — 35€". Each price has its own code, description, and colour.

### The Philosophy: The Game Is The Boss
This is fundamentally different from Nayax. With Nayax, you configure each device independently. With Sapiens, **the Game is the centre of everything**.

You set up a Game with its prices, design, and settings. Then you assign a Payment Terminal or PulseBox. Sapiens automatically generates and pushes the right configuration. That's it.

**Concrete example.** You have a trampoline with one price: "30 min — 8€". Terminal is in "tap to play" mode. Now you add two more prices. With Nayax, you'd need to reconfigure the device, define prices, test, etc. With Sapiens: **just add the prices.** Sapiens detects multiple prices, switches the terminal to selection mode, generates the screen, and pushes it. Live in seconds.

**Want to move a terminal from Game A to Game B?** One click. New configuration pushed instantly. No technician visit. If the device is offline, it picks up the changes when it turns on.

### Everything Is Separate (On Purpose)
- **Prices** — managed by business team
- **Design** — managed by marketing team (logos, colours, skins)
- **Technical settings** — managed by technical team (pulse timing, acceptor config)

Each team works independently. Changing a logo doesn't affect the price. Changing a price doesn't break the pulse timing.

### Remote Control — Real-Time, From Anywhere
All Payment Terminals and PulseBoxes are **connected in real-time**. Configuration changes are pushed instantly. Price changes take effect in seconds. Design updates, pulse timing, mode changes — all remote, all immediate.

*Scenario: Friday evening, venue packed. Owner adds a "Friday Night Special" price from their laptop. Every terminal shows the new option within seconds. No technician. No reboot.*

### Four Operational Modes
- **Attended** — a staff member operates the terminal. They select the product, choose the quantity, and the customer sees the price with a description before tapping their card. Perfect for activities where a human needs to be involved: trampolines, VR experiences, anything with a briefing.
- **Arcade** — fully automatic. Customer walks up, taps their card or phone, game starts. No staff needed. One price, one tap, one game. The classic arcade experience, just without coins.
- **Selector** — customer picks from multiple games displayed on one terminal's screen. Useful when one terminal serves several games in the same area. Tap the game you want, tap your card, play.
- **Kiosk** — the full self-service mode. When paired with a real kiosk (coming soon), it handles payments and reads customer loyalty cards. On its own, it acts as a balance point — customers can tap their card to check their balance and top up. No staff interaction needed.

### Multi-Ticket Payout
Some games pay tickets in chunks while you play. Sapiens now accumulates all chunks on the same transaction, with full logging. Enable per game, off by default.

---

## 3. Game & Game Location Management

### Multiple Prices Per Game
Games now support multiple active prices with code, description, colour, and sort order. Add or remove prices and the terminal adapts automatically.

### Price History
Every price change is recorded — who changed it, when, and what the price was before.

### Moving Games — Enforced and Tracked
If someone physically moves a game but doesn't update Sapiens, **the device won't work**. This is intentional. One click to fix it — but that click must happen. No more ghost moves.

### Effective Dates — When Did Things Actually Change?
Three types of changes on a Game Location now require an **effective date** — you can't save without one:

**1. Location change** — when you move a game from one location to another, you must select *from which date* the game is at the new location. Sapiens uses this to build a complete movement history for every game. This matters because reports are date-aware: when you look at a collection report for March 15th, Sapiens shows each game at the location where it physically was on that date — not where it is today. If a game was at Location A until March 10th and moved to Location B on March 11th, it appears under Location A for any report before the 11th and under Location B after. No more retroactive confusion about where revenue or coins came from.

**2. Status change** — when you switch a game between Active, Maintenance, Inactive, etc., you enter the date when the change took effect. This creates a clear operational timeline: you can see exactly when a game went into maintenance, how long it stayed there, and when it came back online. This is essential for performance analysis — if a game was in maintenance for two weeks, its revenue numbers for that period should reflect that, not look like a mystery drop.

**3. Coin acceptor change** — when you enable or disable coin acceptance on a game, you enter the effective date. This directly impacts the collection workflow: when the collection team goes to collect coins on a given day, Sapiens shows **only the games that were configured to accept coins on that specific date**. If a game had its coin acceptor disabled last Tuesday, it won't appear in Wednesday's collection list — because there shouldn't be any coins to collect. Conversely, if a game was enabled on Monday, it will appear starting from Monday's list even if the team visits later that week. This eliminates two common problems: collecting from games that weren't accepting coins (wasted time), and skipping games that were (missed revenue).

All changes are recorded with their effective date and the user who made them. You can view the full timeline of any game — every location move, every status change, every acceptor toggle — and compare any two versions side by side. Sapiens highlights exactly what changed between them, so auditing is instant.

---

## 4. New Reports

### Game Location Performance Report
Full dashboard: total plays, revenue, unique players, period comparison, daily trend chart, hourly distribution, revenue by source, recent transactions, and price history.

### Accounting Report
Built for the accounting team and shopping centre reporting. Shows **accounting revenue** (not operational) split by day, with each revenue type (regular sales, loyalty card usage, cash collection, online payments, Nayax, refunds) showing gross amount, VAT breakdown by rate, and net amount.

**Excel export** with three sheets: Daily Breakdown, VAT by Type, and Daily VAT Detail. European format. Ready for the accountant/shopping center if needed.

### Sales Comparison Dashboard
Weekly, Monthly, and Year-to-Date views. Per-location breakdown, per revenue source, grand totals, percentage change indicators. Also on the main dashboard (if enabled). It now compares mobile date: if it's Wednesday, it will compare mon-wend with previous mon-wend.

### Product Report
New report showing **product sales and reward exchanges** side by side. For each product: how many sold, at what price, and how many exchanged via loyalty card rewards. Filter by location, date range, or across all locations. Finally answers the question: "Which products are actually making money, and which ones are just being given away?"

### Loyalty Card Report & Staff Performance Report
Detailed card activity per location and staff sales tracking with automatic 20-minute refresh.

---

## 5. Seller Interface

### Payment Terminal (IM30/25) & POS Transactions (A920 Pro)
New pages showing all transactions in real-time. Filter by date, see status, card details, and jump between the transaction and its linked sale. Receipt reprinting available.

---

## 6. Performance
Dashboard loads significantly faster — heavy calculations cached for 20 minutes. Sales Comparison cached for 30 minutes. Under a second for most users.

---

## 7. Bug Fixes (March)
- Historical collection reports now show games at the correct location for that date
- PulseBox activation handles operational modes correctly
- Fixed Add Guests and Change Room buttons after reservation check-in
- Fixed Euro symbol on thermal printers
- Materialized view auto-refresh every 20 minutes (it mean that whole block of data is updates at least once every 20 mintues to allow instant access. Shops instead always sees their data in realtime)

---

# Part 2 — April

*(Still here? Impressive. Here's where it gets really interesting.)*

---

## 8. Centralized Device Monitoring — See Everything, From Anywhere

This is the one we're most proud of. You can now monitor and control **every PulseBox and Payment Terminal across all your locations** from a single page in Core. Live. From your sofa if you want.

### How It Works
Every location already runs a local daemon that manages its devices. Those daemons now connect to a centralized service (daemon-core) that bridges all your locations to your browser. Open the monitoring page and you get:

- **Live status** — see which devices are online or offline, updated in real-time
- **Activity feeds per device** — watch coin inserts, game starts, ticket payouts, and card payments happen live, organised per machine (not all mixed together)
- **Remote commands** — start a game, reboot a terminal, block a device, reboot, update firmware — all from your browser

### The Dashboard
Every location as a card. Green = everything's fine. Yellow = something's offline. Red = trouble. Click to drill in. All updates in real-time — no refresh button needed.

### Remote Commands
**For PulseBox:** Handshake, Get Status, Start Game (configurable to pay ticket in paper or virtual on a loyalty card), Dispense Tickets, Restart, Check for Update, Custom command.

**For Payment Terminal:** Reload Config, Update Prices, Change Mode, Block/Unblock, Reboot.

*Scenario: Saturday afternoon, a PulseBox goes offline at Location 7. You get the alert, open the dashboard on your phone, see it's the Grua near the entrance. Try a remote restart. 1.5 seconds later, it's back online. Fixed from your sofa. The customers didn't even notice.*

---

## 9. Automatic Terminal Blocking & Unblocking

This one prevents real money loss.

**The problem:** a PulseBox controls the game, a Payment Terminal takes the payment. If the PulseBox dies (because the game has a phisical problem that blocks power on pulsebox) but the terminal stays active, customers pay — but the game doesn't start. Hello, refunds.
Of course even before the screen would show an error. The problem is that, especially for the EMV payments (Visa/Mastercard), we cannot detect in advance unless we want the system to be slow. Plus it doesn't happen often.

**The solution:** Sapiens now **automatically blocks the terminal** when its paired PulseBox goes offline, and **unblocks it** when the PulseBox comes back. Within seconds.

Here's what happens:
1. PulseBox goes offline
2. Within ~5 seconds, the system detects it and sends a block command to the terminal
3. The terminal shows "Wait for Service" in multiple languages — nobody can pay for a broken game
4. PulseBox comes back → terminal unblocks automatically → back to normal

**Two systems work together:**
- **Instant reaction** — triggered by the daemon the moment a PulseBox connects or disconnects. Handles 99% of cases in seconds.
- **Periodic safety net** — runs every few minutes and catches anything the instant check missed.

We only *block* when the shop is open (don't create problems at 3 AM), but we *always unblock* when the PulseBox recovers. The device is healthy again — clean it up, regardless of the hour.

### Device Health Page
New page in the client (right after Dashboard, visible to everyone). Shows active issues grouped by incident — not "PulseBox offline" and "Terminal blocked" as two separate things, but one card: "This game has a problem. The PulseBox is offline and the terminal was automatically blocked."

Red badge on the menu updates every 30 seconds. Zero issues? Badge disappears. You'll never forget to check — it's right there every time you use Sapiens.
This allows the team to be pro-active, instead of waiting for a customr to complain or worse: maybe a game was off laredy 1h but no one played, and we didn't know. Not anymore

### Per-Location Toggle
Don't want auto-blocking at a specific location? There's now a setting in Location (SYS only, under Sapiens Pulse): **Auto-block terminal — Yes/No**. Enabled by default. Turn it off and that location's health checker simply skips the blocking logic — no daemon restart, no code change, instant effect. Turn it back on and it resumes. Useful for locations where you're still setting things up, or where the PulseBox connectivity is flaky and you'd rather handle it manually.

---

## 10. Game Location — Clearer, Faster, Smarter

### Redesigned Detail View
The Game Location form was... functional. But it was one long wall of fields with no visual grouping. Now it's organised into clear sections: QR Code, Info, Business Settings, Coin Acceptor, Tags, Status. Each with a colour-coded heading. Same for the "New" form.

### No More Full Table Reload on Save
Used to reload the entire table every time you saved. Scroll position lost, page flickers, annoying. Now only the changed row updates. Detail panel stays open. Smooth.

### Active Row Highlighting
Click a game → row turns blue → detail scrolls into view. Small thing, big difference.

---


## 11. PulseBox — Registration & Smart Management

### QR Code Registration — Scan, Click, Done
Every PulseBox now ships with a QR code on it (yes, including the 800 we just received). To register a device:

1. Scan the QR code with your phone
2. Sapiens opens with everything pre-filled — MAC address, device info, all of it
3. Select the game, confirm, done

No typing MAC addresses. No misreading "B" vs "8". The device can be configured completely offline — it doesn't even need to be connected to WiFi yet. Just scan the sticker and follow the instructions. This is how we're registering 130 devices in Sabadell this week: scan, assign, move on. Next.

### Smart Default Configurations — Set It Once, Forget It Forever
Here's a problem we solved: you've spent 20 minutes finding the perfect pulse timing for a claw machine. Relay pin 7, 100ms pulse, paper payout. Beautiful. Now you need to set up 15 more claw machines. Do you remember those settings? Do you want to look them up every time?

**Sapiens remembers for you.** Configurations are automatically saved by game type. When you register a new PulseBox and select the game, Sapiens pre-fills all the hardware settings with the defaults for that type of game. First claw machine took 20 minutes to configure. The next 14 take 10 seconds each.

Need a custom configuration for a specific machine? Just change it — Sapiens automatically saves it as a new default option. There's also a dedicated page where you can manage all default configurations by game: view them, edit them, create new ones. The idea is simple: **find the perfect setup once, and never think about it again.**

### One Game = One PulseBox (Enforced)
The dropdown now shows which game locations are available and which already have a PulseBox. If you pick one that's taken, the system automatically releases it from the old PulseBox, syncs both, and assigns it to the new one. No conflicts. No orphaned devices.

### Selective Firmware Versions
New Location setting (SYS only): pin a location to a specific firmware version. Want to test new firmware on one location before rolling out? Pin it. Got a location with a weird issue? Keep it on a known-good version. Everyone else follows the stable release automatically.

---

## 12. VAT — The Canary Islands Feature (And Everyone Else Benefits Too)

### The Background
The Canary Islands use IGIC (7%) instead of mainland Spain's IVA (21%). Until now, Sapiens handled this with a hardcoded workaround — a specific rule that detected Canary Islands locations and applied a different rate. It worked, but it was brittle, ugly, and didn't scale. What about Portugal? What about a tax-exempt product at a location with a special rate? The workaround couldn't handle any of that.

It was about time to do it properly.

### The Problem
Changing VAT for a product at a specific location required enabling "Custom Settings" — which forced you to manually set price, status, reward, visibility, and everything else. Just to change a tax rate. And if you had a location in the Canary Islands, you'd have to do this for every. single. product.

### The Solution: Three-Level Cascade
VAT now flows: **Product-Location → Location → Country**. The magic word is **"Sapiens"** — which means "inherit from the level above".

| Product-Location VAT | Location VAT | What the customer pays |
|---|---|---|
| Sapiens | Sapiens | Country rate (21% in Spain, etc.) |
| Sapiens | 7% IGIC | **7%** — location wins |
| 0% (exempt) | 7% IGIC | **0%** — product-specific override |

**In practice:** set VAT once on the Canary Islands location → every product there automatically uses 7%. New products added later? Also 7%. One setting. Done. The old hardcoded workaround is gone.

The VAT selector is now always visible on the product form (not hidden behind Custom Settings), and defaults to "Sapiens" for new products.

---

## 13. Location — Quality of Life

### Opening Hours Preview
New feature in Location detail. The Opening Hours tab now includes a **schedule preview** at the top: it loads today's schedule automatically, and you can pick any date — past or future — to see what hours Sapiens will apply. This is your verification tool: opening hours are the result of layering **Default Schedule → Period overrides → Holiday rules**, and it's not always obvious what the final result is. The preview shows you exactly what Sapiens calculates for any given day. Holidays and holiday eves are shown with proper labels ("Holiday", "Holiday Hours", "Holiday Eve Hours").

### Open/Closed — Always Visible
The top-right corner of the Location detail now shows whether the shop is **open right now** at this exact moment. Green = open, red = closed. Always visible, no need to check manually.

---

## 14. QR/NFC Payment — Pay With Your Phone, Play Instantly

This is a big one. Customers can now **pay for a game by scanning a QR code with their phone**. No app. No download. No account. Just scan and play.

### How It Works

1. **You create QR codes in Core** — generate them, download the PDF, send it to print. Each code is a small sticker.
2. **Stick the code on the game** — one code per game, assigned in Core with one click.
3. **Customer scans the code** — their phone opens a payment page. No app needed — it's a web page.
4. **Sapiens detects the best payment method** — Apple Pay, Google Pay, or card. Whatever the customer's phone supports, we show it. Apple user? Apple Pay button appears first. Android? Google Pay. Neither? Card form. The customer picks the fastest option.
5. **Sapiens checks if the game is online** — before taking any money, we verify the PulseBox is connected and ready. If it's offline, we tell the customer immediately. No payment taken for a broken game.
6. **Customer pays, game starts** — the whole thing takes seconds.

### The Safety Net — Why Pre-Authorisation Matters

A quick word on chargebacks, because this matters more than most people think. Chargebacks happen when a customer disputes a charge — and for online payments, they're a real risk. The numbers are brutal: if just **1% of your transactions** get chargebacked (that's 1 in 100), your payment processor will very likely **block your account**. Most processors start getting nervous at 0.75%. One bad month can shut down your ability to accept online payments entirely.

This happens to be one of our areas of deepest expertise, so we built the system to eliminate this risk from the start:

- **Step 1: Pre-authorise** — we place a hold on the customer's card. The money is reserved but not charged yet. **Pre-authorisations cannot be chargebacked.** This is the key.
- **Step 2: Start the game** — we send the command to the PulseBox.
- **Step 3: Game started successfully?** → Capture the payment (now it's a real charge). **Game failed?** → Release the hold (customer's money is returned automatically).

If a pre-authorisation is never confirmed, it expires on its own after 7 days — the customer's money is released automatically. No orphaned charges. No manual cleanup.

*The result: the customer pays 2€ on their phone, the claw machine starts before they put their phone back in their pocket, and if anything goes wrong, they're never charged. Your chargeback rate stays at zero. That's how it should work.*

### Live in the Shop — Real-Time NFC Payment Feed
Despite being online payments, QR/NFC transactions appear **in real-time at the shop** under the new **NFC Payments** menu. Staff can see every payment as it happens — who paid, when, which game, and the customer's name when available (from their card or wallet). No delay, no sync needed. The payment shows up the moment the customer taps.

### Instant PulseBox Check
When someone scans the QR code, Sapiens checks if the PulseBox is online through the fastest path available. Response time went from 1-3 seconds to under 5 milliseconds. The page loads, the game status is already there. No spinner, no waiting.

### Location-Filtered Packages
Top-up packages are now filtered by location. A package available only in Spain won't show up for a customer in Portugal.

### Service Card = Paper Tickets
When a service card (staff card) starts a game, tickets come out on paper instead of virtual. Because nobody's going to redeem virtual tickets on a test card, and we'd rather not corrupt the data.

---

## 15. Accounting

### VAT Rounding
Fixed a subtle rounding issue where the VAT calculation could be off by 1 cent on certain amounts. Now matches how tax authorities expect it. Affects Nayax transactions, loyalty card usage, and cash collection journal entries.

---

## 16. Holiday Intelligence
Opening hours now properly handle holidays and holiday eves when calculating the schedule for a specific date. When a date falls on a holiday, Sapiens applies the holiday schedule; when it's a holiday eve, it applies the eve schedule. The preview labels clearly show which rule is active: "Holiday", "Holiday Hours", or "Holiday Eve Hours".

---

## 17. User Management — Simpler, Safer, Faster

### Account Creation — No More Temporary Passwords
Creating a new user no longer generates a temporary password. Instead, the user receives a **single activation link** by email. Click it, choose your password and PIN. Done.

This fixes a real problem we found in production: some Android devices (particularly older versions running non-standard browsers) had trouble with the previous flow. The page relied on browser features that weren't universally supported. We've rebuilt the activation page using simpler, more widely supported web standards — the kind that work on everything from a 2018 budget Android to the latest iPhone.

We also fixed a bug where, in certain circumstances, a user's PIN wouldn't propagate correctly across the network — forcing repeated resets. That's gone.

### PIN Reset — Two Paths, Clear Rules
Two new options for PIN management:

**1. Reset with current PIN (user knows their PIN):** Available in-shop or via email. If done via email, the user receives a link. If done at the shop: the next time they log in with their current PIN, Sapiens immediately asks them to choose a new one. No interruption to their session — they just pick a new PIN and continue.

**2. Reset without current PIN (user forgot it):** Only via email. This is a security-sensitive action — Sapiens immediately invalidates the current PIN. The user cannot log in until they click the email link and set a new PIN. This prevents someone who shouldn't have access from continuing to use a compromised PIN.

**3. Self-service PIN change:** Users can also change their own PIN anytime from their profile in the shop app — no manager needed, no reset flow. Just open your profile, enter your current PIN, choose a new one.

### Instant Account Deactivation Across the Network
When a user is deleted or banned in Core, the change now propagates **instantly** to every connected location. If that user is currently logged in at a shop, Sapiens destroys their active session — they're logged out immediately, mid-shift if necessary. No waiting for the next sync cycle, no "they still have access for 30 minutes". The session is gone the moment you click delete.

---

## 18. Location & Organisation — Better Visibility

### Users Tab in Location Detail
The user list was previously buried in the Location form alongside all other settings. It now lives in its own dedicated **Users tab** with a cleaner layout — easier to see who has access to a location at a glance, add new assignments, or remove existing ones.

The same improvement applies to **Organisation detail**: users are now displayed with more information (role, status, last login) and in a clearer format.

---

## 19. Under the Hood
- Better database design for device health tracking
- Alerts track who resolved them and link to their root cause
- New translations across English, Spanish, and Portuguese
- Faster device lookups through in-memory caching
- General code cleanup and consistency improvements

---

That's two months of work. 19 sections. We need a holiday. (We won't take one.)

The theme? **Make problems visible and fix them before anyone notices.** The monitoring system, the automatic terminal blocking, the health alerts, the QR payments, the cascading VAT — they're all about removing manual work and catching issues before customers do. A broken game used to mean an angry customer, a confused staff member, and a refund negotiation. Now it means a red badge that clears itself in 5 seconds while everyone continues eating pizza.

But we're not done. Not even close. In fact, we're just getting warmed up. So before you go...

---

# Part 3 — What's Next

*(This is the part where we get excited and try not to overpromise. We'll try. We'll probably fail.)*

---

## Kiosk Mode — The Big One

We've started building the actual Kiosk experience — a full self-service station where customers can do everything themselves: top up their loyalty card, buy a new card, check their balance, browse games and activities, make a reservation, and pay. All without any staff interaction.

The Payment Terminal already supports Kiosk mode (see section 2). What we're building now is the brain behind it — the full customer-facing interface that turns a terminal from "tap to pay" into "browse, choose, pay, play." This is the next major milestone and it's actively in development.

---

## Sapiens PDA — Already in Final Testing

This one's been cooking for a while and it's almost ready. In fact, it's so close to ready that we're using it **this week** to install 130 PulseBoxes in Sabadell. That's not a demo — that's production.

### What It Does Today

The Sapiens PDA is a dedicated handheld tool for field operations. Connect it to a PulseBox via USB-C cable and you get:

- **Live logs on screen** — see exactly what the PulseBox is doing, in real-time, right there in your hand
- **Install firmware** — flash a PulseBox with the correct firmware directly from the PDA
- **Erase device** — full wipe when decommissioning or fixing broken sectors
- **Auto-generate QR code** — the PDA reads the device info and creates a QR code + link that opens directly in Core. Scan it with your phone or tap the link — you're on the registration page with everything pre-filled
- **Bridge mode** — this is the game-changer. PulseBox is offline? WiFi isn't working? No way to see what's happening? Connect the PDA. It bridges the PulseBox logs to Core. Your expert in the office sees what's going on as if they were standing next to the machine.

### Why This Matters

Here's the vision: **you shouldn't need a senior technician at every location.** The reality of managing 40+ venues is that you can't have an expert everywhere. The expert should be in the office — designing, optimising, solving the hard problems. The PDA is what connects them to the field.

A staff member at the shop — not a technician, just someone who knows how to plug in a USB cable — connects the PDA to the problematic device. The expert in the office sees the logs, understands the problem, and either fixes it remotely or gives clear instructions. No travel. No guessing. No "can you tell me what the lights are doing?"

We're not saying every shop gets a PDA tomorrow. But we're getting very close to that reality.

---

## Sapiens AI — The PDA Gets a Brain

This is the one that keeps us up at night — in the good way.

We're building an AI system that sits inside the PDA. When a PulseBox has a problem, **before opening a ticket, before calling anyone**, the AI analyses the device logs, identifies the issue, and attempts to fix it automatically.

Think about it:
- PulseBox isn't connecting to WiFi → AI checks the configuration, compares with known-good devices at the same location, identifies the mismatch, and pushes the fix
- Firmware is stuck in a boot loop → AI recognises the pattern from previous cases, rolls back to the last stable version
- Pulse timing is wrong for the game type → AI detects the mismatch against the expected configuration and corrects it

Only when the AI can't resolve the issue does it escalate to a human — and even then, it provides the full diagnosis: "I tried X, Y, and Z. Here's what I found. Here's what I couldn't fix."

This is complex. Really complex. It requires understanding device behaviour, historical patterns, and the relationship between configuration and symptoms. It won't be ready next month. But it's actively being built, and the architecture is designed so we can teach it incrementally — every resolved issue makes it smarter.

The end goal: a staff member walks up to a broken game, plugs in the PDA, and the AI fixes it. No human expert needed. No ticket. No waiting. The game is back online in minutes. It can't be fixed? the AI will drive the used on what to do next.

*Yeah, we know. It sounds like science fiction. We're building it anyway.*

---

## Smarter Monitoring — Opening & Closing Awareness

The device monitoring system is getting even smarter. Because Sapiens already knows every location's opening hours (down to holidays and holiday eves), the next step is obvious:

**Opening check:** When a shop is supposed to open at 10:00, are all the games actually online by 10:00? If a PulseBox is still offline at opening time — alert. No more "the claw machine near the entrance has been off since this morning and nobody noticed until 3 PM."

**Closing check:** If a shop closes at 23:00 but a device went offline at 22:30, that's not necessarily wrong — but you should know about it. Maybe the staff turned things off early. Maybe there's a problem. Either way, awareness is better than surprise.

**Out-of-shop terminals:** When we start deploying iM25 terminals outside the venue (at other locations, in shopping centres), this becomes critical. A terminal that's been offline for a week with nobody noticing? That's lost revenue. Sapiens will catch it — automatically, on day one.

---

## Website & Customer Apps

It's time to accelerate the customer-facing side. The booking website, the customer app, the loyalty card self-service — all of these are next in line. The backend is ready (it's everything you just read about). Now we build the front door.

---

That's it. For real this time.

Two months of what's done, and a roadmap of what's coming. If you look at the trajectory — from manual configuration to automatic, from reactive to predictive, from "a human noticed a problem" to "the system fixed it before anyone knew" — that's where we're going.

We know how complex this is. We know how many moving parts there are. And we know that every single feature we ship makes the next one possible. The monitoring enables the auto-blocking. The auto-blocking enables the health alerts. The health alerts enable the PDA. The PDA enables the AI. It's all connected. Just like the platform itself.

Thank you for reading this far. Seriously. It means a lot.

*— The Sapiens Team*

*P.S. — If you read this whole thing, you deserve a raise. Or at least a coffee. On us. If you also understood the VAT cascading section on the first try, make it a double espresso.*

