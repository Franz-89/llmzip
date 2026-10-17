# Floor — 2D-first floor editor + live viewer (with generated 3D view)

A real-scale spatial layer over a venue: where things are, how big they are,
how they're oriented, plus the purely-visual objects that exist nowhere else
(walls, sockets, doors). **A view, not a system** — Floor *references*
business entities (`game_location`, `workstation`) via `(type, id_entity)`
and never duplicates their attributes.

**v2 architecture (the Planner-5D lesson): you edit in 2D top-down, 3D is a
generated view.** The 2D canvas is metres-accurate at every zoom; the 3D
scene renders the exact same data read-only.

## How to run

```bash
# 1. Migrations
php utility/updateDatabase.php     # sqlinstall00360 (tables) + 00361 (layer column)

# 2. Frontend bundle (Konva + three.js live only in the floor island)
npm install && npm run build       # emits dist/floor.js + dist/floor.css

# 3. Sample data (a live plan + a what-if draft for one location)
cd utility && php floorSampleData.php <idLocation> [idUser]

# 4. Open
#   /floor/{idLocation}        — editor
#   /floor/view/{idLocation}   — viewer (live device status)
```

## Codebase map

- `App/Model/Floor/*` — AutoDb models: `FloorPlan`, `FloorLevel`, `FloorContent`, `FloorContentPositionHistory` (hypertable, append-only).
- `App/Model/NoDb/Floor/FloorContentType.php` — **the type registry**: per-type behavior + the element library (presets with real dimensions). `FloorLayer.php` — the pre-created domain layers.
- `App/Manager/Floor/FloorManager.php` — business logic + API formatters + underlay management; `FloorBroadcaster.php` — daemon-core fan-out.
- `App/Controller/Admin/Floor/FloorController.php` (SSR shell) + `App/Controller/Admin/API/Local/V1/Floor/FloorApiController.php` (JSON, Trace envelope) behind `FloorAdminAccessMiddleware`.
- `public/assets/adminlte/v2/js/islands/floor/` — the Vue island: `Editor2D.vue` (Konva canvas — THE editor), `Scene.vue` (three.js — the read-only 3D view), palette / layers / underlay / inspector panels, Pinia store.

## Data model

```
location 1─N floor_plan          layout scenario; status 1 live / 2 draft / 3 archived
              1─N floor_level    a storey: wall runs + ceiling height + underlay (detail.underlay)
              1─N floor_content  one placeable: type, kind (1 real / 2 virtual), id_entity,
                                 layer, label, w/h/d, pos_x/y/z, rotation (° Y-only), detail jsonb
                    1─N floor_content_position_history   hypertable; only position is historized
```

- **At most one live plan per location** — Manager rule + partial unique index.
- **Walls** (`floor_level.wall_outline`): a LIST of runs `[{points: [{x,z}…], closed}]` —
  outer shell closed, inner walls open runs. Legacy single-polyline rows are read as one
  closed run; the API always emits the new format.
- **Layers** (`floor_content.layer`): pre-created — architecture / games / IT / furniture /
  power. Registry assigns each type a default; per-placeable override in the inspector;
  visibility + lock toggles in the panel.
- **Clearance** is per-side `{front, back, left, right}` metres in `detail.clearance`,
  drawn as a dashed halo (legacy single numbers auto-migrate on read in the inspector).
  Enforcement is a declared seam — data only.
- **Front-face convention**: rotation 0 faces +Z; the 2D shape carries a front arrow.
- **Position commit** is explicit: dragging only mutates canvas state; "Save layout as-of
  `<date>`" updates current positions AND appends history rows with a user-selectable
  `effective_at` decoupled from `created_at`.

## The 2D editor (`Editor2D.vue`)

Konva stage where **world units are metres** (stage scale = px/m, wheel-zoom to cursor,
adaptive 1 m / 0.25 m grid). Pan = space+drag / middle / right button (viewer: plain
left-drag). Two registry-driven render classes:

- **footprint** (games, tables, workstations, doors…) — true w×d rectangle at scale,
  front arrow, clearance halo (opt-in toggle), dashed stroke = virtual, orange stroke =
  uncommitted move. **Custom selection handles**: a rotate grip above the shape (15°
  snaps, pivots on the shape centre) and 4 corner grips resizing symmetrically around
  the centre (real dimensions persist on release). Konva.Transformer was dropped on
  purpose — it derives its pivot from the full client rect (label/arrow included), which
  made rotation orbit off-centre. Don't reintroduce it.
- **icon** (routers, sockets) — exact position, fixed screen-size glyph that counter-scales
  against zoom, so an 8 cm socket stays clickable at venue zoom.

Selection: click (shift-click adds), **left-drag marquee on empty canvas selects an area**;
the whole selection moves together (drag, arrow-nudge, Del). Placement is **sticky with a
cursor ghost**: pick from the palette (lists stay open, active preset highlighted), stamp
with clicks, Esc to finish — real entities stamp once, grey out, and are guarded
server-side against being placed twice on the same plan
(`floor.error.entity_already_placed`).

**Stacking**: registry `isSurface` types (table, workstation) carry other placeables —
drop or stamp something onto one and its `pos_y` becomes the surface top (a workstation
ON a table). Elevated items show a "▲" caption marker, the exact height in the hover
tooltip and an Elevation field in the inspector (elevation is position: it goes through
the pending/commit flow). The 3D view renders items at their elevation.

**Undo & productivity**: Ctrl+Z undoes uncommitted gestures (moves/rotations/nudges as
batches, placements delete); the toolbar shows an undo button, "discard" clears all
pending. Ctrl+D (or the inspector copy button) duplicates — always as a **virtual** copy
(a real entity exists once). While dragging, red **centre-alignment guides** appear and
snap against other items (0.12 m tolerance).

Two load-bearing canvas rules (both fixed real bugs — don't regress):
- every stroke/dash is **screen pixels** via `strokeScaleEnabled: false` — a world-unit
  stroke becomes a metre-thick dashed ring at low zoom (the "orange rays" bug);
- rebuilds are **deferred while a gesture is live** (`beginInteract`/`endInteract`) — a
  server response mid-drag used to destroy the node under the pointer and snap it back.

Labels: captions are truncated (16 chars), stay **horizontal at any rotation**
(counter-rotated sub-group), auto-hide below 28 px/m, and have a toolbar toggle; the full
label always shows in a hover tooltip. Presets can declare a 2D `shape` — the round table
renders as a circle (cylinder in 3D) with a single-diameter resize.

**Game physical facts** (sqlinstall00362): `game.width/height/depth/weight_kg` — editable
in the game form. Placing a real game seeds its true footprint from the game model;
**linking a planned (virtual) placeholder to a real game adopts its label and dimensions**.
That's the pre-opening workflow: draw the venue, lay out generic planned games, buy the
machines, then transform-to-real one by one.

The viewer (`/floor/view/{idLocation}`) is a **clean full-bleed view** — no toolbar, no
panels, no editing; just the live floor, level pills and the 2D/3D switch. This is the
surface for wall dashboards; device status already streams into it via daemon-core.

Tools: **wall** (click-to-draw runs with live length labels; click near the first point
closes the shell; Enter finishes an open inner wall; select a wall to drag vertices with
the wall and labels following in real time, dblclick removes a vertex, Del deletes the run,
and **clicking a length label lets you type the exact segment length**), **measure** (two
clicks), **calibrate** (underlay scale). Doors/windows/sockets snap to the nearest wall on
placement, **slide along walls** when dragged, and detach if pulled away.

**Wall anchors are live**: runs carry a stable `id` (lazy-migrated on read), an anchor is
`detail.wall = {wallId, offset}` (metres along the run), and anchored items **derive their
position from the wall at render time** — drag a wall vertex and its doors follow in real
time; saving the wall re-anchors them server-side (`reanchorLevelContents`, direct position
write, no history row — the wall moved, not the item). The geometry lives once in
`wallMath.js` (2D + 3D) with a PHP mirror in `FloorManager::resolveAnchor` — keep them in
sync. Legacy `{wallIndex, segmentIndex, offset}` anchors resolve read-only and upgrade on
the next drag.

**Underlay workflow** (create a floor from an existing plan): upload a PNG/JPG of the venue
plan → set opacity → *calibrate* (click two points over a known feature, type its real
length) → *move* to align → trace walls and placeables in vector over it → remove the image.
Stored per storey in `floor_level.detail.underlay` (`{url, storage, path, …}`); the file
goes to **Cloudflare R2** via `CloudflareStorageService` (local
`public/assets/storing/{theme}/floor/{idPlan}/` as fallback), and removal deletes it from
wherever it lives. The image loads `crossOrigin: anonymous` so PNG export stays untainted.

**Walls are a pseudo-layer** (top row of the layers panel): hide to declutter, lock so
clicks in a dense room go to placeables instead of the shell. Related load-bearing fix: a
closed Konva.Line's hit region is its filled interior even without a fill — wall lines set
`fillEnabled: false`, otherwise every click inside the room "selects the wall" and the
marquee never starts.

**Toolbar extras**: zoom-to-fit (also auto on plan open, and in the viewer), PNG export
(grid hidden, 2× resolution — print/share ready), and live level stats (games · seats ·
ΣkW · Σkg from the placeables' metadata).

## The type registry + element library

| type | code | kind | layer | render2d | live status | presets |
|---|---|---|---|---|---|---|
| 1 | gameLocation | real (game_location) | games | footprint | **deviceMac** | upright, driving cabin, claw, pinball, air hockey, basketball, kiddie ride, punch |
| 2 | workstation | real (workstation) | furniture | footprint | **staticField** | counter, desk |
| 3 | table | virtual¹ | furniture | footprint | none | square/round/rect/high |
| 4 | router | virtual | IT | icon | none | router, AP, rack |
| 5 | socket | virtual (wall) | power | icon | none | single, three-phase |
| 6 | door | virtual (wall) | architecture | footprint | none | single, double, emergency |
| 7 | window | virtual (wall) | architecture | footprint | none | standard, wide |
| 8 | stairs | virtual (levels) | architecture | footprint | none | straight, wide |
| 9 | elevator | virtual (levels) | architecture | footprint | none | standard |

¹ `location_table` lives on the sapiensclient NUC (`App/Model/Location/LocationTable.php`
there), not in this DB — cross-system real binding is a later step. Registry + presets are
served inside `plan/detail` (`listType`, `listLayer`) — one source of truth, the frontend
hard-codes nothing.

## MAC → content live-status contract

A `game_location` emits nothing itself. Its attached `pulse_box` / `payment_terminal`
connect to daemon-core keyed by **MAC address** (`daemon:device_status` events via the
SharedWorker bridge). The API resolves MAC → content server-side (`listDevice` with
normalized `macKey`); a placement's live state = **union of its devices' `connected`**.
Workstations render their static DB status. Heartbeats mutate a **non-reactive** map
(`liveIndex`) and both canvases recolour imperatively — live data never enters Vue
reactivity. Edits broadcast Trace-style on topics `floor.plan.{id}` / `floor.location.{id}`
and patch stores in place (last-write-wins, no refetch).

## Decisions & flagged deltas

- **2D-first on plain Konva** (no vue-konva) — same doctrine as the three.js choice: the
  hot paths are imperative; Vue owns the panels around the canvas.
- **Konva.Transformer does NOT compensate stage zoom** — anchors are sized in local units;
  `syncTransformerScale()` keeps them screen-sized. Load-bearing, don't remove.
- Editing in 3D was removed on purpose (the v1 mistake); `Scene.vue` is view-only and
  is the **glTF seam** (`buildContentMesh()`), still grey boxes.
- Single `id_<table> bigserial` PK per repo convention; no `sync` columns (core-only).
- Extra endpoints beyond the original spec: `POST /plan/{id}/level`,
  `GET /entity/{type}/{idLocation}`, and the three `/plan/{id}/underlay` routes.

## Seams, wired to nothing (do not build yet)

Clearance/wall-constraint **validation engine** · **position analytics / heat maps**
(history written, never read — spatial data × transactions is the future gold) ·
**glTF asset pipeline** · **cross-system `location_table` binding** · **plan-apply
reconciliation** (v1 = status flip + per-content transform-to-real) · operator-defined
layers/types (lookup tables when needed).
