# Sapiens Platform — What's New (April 2026)

Another month, another wall of text. We told you more was coming soon. Here it is.

---

## 1. Centralized Device Monitoring — See Everything, From Anywhere

This is the big one. You can now monitor and control **every PulseBox and Payment Terminal across all your locations** from a single page in Core. Live.

### The Architecture
Every location runs a local daemon (daemon-pulse) that manages its devices. These local daemons now connect upstream to a centralized daemon-core service via persistent WebSocket. daemon-core acts as the bridge between your locations and your browser.

When you open the Device Monitoring page in Core, your browser connects to daemon-core via a SharedWorker (one WebSocket shared across all tabs — survives page navigation). You subscribe to a location and immediately get:

- **State snapshot** — the current online/offline status of every device at that location
- **Live status updates** — devices going online/offline appear instantly
- **Activity feed** — coin inserts, game starts, ticket payouts, loyalty card taps, card payments — all in real-time
- **Command responses** — when you send a command, you see the acknowledgement

This is the same real-time visibility that existed on the local client page — but now accessible from Core, across all 40+ locations, from your phone if you want.

### Dashboard
The monitoring dashboard shows every location as a card:
- Daemon connection status (green/red)
- PulseBox count: online / approved (colour-coded: green = all online, yellow = some offline, red = none)
- Terminal count: same
- Click any location to drill into the detail page

All counters update in real-time as devices connect and disconnect.

### Location Detail — Per-Device Activity Feeds
When you open a location, you see devices grouped by Game Location — the same layout as the client monitor. But now **each device has its own activity feed**:

- PulseBox shows: coin inserts, game starts, ticket payouts, Nayax forwarding, status changes
- Payment Terminal shows: config reloads, price updates, mode changes, payments, blocks

Activities are colour-coded and timestamped. Each entry shows an icon (gamepad for game start, money for coins, ticket for payouts, star for loyalty card, etc.) so you can scan the feed at a glance.

This is a massive upgrade from what was there before — a single global feed where everything was mixed together and you had to read timestamps and MAC addresses to figure out which device did what.

### Remote Commands — From Core to Device
You can send commands to any device directly from Core:

**PulseBox commands:**
- Handshake (force config refresh)
- Get Status
- Send Pulses / Start Game (with configurable pin, count, duration, payout mode)
- Dispense Tickets
- Restart
- Check for Update
- Custom JSON command

**Payment Terminal commands:**
- Reload Configuration
- Update Prices
- Change Mode (Arcade / Attended)
- Block / Set Status (Active / Maintenance / Wait for Service)
- Reboot

Commands flow: Core browser → daemon-core → daemon-pulse → device. The response flows back the same way and appears in the device's activity feed.

### Reliability
We found and fixed several issues in the real-time pipeline to make sure events and commands flow reliably across the full chain:

- Activity events (loyalty card taps, coin inserts, etc.) now reliably reach Core — even after network interruptions or service restarts
- Commands from Core now reach all device types correctly — PulseBox and Payment Terminal
- Device status changes are reported exactly once (no duplicate events)
- Loyalty card activity now shows the card number and amount instead of generic "0 points"

---

## 2. Automatic Terminal Blocking & Unblocking

### The Problem
A PulseBox controls the game. A Payment Terminal takes the payment. If the PulseBox goes offline but the terminal is still active, customers pay but the game doesn't start. That's a refund waiting to happen.

### The Solution
The Device Health Checker now **automatically blocks the Payment Terminal** when its paired PulseBox goes offline, and **automatically unblocks it** when the PulseBox comes back online.

Here's the flow:
1. PulseBox goes offline → daemon-pulse broadcasts the disconnect
2. Within ~5 seconds, daemon-pulse triggers an immediate health check via HTTP
3. The health checker sees the PulseBox is offline, the location is open, and the paired terminal is still active
4. It sends a `block_device` command to the terminal via WebSocket — the terminal immediately shows "Wait for Service" in multiple languages
5. An alert is created: "PulseBox offline" with a child alert "Terminal auto-blocked"
6. When the PulseBox comes back online, the reverse happens: alert resolved, terminal unblocked, back to normal

**The critical fix:** unblocking now happens **regardless of whether the shop is open or closed**. Previously, if a PulseBox went offline while the shop was open (terminal blocked), and came back online after closing — the health checker skipped everything because the shop was closed. The terminal stayed blocked until the next day. Now: blocking only happens when open, but unblocking always happens. If the device recovered, clean it up.

### Instant Reaction vs Periodic Check
Two systems work together:

- **Real-time hook** — daemon-pulse triggers an immediate HTTP health check on every PulseBox connect/disconnect. Reacts within ~5 seconds. Handles 99% of cases.
- **Periodic cron** — the `DeviceHealthChecker` command runs every few minutes as a safety net. Catches anything the real-time hook might miss (network issues, daemon restart, etc.).

### Alert Chains
When the system auto-blocks a terminal, the terminal's alert stores a reference to the PulseBox alert as `idParent`. This creates a clear cause chain that's visible in the UI.

### Device Health Page (Client)
New page in the client sidebar (right after Dashboard, visible to everyone):

- **Active Issues** — grouped by incident. A PulseBox going offline and its terminal getting blocked is shown as one card, not two separate rows. Root cause is prominent ("PulseBox PB-Name — Offline"), consequence shown below ("Terminal PT-Name — Blocked — Automatic").
- **Recent History** — last 30 alerts with status (active/resolved) and timestamps
- **Live counter** — red badge on the menu item, polls every 30 seconds, shows only root-cause count (not children)

The page focuses on what operators need: **which game is affected** (game location name is the first thing you see), not which device has which MAC address.

---

## 3. Game Location — Clearer, Faster, Smarter

### Redesigned Detail View
The Game Location detail panel got a complete visual overhaul. Instead of one long form where everything blends together, fields are now organised into clear sections with colour-coded headings:

- **QR Code** — assign, preview, download
- **Info** — location, game, serial, label, parent machine, position
- **Business Settings** — global/location/individual pricing toggle
- **Coin Acceptor** — accept coins, coefficient, effective date
- **Tags & Notes** — shared tags, game location tags, comments
- **Status** — status, effective date, Nayax POS

The box header now shows the game label + ID + status badge — so you immediately know which game you're editing and whether it's active.

The same layout is applied to the "New Game Location" form for consistency.

### No More Full Table Reload on Save
Previously, saving a Game Location reloaded the entire DataTable — destroying scroll position, losing context, and causing visible flicker. Now, when you save and the game stays in the same location, **only the changed row updates**. The detail panel stays open with the values you just saved. No flicker, no lost position.

If the game moves to a different location, the full reload still happens — because the row should disappear from this list.

### Active Row Highlighting
When you click a game in the list, the row highlights in blue and the detail panel auto-scrolls into view.

---

## 4. PulseBox — Registration & Enforcement

### PulseBox Registration Page
New standalone registration page: `/action/pulse-box/new?mac=10200BA1234`

Same flow as Payment Terminal registration:
1. MAC address is validated and formatted automatically (handles raw hex, adds colons)
2. If already registered → shows the existing device info (name, status, location, game)
3. If new → shows the full creation form with MAC pre-filled and read-only

### One Game = One PulseBox (Enforced)
A game location can only have one PulseBox at any time. The system now enforces this:

- When selecting a game location for a PulseBox (create or edit), the dropdown shows two groups: **Available** (no PulseBox) and **Assigned to PulseBox** (showing which device, e.g., "Claw Machine [PB-1234]")
- If you assign a game location that already has a PulseBox, the system **automatically releases it** from the other PulseBox, syncs the old device, and assigns it to the new one
- All syncs (new PulseBox and old PulseBox) are triggered automatically

### Selective Firmware Versions Per Location
New setting in Location (SYS only): **Sapiens Pulse Version**

- **"Sapiens" (default)** — follows the global active/stable firmware version. Nothing changes.
- **Specific version** — pin a location to a particular firmware version. PulseBoxes at that location receive that version instead of the automatic one.

This applies to:
- The firmware update check (`/api/v1/request/update`) — when a PulseBox asks for the latest version, the pinned version is returned instead
- The hardware config (`getHwConfig()`) — the version field in the config synced to the NUC reflects the pinned version
- Unsupported versions are blocked for non-pinned locations but **allowed for pinned ones** — that's the whole point of pinning

Use case: test new firmware on one location before rolling out. Or keep a problematic location on a known-good version while investigating.

---

## 5. VAT — Cascading System

### The Problem
Previously, to set a different VAT rate for a product at a specific location, you had to enable "Custom Settings" for that product-location — which also forced you to manually configure every other setting (price, status, reward, visibility). Just to change the VAT from 21% to 7%.

Even worse: if a new location had a different tax regime (like the Canary Islands with IGIC instead of IVA), you'd have to manually set the VAT for every single product at that location. Hundreds of products, one by one.

### The Solution: Three-Level Cascade
VAT rates now follow a simple cascade: **Product-Location → Location → Country**

Each level can be set to **"Sapiens"** (default) which means "inherit from the level above":

| Product-Location VAT | Location VAT | Result |
|----------------------|-------------|--------|
| Sapiens | Sapiens | Country VAT (original behaviour) |
| Sapiens | 7% | **7%** (location default applies to all products) |
| 0% (exempt) | 7% | **0%** (product-specific override wins) |
| 21% | 7% | **21%** (product-specific override wins) |

**Practical example — Canary Islands:**
1. Set the Location's VAT to 7% IGIC (one setting, done once)
2. Every product at that location automatically uses 7% — zero manual work
3. New products added to the location default to "Sapiens" → they get 7% automatically
4. If one specific product needs 0% (exempt), set it on that product-location — it overrides
5. All other locations with "Sapiens" continue using their country rate as before

The VAT selector is now:
- **Always visible** on the product-location form (not hidden behind Custom Settings)
- **Defaults to "Sapiens"** for new products added to a location
- Available as a **Location-level setting** (SYS only) in the Location detail

The cascade is fully implemented end-to-end: Core admin → sync to NUC → materialized view → seller interface → cart → payment. The correct VAT shows on every product button in the selling area.

---

## 6. Location — Quality of Life

### Opening Hours Preview
The Opening Hours tab now has a **schedule checker at the top** — prominent, always visible. Today's date is pre-filled and the schedule loads automatically when you open the tab. Pick any date from the datepicker and the schedule checks instantly (no button needed). Shows:

- Day name and date
- Open/closed status
- Time slots
- Whether it's a holiday or holiday eve (with proper labels — no more mysterious "Active" badge)

### Open/Closed Status in Header
The location's current open/closed status now shows in the **top navigation bar** instead of inline above the tabs. Hover over it to see today's opening hours as a tooltip.

### Odoo Settings — Load on Demand
For SYS users, the Odoo settings section no longer loads automatically — it was making 4 API calls to Odoo on every page load, which was slow and would crash the page if Odoo was down. Now there's a "Show" button that loads the settings when you actually need them. If you save without loading them, existing Odoo configuration is preserved untouched.

---

## 7. NFC Payment — Service Card Handling
When a loyalty card plays a game via a Payment Terminal, the system now checks if it's a **service card**. Service cards are staff cards used for testing and management. When a service card starts a game, the ticket payout mode is automatically set to **paper** instead of virtual — so no virtual tickets are credited to a service card that nobody will redeem.

---

## 8. Sii & Odoo — Filter Buttons
The SII Schedule and Odoo Journal Entry list pages now have a proper **Filter button**. The filters (location, date from, date to) existed before, but there was no way to apply them without clicking a pagination link. Now you click the button, the filter applies, page 1 loads with filtered results.

---

## 9. Full NUC Sync — Now Complete
The `SyncNuc` command (full re-sync of everything to a location's NUC) was missing two important entities:

- **Game Locations** — the game configuration, assignments, and business settings
- **Payment Terminals** — device config, mode, prices, game assignments

Both are now included. The full sync covers: Organization, Location, VAT Rates, Loyalty Card Contexts, Loyalty Tiers, Product Locations, Activity Packages, Holidays, Loyalty Card Packages, Game Locations, PulseBoxes, and Payment Terminals.

---

## 10. NFC/QR Payment — Faster & Smarter

### PulseBox Status Check — Now Instant
When a customer scans a QR code on a game to pay with their phone, Sapiens needs to verify the PulseBox is online before authorising the payment. Previously, this check went through the client NUC via Tailscale VPN — reliable, but slow (1-3 seconds).

Now, Sapiens asks daemon-core first (same Docker network, under 5ms). If daemon-core knows the device status, the answer comes back instantly. If daemon-core is unavailable, it falls back to the old path. The customer experience goes from "tap... wait... wait... game starts" to "tap... game starts".

### Location-Filtered Top-Up Packages
When a customer tops up their loyalty card via NFC/QR payment, the system now filters available packages **by location**. If a package is restricted to specific locations or countries, customers at other locations won't see it. Previously, all active packages were shown regardless of location — leading to confusion when a package available only in Spain appeared at a Portuguese location.

---

## 11. Odoo & Accounting Fixes

### VAT Rounding Fix
Fixed a subtle rounding issue in Odoo journal entry VAT calculations. The previous formula calculated base first and VAT as remainder, which could produce 1-cent rounding errors on certain amounts. Now VAT is calculated first (matching how tax authorities expect it), and base is derived from that. Affects Nayax transactions, loyalty card usage entries, and cash collection journal entries.

### Odoo Reconciliation Tool
Improved the reconciliation logic for detecting mismatches between Sapiens records and Odoo journal entries.

---

## 12. Opening Hours — Holiday Intelligence

### Per-Day Holiday Detection
The opening hours system now efficiently detects holidays for a specific day without loading the entire holiday calendar. When checking if a location is open on a given date, it queries only that day — checking location-specific holidays first, then national ones.

### Holiday Eve Support
The schedule checker now properly handles **holiday eves** — the day before a holiday can have its own special opening hours. Previously, holiday eve schedules existed but weren't surfaced in the schedule checker UI. Now they're detected and labelled clearly: "Holiday Hours" for custom holiday schedules, "Holiday" for standard closures, and "Holiday Eve Hours" for modified pre-holiday schedules.

### Proper Labels
Fixed the confusing "Active" label that appeared when viewing a holiday's schedule — it was using the holiday status translation instead of the holiday name. Now correctly shows "Holiday" or "Holiday Eve" so operators know why the schedule is different.

---

## 13. daemon-core — The New Backbone

This is a new service that didn't exist before and makes centralised monitoring possible.

**daemon-core** sits between all your locations and the Core admin interface. Every location connects to it automatically, and it keeps track of which devices are online, what's happening, and routes your commands to the right place.

- Each location connects and reports its devices. If a location loses connection, daemon-core detects it and marks all its devices as offline.
- When you open the monitoring page, you get live data immediately — no polling, no refresh buttons. Events appear as they happen.
- Commands you send from Core reach the target device within milliseconds — daemon-core routes them to the right location automatically.
- It only sends activity data (coin inserts, game starts, etc.) when someone is actually watching. No wasted bandwidth when nobody's looking.

If daemon-core restarts, everything reconnects within seconds. No data is lost, no manual intervention needed. It's designed to be invisible — you just open the page and everything works.

---

## 14. Under the Hood

- **Device health tracking** — improved database schema for better performance and consistency
- **Alert tracking** — alerts now record who resolved them and link to their root cause (e.g., "terminal blocked because PulseBox went offline")
- **Translation coverage** — new translations across English, Spanish, and Portuguese for all new features
- **Performance** — device lookups are now cached in memory, so pages with multiple devices load faster
- **Code quality** — cleanup and standardisation across all modified templates and controllers

---

That's April. 14 sections. We counted.

A lot of it is infrastructure — daemon-core, monitoring, health automation, cascading VAT, firmware management. The kind of work that doesn't make for flashy screenshots but compounds over time. The monitoring alone changes how you manage 40 locations: instead of waiting for a customer to complain that a machine doesn't work, the system detects it in 5 seconds, blocks the terminal so nobody pays for a broken game, and unblocks it automatically when it's fixed. No human intervention. No angry customer. No refund.

That's what infrastructure does. It makes problems invisible.

More coming.

*— The Sapiens Team*
