# Hosting Platform

## Status

Accepted — self-hosted Docker Compose + GHCR

## Context

The app needs a production hosting environment. Key constraints:

- **Dual SQLite databases** — primary app DB and a transient Anki import DB. Any
  platform must provide a persistent filesystem or the primary DB must be migrated
  to Postgres. Avoiding that migration is strongly preferred.
- **Rails 8 + Kamal 2** — Rails 8 ships with Kamal 2 pre-configured. Using it keeps
  the deployment toolchain in the framework's own orbit and works with any target
  that accepts SSH + Docker.
- **Budget** — personal app, low traffic. Minimise running costs.
- **Preview deployments** — each PR should get an ephemeral environment for QA.
- **Background workers** — Solid Queue will need a worker process alongside the web
  process.

## Options ruled out

These are off the table regardless of final target:

- **Heroku** — no persistent filesystem means SQLite requires a Postgres migration.
  Adds cost and complexity for no functional gain at this scale.
- **Vercel** — serverless-only, fundamentally incompatible with a stateful Rails app.
- **Fly.io / Render** — both viable but add platform-specific config layers over what
  Kamal already handles. Not meaningfully better than a VPS at this scale.

## Options under consideration

### Option A: Hetzner CX22 + Kamal 2

**Hetzner CX22** (Helsinki or Falkenstein datacentre)
- 2 vCPU (Intel x86), 4 GB RAM, 40 GB SSD
- €4.51/month, billed hourly

The cheapest credible production VPS. x86 architecture means no multi-arch Docker build
complexity. At this scale (single user, SQLite, low traffic), the CX22 has comfortable
headroom for the web process, Solid Queue worker, and several idle preview containers
simultaneously.

Preview deployments: each PR deployed as a named Kamal service on the same server,
accessible at `pr-<number>.preview.<domain>`. Kamal Proxy handles subdomain routing.

| Item | Monthly | Annual |
|------|---------|--------|
| Hetzner CX22 | €4.51 | €54.12 |
| Backblaze B2 (Litestream backup) | €0 | €0 |
| Domain (if new) | — | ~€10–15 |
| **Total** | **~€4.51** | **~€64–69** |

---

### Option B: AWS EC2 + Kamal 2

AWS offers a familiar, well-documented cloud environment with a large ecosystem.
Kamal deploys identically to EC2 as to any other SSH-accessible server.

**Recommended instance for this workload:**

| Instance | vCPU | RAM | On-demand | 1yr reserved | 3yr reserved |
|----------|------|-----|-----------|--------------|--------------|
| t4g.small (ARM) | 2 | 2 GB | ~$13.36/mo | ~$8.03/mo | ~$5.62/mo |
| t3.small (x86) | 2 | 2 GB | ~$15.18/mo | ~$9.49/mo | ~$6.72/mo |
| t3.medium (x86) | 2 | 4 GB | ~$30.37/mo | ~$18.98/mo | ~$13.36/mo |

Rails 8 + Puma + Solid Queue is comfortable at 4 GB RAM (t3.medium). 2 GB (t3.small)
is workable for personal-scale traffic but leaves less headroom.

Additional AWS costs on top of the instance:

| Item | Monthly |
|------|---------|
| EBS gp3 volume (20 GB) | ~$1.60 |
| S3 (Litestream backup, <10 GB) | ~$0.23 |
| Data transfer out (personal scale) | ~$0 |
| Elastic IP | $0 (attached to running instance) |

**Realistic total (t3.small, on-demand):**

| Item | Monthly | Annual |
|------|---------|--------|
| EC2 t3.small | ~$15.18 | ~$182.16 |
| EBS 20 GB | ~$1.60 | ~$19.20 |
| S3 Litestream | ~$0.23 | ~$2.76 |
| **Total** | **~$17.01** | **~$204.12** |

With 1-year reserved t3.small: ~**$11.32/month** (~$135.84/year).

**AWS-specific considerations:**

- VPC, security groups, and IAM add setup overhead that Hetzner + Kamal avoids.
- Free tier covers a t2.micro (1 GB RAM) for 12 months — too small for this app
  under any real load, but useful for initial deploy testing.
- S3 is more reliable than Backblaze B2 for Litestream, but at ~$0.23/month the
  cost difference is negligible.
- CloudWatch provides built-in log aggregation and metrics — reduces the need for
  third-party observability tooling.
- EC2 t4g (ARM/Graviton) is ~12% cheaper than equivalent t3 (x86) but requires
  multi-arch Docker builds or an ARM-specific image.

---

### Option C: Self-hosted (selected)

A Docker Compose stack running on self-hosted hardware, fronted by a reverse
proxy or tunnel. No monthly hosting cost.

**Deployment pipeline:**

1. CI builds the Docker image on merge to `main` and pushes to GHCR (GitHub
   Container Registry) using the auto-injected `GITHUB_TOKEN` — no credentials
   to manage.
2. The image is tagged with both `latest` and the short commit SHA.
3. The container host runs the stack via `docker-compose.yml`. Redeployment is
   triggered externally (e.g. via a webhook) after a new image is pushed.

**Storage:** all SQLite databases live in a single named Docker volume mounted
at `/rails/storage`. The volume persists across container restarts and image
updates.

**Backup:** Litestream (or equivalent) runs as a sidecar, replicating the
SQLite WAL to any S3-compatible object store for off-host durability.

**Environment configuration:** a `.env` file on the host supplies secrets and
tuning variables. `.env.example` in the repository documents every variable
with descriptions and safe defaults.

---

## Common architecture (applies to all options)

Regardless of target, the deployment and backup approach is the same:

### SQLite: keep, back up with Litestream

SQLite remains the primary database. No Postgres migration.

**Litestream** replicates the SQLite WAL continuously to object storage
(Backblaze B2 or S3). On server failure: restore from the latest replica,
redeploy. Recovery time is minutes.

The Postgres migration issue (#129) remains conditional — only act on it if the
chosen platform has no persistent disk.

### Background workers: Solid Queue as a Kamal accessory

Solid Queue runs as a separate process via Kamal's `accessories` config, with
independent start/stop/rollback from the web process.

### Preview deployments

Per-PR Kamal service on the same server, auth-gated with HTTP Basic Auth at the
proxy level. Each PR gets a subdomain; teardown on PR close via GitHub Actions.

---

## Cost comparison summary

| Option | Monthly (realistic) | Annual | Notes |
|--------|--------------------:|-------:|-------|
| Hetzner CX22 | ~€4.51 | ~€54 | Cheapest, 4 GB RAM included |
| AWS t3.small (on-demand) | ~$17.01 | ~$204 | 2 GB RAM, full AWS ecosystem |
| AWS t3.small (1yr reserved) | ~$11.32 | ~$136 | Requires upfront commitment |
| AWS t3.medium (on-demand) | ~$32.20 | ~$386 | 4 GB RAM, better headroom |
| AWS t3.medium (1yr reserved) | ~$20.81 | ~$250 | Equivalent RAM to Hetzner |
| Self-hosted | ~€0 | ~€0 | Hardware already owned |

Hetzner is **3–7× cheaper** than AWS on-demand for equivalent or better specs.
AWS's premium buys ecosystem depth, managed services, and institutional familiarity —
none of which are blockers at this app's scale.

---

## Decision

**Option C: Self-hosted.** Docker Compose + GHCR. See the self-hosted section
above for the full architecture. The Kamal config (`config/deploy.yml`) is
retained in the repository for reference; a hosted VPS remains a viable
fallback if circumstances change.
