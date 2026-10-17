# DB connection pooling & stability (plan)

Planned 2026-07-22. **Not yet implemented** — this is the agreed design for adding a
connection pooler + safety timeouts in front of the per-stack Postgres, to fix a
production incident where a load peak returned `too many clients` **and** the DB froze
as if connections were never released.

Companion facts: connection setup lives in `App/InstanceCollector/IC.php`
(`pgFirstConnect()` → `pg_connect`), the DB layer is `salvosav/autodb` (pg_query simple
protocol, no server-side prepared statements), and each stack has its own `database`
service (see `docker-compose-setting/core/<customer>/docker-compose.yaml`).

---

## 1. Current model (the problem)

- Every front controller (`public/index.php`, `nayax.php`, `kiosk.php`, `pulse.php`,
  `device.php`, `pax.php`, `workstation.php`) calls `IC::pgFirstConnect()` at bootstrap.
- That runs **non-persistent** `pg_connect('host=database …')` (`IC.php:27`). AutoDb is set
  `setOnDestructDisconnect(true)` (`IC.php:106`) and `pg_close()`s at request end.
- So **1 HTTP request = 1 full Postgres backend fork + auth + teardown.** Concurrent
  Postgres backends ≈ concurrent in-flight requests across all front controllers.

### Two failure modes seen in the incident

1. **Connection exhaustion / cascade** — a peak (or a device reconnect storm from
   sapiensclient PulseBox/PaymentTerminal all re-requesting core at once) drives concurrent
   backends into `max_connections`. Once exhausted, *nothing new can connect*, including
   admin/monitoring → looks totally frozen. Note: short-lived requests still pile up when
   arrival rate is high and latency degrades (concurrency = arrival_rate × latency).
2. **Stuck / unreleased transaction** — app pattern is
   `try { BEGIN … COMMIT } catch (Exception) { ROLLBACK }` (e.g. `ShippingController.php:155`,
   ~60 call sites). `catch (Exception)` does **not** catch `Error`/fatal/fpm
   `request_terminate_timeout`, so a failure between `BEGIN` and `COMMIT` skips the
   `ROLLBACK` → backend left `idle in transaction` holding locks → everyone waiting on that
   lock blocks → feeds failure mode 1.

Root cause of the specific incident was never confirmed. Diagnosis for next time, §6.

---

## 2. The fix — four layers (defense in depth)

| Layer | What | Fixes | Risk |
|---|---|---|---|
| 1 | PgBouncer container (session mode first) | exhaustion + cascade + churn + retry storms | low |
| 2 | App points at PgBouncer (one line) | — enables Layer 1 | trivial, reversible |
| 3 | Postgres safety timeouts | the stuck/unreleased transaction (root) | low, no restart |
| 4 | `Throwable`/`finally` transaction cleanup | the leak at source | code cleanup, incremental |

PgBouncer **contains** the freeze (bounds blast radius); the **timeouts cure** the stuck
transaction. Ship both — PgBouncer alone treats the symptom.

---

## 3. Layer 1 — PgBouncer service

One service per stack, on `internal_net`, alongside `cache`/`daemon-core`.

```yaml
  pgbouncer:
    image: edoburu/pgbouncer:latest
    environment:
      DB_HOST: database
      DB_PORT: 5432
      DB_USER: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: ${POSTGRES_DATABASE}
      POOL_MODE: session            # phase 1: zero app-semantics risk
      LISTEN_PORT: 6432
      MAX_CLIENT_CONN: 1000         # clients that can queue at PgBouncer
      DEFAULT_POOL_SIZE: 25         # real Postgres backends — the hard cap
      MIN_POOL_SIZE: 5
      RESERVE_POOL_SIZE: 5
      RESERVE_POOL_TIMEOUT: 3
      SERVER_IDLE_TIMEOUT: 240
      QUERY_WAIT_TIMEOUT: 120       # queued client fails instead of hanging forever
      AUTH_TYPE: scram-sha-256      # MUST match Postgres pg_hba (md5 if older)
      SERVER_TLS_SSLMODE: disable   # local Docker-bridge hop; ssl=on is replication-only
      IGNORE_STARTUP_PARAMETERS: extra_float_digits,options
    depends_on:
      database:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - internal_net
```

Two things that bite, pre-empted:

- **`IGNORE_STARTUP_PARAMETERS`** — the php pgsql driver sends startup params PgBouncer
  rejects by default; without this, every connect fails. Include from day one.
- **`AUTH_TYPE` must match** Postgres auth or all connects fail. Check
  `SHOW password_encryption;` (scram-sha-256 on PG16 by default).

## 4. Layer 2 — app change

`IC.php:27`, in `pgFirstConnect()`:

```php
// from
self::$_pgRes = pg_connect('host=database port='.POSTGRES_PORT.' …');
// to
self::$_pgRes = pg_connect('host=pgbouncer port=6432 …');
```

Everything funnels through here — this is the whole app change. **Keep `pg_connect`
(non-persistent)**; let PgBouncer own pooling, not PHP (`pg_pconnect` fights
`setOnDestructDisconnect` and doesn't solve the `max_connections` ceiling). Fully
reversible: point back to `database:5432`. Cleaner: introduce `DB_HOST`/`DB_PORT` env so
the switch is config, not code.

## 5. Layer 3 — Postgres safety timeouts

`idle_in_transaction_session_timeout=30000` + `superuser_reserved_connections=5` live in the
DB `command:` (§12) — global, IaC-visible. **New installs** get them baked in; **existing**
installs get them on the next `compose up` (the DB container recreates, data preserved in the
volume, ~seconds restart). No hand-run SQL required. (Optional zero-downtime shortcut to
apply before a redeploy: `ALTER SYSTEM SET idle_in_transaction_session_timeout='30s';
SELECT pg_reload_conf();` on the primary.)

`idle_in_transaction_session_timeout = 30s` is the highest-value setting — it's what would
have auto-killed the stuck transaction from the incident. It **only** terminates a session
idle *inside an open transaction* (waiting on the client); an actively-running query is never
touched, and a plain idle connection with no open transaction is left alone. Start at 30s
(generous for any legit web transaction), tune down later.

### No `statement_timeout` — deliberate

We do **not** set `statement_timeout` anywhere — not globally, not on the role, not per
request, not even a long one. A query is never killed by a timer. Rationale: the incident
was a *leaked idle transaction*, which `idle_in_transaction_session_timeout` already handles
without touching running work; a role-wide cap would also kill long `CREATE INDEX` migrations
(the app user runs migrations), and we would rather find and kill a genuine runaway query
manually (§11 diagnostics) than risk aborting legit long work.

## 6. Layer 4 — `Error`-safe transaction cleanup

Current `catch (Exception)` leaks on uncaught `Error`/fatal/fpm-timeout (~60 call sites).

1. **Now:** widen critical DB blocks from `catch (Exception)` to `catch (Throwable)`.
2. **Strategic:** add `IC::transaction(callable $fn)` — `BEGIN`+`COMMIT` on success,
   `ROLLBACK` in a `finally` on any throw — and migrate call sites incrementally (not all
   60 at once). With Layer 3 as backstop, any leak that slips past gets reaped in 30s.

---

## 7. Sizing

- `DEFAULT_POOL_SIZE` ≈ 2–4 × DB CPU cores — sized to what Postgres runs *well*
  concurrently, **not** to fpm worker count. That decoupling is the point.
- Postgres `max_connections` ≥ pool_size + reserve_pool + walsenders + CLI/daemon headroom.
- `MAX_CLIENT_CONN` can far exceed pool_size — that queue absorbs the device retry storm.

## 8. Replication — unaffected, with one rule

Streaming replication runs below PgBouncer: the replica connects to the **primary
directly** (walsender). App → PgBouncer → primary; primary → replica untouched.

- **Rule:** never route a replication connection *through* PgBouncer (it can't pool the
  replication protocol). The replica already dials `database` directly — keep it that way.
- The §5 `idle_in_transaction` flag rides in the DB `command:`, so any container (primary or
  replica) that starts from it gets it — harmless on a replica (only bounds its read sessions).
- PgBouncer does **not** do read/write splitting — that's pgcat/pgpool, out of scope.

## 9. Transaction pooling (later, higher density)

Web path is **compatible**: AutoDb uses `pg_query` simple protocol only — no server-side
prepared statements, no `LISTEN`/`NOTIFY`, no session `SET`, no temp tables in the request
path. So after session mode is proven, flip **web traffic to transaction mode** for the big
density win (many clients → few backends).

- **Caveat:** `SyncOutboundDrain.php:117` uses `pg_try_advisory_lock` (session-level). Keep
  CLI/daemon/cron on a **session-mode** port (or direct to `database`); only web goes to a
  transaction-mode port.

---

## 10. Rollout order (each step independently reversible)

1. **Layer 3 first** — pure SQL, no restart, instant safety net.
2. **Layer 1 + 2** — PgBouncer session mode; validate on one stack, then roll out.
3. **Layer 4** — code cleanup at own pace.
4. **Later** — transaction mode for web (§9).

## 11. Validation

- PgBouncer admin console: `SHOW POOLS;` (watch `cl_waiting`, `sv_active`, `sv_idle`),
  `SHOW STATS;`.
- `pg_stat_activity` peak backend count should sit at/under `pool_size` regardless of load.
- Force a retry storm in staging (kill client link, let devices hammer) → core queues
  instead of throwing `too many clients`.

Incident classification query (run during an event or on a sampling cron):

```sql
SELECT state, wait_event_type, wait_event, count(*)
FROM pg_stat_activity GROUP BY 1,2,3 ORDER BY 4 DESC;
```

- many `idle in transaction` → leaked transactions → Layer 3 + Layer 4.
- many `active` / `Lock` wait → lock storm behind a slow writer → find the slow writer and
  `pg_terminate_backend(pid)` it manually (we do not auto-kill via `statement_timeout`).
- many plain `idle` piling up → pure connection churn → PgBouncer.

---

## 12. Deployment integration (how the stack actually wires up)

Verified against `docker-compose-setting/` 2026-07-22. Get these right or the rollout breaks.

**Source of truth = the Jinja template, not the checked-in customer files.**
`docker-compose-setting/templates/core/docker-compose.yaml.j2` is rendered per customer by
ansible. The checked-in `core/souldpark|prod|beta/docker-compose.yaml` files are **stale**
(plain DB, no `command:`) vs the current template (which already overrides DB `command:`
with replication + SSL). Patch the **template** and regenerate; only `core/dev/` is
hand-maintained (dev builds images locally + mounts source, so app changes are live).

**PHP constants come from the bind-mounted `.env` file, NOT docker `environment:`.**
`src/env.php` reads `/var/core/<customer>/.env` and `define()`s each key. The
`POSTGRES_HOST: database` in the compose `environment:` block never reaches PHP —
`IC.php` hardcodes `host=database`. So the host switch is a code + `.env` change.

**Blast radius = one service.** Only `sapienscore` (app + its CLI/cron, which share `IC`)
connects to `database`. `daemon-core` is a WS relay (no DB). Replicas use the walsender
path (direct). Migrations run through the same `IC` path (`update_database.sh` →
`updateDatabase.php` → `IC::pgFirstConnect`).

### The switch — PgBouncer is a standard stack component

Every stack ships PgBouncer (unconditionally, like `cache`). So the app default **is**
PgBouncer. Keep the host as a constant (not a hardcoded literal) purely as a break-glass
bypass; `IC::def()` (`IC.php:125`) returns false when unset, so the default resolves to
`pgbouncer`:

```php
// IC.php pgFirstConnect()
$host = IC::def('DB_HOST') ?: 'pgbouncer';
$port = IC::def('DB_PORT') ?: '6432';
self::$_pgRes = pg_connect('host='.$host.' port='.$port.' password='.POSTGRES_PASSWORD
    .' user='.POSTGRES_USER.' dbname='.POSTGRES_DATABASE);
```

- Default = PgBouncer everywhere. The pgbouncer container and the app image/compose ship
  **together** (dev is live; prod releases bundle image + compose), so the target always
  exists when the app points at it.
- Break-glass only: set `DB_HOST=database` + `DB_PORT=5432` in a stack's
  `/var/core/<customer>/.env` and restart the app container to bypass PgBouncer during an
  incident — no image rebuild.

### File-by-file

| File | Change |
|---|---|
| `App/InstanceCollector/IC.php` | default host → `pgbouncer:6432`, `DB_HOST` override as break-glass |
| `templates/core/docker-compose.yaml.j2` | add `pgbouncer` service (unconditional); append timeout `-c` to DB `command:` |
| `core/dev/docker-compose.yaml` | same, hand-maintained |
| `core/{prod,beta,souldpark}/*.yaml` | regenerate from template (also fixes drift) or hand-patch |

Postgres timeouts: `idle_in_transaction_session_timeout=30000` +
`superuser_reserved_connections=5` are in the DB `command:` (§5) — baked in for new installs,
applied to existing on the next `compose up`. No `statement_timeout` anywhere, by design (§5).

### Breakers to verify before flipping any `.env`

- **SSL: not needed for the app path — use `server_tls_sslmode=disable`.** `ssl=on` on the
  DB exists only for **replication** (`init-replication.sh` writes `hostssl replication
  replicator …`; the walsender stream leaves the host). The app user is governed by the
  default `host all all all scram-sha-256` rule, which permits non-SSL, and app→pgbouncer→DB
  is a private Docker-bridge hop that never leaves the box — TLS there is wasted CPU. (Today
  the app connects with libpq default `sslmode=prefer`, so it silently negotiates TLS on the
  local hop for nothing; `disable` removes that overhead.) Auth is still `scram-sha-256`
  (pgbouncer uses the app password it gets via env) — that's independent of transport.
- **Template drift:** patch the `.j2`, don't hand-edit a single customer file (ansible
  overwrites it).
- **Transaction-mode later:** web + CLI share `IC`'s `DB_HOST`; splitting web (txn port)
  from CLI/migrations/`SyncOutboundDrain` advisory lock (session port) needs a second
  constant. Phase-2 note.
- **`shm_size`:** souldpark sets `shm_size: '2gb'` on the DB (template gates it behind
  `core_db_shm_size`) — don't drop it when regenerating.

## Open / deferred

- Confirmed root cause of the original incident (unknown; §1 lists candidates).
- sapiensclient device **retry/backoff** behaviour when core is unreachable (the reconnect
  storm source) — separate investigation.
