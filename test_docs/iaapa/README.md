# SapiensCore — Booklet v2 (preview)

IAAPA London 2026 booklet · v2 · for review.

---

## How to open

You need a tiny local HTTP server (Python builtin on Mac/Linux, no install).
Opening the HTML directly from Finder breaks image loading in some browsers.

```bash
cd sapienscore-booklet-v2-preview
python3 serve.py 8765
```

Then open:

- **http://localhost:8765/book_en_v2.html** — the clean, print-ready version
- **http://localhost:8765/book_en_v2_skinned.html** — same booklet + **font switcher** (◐ pill, top right) to try 13 alternative typographies

The `_skinned` build is just for playing with fonts and picking a final one.
The content is identical between the two files.

Ctrl-C to stop the server.

---

## What's in the bundle

- `book_en_v2.html` — the final booklet (115 pages: cover + TOC + 6 sections + 16 chapters + closing + back cover)
- `book_en_v2_skinned.html` — same booklet with the font switcher widget
- `serve.py` — local HTTP server with no-cache headers, bound to 127.0.0.1 only
- `images/` — 24 editorial dark-mood chapter backgrounds + 3 device catalogue photos in `images/devices/`

---

## Navigation

- **Left/right arrows** at the bottom = previous/next page
- **☰ Chapters** = jump-to chapter (interactive TOC with every section and chapter)
- **📸 Export** = screenshot the current page (handy for sharing individual pages)

Only on `_skinned.html`:
- **◐ Pill, top right** = font switcher (13 alternatives, default Playfair Display). The choice persists across reloads via localStorage.

---

## Status

- TEXT FROZEN — Salvo's v2.1 content, verbatim
- Consecutive pagination p1 → p115
- 13 chapter background images generated in a consistent editorial style (amber light + Monocle-style chiaroscuro)
- Hardware (iM25, PulseBox, Case LED) on pricing cards at p108, each with its own catalogue photo

Final print format: **A5 landscape**, Mixam PUR binding, 216×154 mm with bleed.
