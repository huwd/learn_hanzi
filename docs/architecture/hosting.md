# Hosting Platform

## Status

Accepted — April 2026

## Context

The app needs a production hosting environment. Key constraints:

- **Dual SQLite databases** — primary app DB and a transient Anki import DB. Any
  platform must provide a persistent filesystem or the primary DB must be migrated
  to Postgres. Avoiding that migration is strongly preferred.
- **Rails 8 + Kamal 2** — Rails 8 ships with Kamal 2 pre-configured. Using it keeps
  the deployment toolchain in the framework's own orbit.
- **Budget** — personal app, low traffic. Minimise running costs.
- **Preview deployments** — each PR should get an ephemeral environment for QA.
- **Background workers** — Solid Queue will need a worker process alongside the web
  process.

## Options evaluated

| Platform | Monthly cost | Persistent FS | Preview envs | Notes |
|----------|-------------|---------------|--------------|-------|
| **Hetzner CX22 + Kamal 2** | ~€4.51 | Yes (native) | Yes (same server) | Full control, SQLite native |
| Fly.io | ~€0–5 | Yes (volumes) | Via CI scripting | Good Rails support, more config |
| Render | ~€7+ | Yes (+€0.25/GB) | Paid plan only | Managed PaaS, less control |
| Heroku | ~€12+ | No | Built-in | No persistent FS → Postgres required |
| Vercel | Free–€20 | No | Yes | Serverless only, not suitable |

## Decision: Hetzner CX22 + Kamal 2

### Server spec

**Hetzner CX22** (Helsinki or Falkenstein datacentre)
- 2 vCPU (Intel x86), 4 GB RAM, 40 GB SSD
- €4.51/month, €0.008/hour
- x86 architecture — no multi-arch Docker build complexity

At this scale (single user, SQLite, low traffic), the CX22 has comfortable headroom
for the web process, Solid Queue worker, and several idle preview containers
simultaneously.

### Why not the alternatives

- **Heroku**: no persistent filesystem means SQLite is off the table, requiring a
  Postgres migration that adds cost and complexity for no functional gain.
- **Fly.io / Render**: both viable, but add platform-specific config layers over what
  Kamal already provides. Hetzner + Kamal is simpler and cheaper.
- **Vercel**: serverless-only, fundamentally incompatible with a stateful Rails app.

## SQLite strategy: keep, back up with Litestream

SQLite remains the primary database. No Postgres migration.

**Litestream** replicates the SQLite WAL continuously to object storage:

- **Destination**: Backblaze B2 — free up to 10 GB storage and 1 GB/day egress,
  sufficient for this app indefinitely.
- Litestream runs as a sidecar process managed by Kamal as an accessory.
- On server failure: restore from latest Litestream replica, redeploy. Recovery
  time is minutes, not hours.
- The Postgres migration issue (#129) remains open but conditional — it should only
  be acted on if the hosting platform changes to one without persistent disk.

## Preview deployments: per-PR Kamal service on the production server

Each open PR is deployed as a named Kamal service to the same CX22 server, accessible
at a subdomain: `pr-<number>.preview.<domain>`.

**Mechanics:**
- GitHub Actions workflow triggers on PR open/synchronize
- `KAMAL_SERVICE=pr-<number>` is passed to the Kamal deploy command
- Kamal Proxy routes the subdomain to the correct container
- On PR close, a teardown workflow runs `kamal remove -s pr-<number>`
- Preview databases are ephemeral (seeded from schema, not production data)

**Auth gate:** HTTP Basic Auth injected at the Kamal Proxy level — a shared
credential stored as a GitHub Actions secret. No app-level changes required.

**Resource sharing:** Preview containers are idle most of the time. Three or four
simultaneous open PRs will not meaningfully strain a CX22. If this ever becomes a
problem, a second cheap Hetzner server (CX11, ~€3.29/month) can be added as a
dedicated preview target.

## Background workers: Solid Queue as a Kamal accessory

Solid Queue runs as a separate process deployed via Kamal's `accessories` config.
This keeps the worker lifecycle managed by the same toolchain as the web process,
with independent start/stop/rollback.

## Approximate year-one cost

| Item | Monthly | Annual |
|------|---------|--------|
| Hetzner CX22 | €4.51 | €54.12 |
| Backblaze B2 (Litestream) | €0 | €0 |
| Domain (if new) | — | ~€10–15 |
| **Total** | **~€4.51** | **~€64–69** |

## Consequences

- Kamal 2's `config/deploy.yml` (already scaffolded by Rails 8) needs completing with
  server address, image registry, volume mounts, and accessory definitions.
- Litestream must be added to the project and configured before first production deploy.
- Preview deploy workflow needs to be written in GitHub Actions.
- The `RAILS_ENV=production` SQLite database path must be an absolute path on the
  mounted volume — not a relative `storage/` path — to survive container restarts.
- Backblaze B2 bucket and application key must be provisioned and stored as secrets.
