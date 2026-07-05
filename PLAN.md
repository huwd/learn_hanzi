# PLAN: MCP Server (read) — issue #220 Phase 1

Disposable file — delete before merging.

## Goal

A Rails-mounted MCP server exposing a user's learning state as read-only resources,
consumable by any MCP-compatible AI agent.

## Auth architecture

### Discovery (CF Access handles this — no Rails work needed)

CF Access already serves:
- `www-authenticate: Cloudflare-Access resource_metadata=...` on 302 responses
- `/.well-known/cloudflare-access-protected-resource/` (points to susurrant.cloudflareaccess.com)
- `https://susurrant.cloudflareaccess.com/.well-known/oauth-authorization-server`
  (Authorization Code + PKCE, token revocation, dynamic client registration)

A spec-compliant MCP client discovers the OAuth 2.1 server through this chain automatically.
Rails does not need to serve its own `/.well-known/oauth-authorization-server`.

### Token validation (Rails — new `CfAccessAuthentication` concern)

Once an MCP client holds a CF Access JWT and sends it as `Authorization: Bearer <token>`,
CF Access passes the request through. Rails must:

1. Extract the Bearer token from the Authorization header
2. Fetch JWKS from `https://susurrant.cloudflareaccess.com/cdn-cgi/access/certs` (cached with TTL)
3. Validate: signature, `iss` == `https://susurrant.cloudflareaccess.com`, `aud` matches
   the CF Access application AUD tag, `exp` not passed
4. Extract the `email` claim
5. `User.find_by!(email_address: email)` — user must exist (created on first UI login)
6. Return 401 if any step fails

### ⚠️ Security posture — email claim matching (NEEDS DECISION before implementing)

See threat assessment section below. Implementation should not start until posture is agreed.

## MCP protocol

Transport: Streamable HTTP — single `POST /mcp` endpoint, JSON-RPC 2.0.
No SSE for Phase 1 (read-only, no server-initiated messages needed).
No gem — implement JSON-RPC handling directly (protocol is simple; avoids alpha-gem risk).

| JSON-RPC method             | Behaviour                                              |
|-----------------------------|--------------------------------------------------------|
| `initialize`                | Return server info + capabilities, issue session ID    |
| `notifications/initialized` | Ack, return 200                                        |
| `resources/list`            | Return the 5 resource descriptors                      |
| `resources/read`            | Return content for the requested URI                   |

Session IDs: generated on `initialize`, validated on subsequent requests, stored in Rails cache.

## Resources

All URIs use the `learn-hanzi://` scheme. Each resource returns JSON with no internal IDs —
shaped for agent consumption.

| URI                                  | Description                                              | Key fields                                    |
|--------------------------------------|----------------------------------------------------------|-----------------------------------------------|
| `learn-hanzi://profile`              | Summary: counts by state + HSK level breakdown           | state counts, hsk_breakdown                   |
| `learn-hanzi://vocabulary/mastered`  | Consolidated words, newest first                         | hanzi, pinyin, meaning, mastered_at           |
| `learn-hanzi://vocabulary/struggling`| Learning words ranked by lapse count desc, low factor   | hanzi, pinyin, meaning, lapse_count, factor   |
| `learn-hanzi://vocabulary/recent`    | Words mastered in last 30 days                           | hanzi, pinyin, meaning, mastered_at           |
| `learn-hanzi://vocabulary/active`    | Words in learning queue, ordered by next_due            | hanzi, pinyin, meaning, next_due, factor      |

Lapse count is derived: `review_logs.where(ease: 1).count` per `user_learning`.
No denormalised counter needed at this data volume.

## Commit sequence (TDD, red → green → refactor per step)

- [x] 1. `CfAccessAuthentication` concern — JWT validation + user resolution
- [x] 2. `McpController` — routing, session management, `initialize` handshake
- [x] 3. `resources/list` — return all 5 resource descriptors
- [x] 4. `learn-hanzi://profile` resource
- [x] 5. `learn-hanzi://vocabulary/mastered` resource
- [x] 6. `learn-hanzi://vocabulary/struggling` resource (lapse count derivation)
- [x] 7. `learn-hanzi://vocabulary/recent` resource
- [x] 8. `learn-hanzi://vocabulary/active` resource

## ⚠️ Threat assessment: email claim matching

### The concern

`CfAccessAuthentication` will extract the `email` claim from the CF Access JWT and call
`User.find_by!(email_address: email)`. This implies absolute trust between the email
address we hold and the one asserted by CF Access. Several vectors to assess:

### What the specs say

**OpenID Connect Core §5.7** — the `email_verified` claim:
> Relying Parties MUST NOT trust an email claim unless `email_verified` is present and true.

CF Access JWTs do not include `email_verified`. CF Access uses email as the `sub` claim
(its primary stable identifier), which is unusual — most OIDC providers use an opaque UUID
for `sub`. This means email is both the identity and the lookup key.

**OAuth 2.0 Security BCP (RFC 9700) §2.1**:
> Use `sub` for user identification. Email is mutable and potentially unverified.

**The specific risks:**

1. **Unverified email registration** — if PocketID does not enforce email verification,
   an attacker who can create a PocketID account could claim any email address and, if CF
   Access lets them through, gain access to another user's data via the email lookup.

2. **Email mutability** — if a user changes their email in PocketID, the CF Access JWT
   carries the new email. `find_by!(email_address: new_email)` fails → 401. Data is not
   compromised but access is silently broken until email is updated in Rails too.

3. **Cross-application token reuse** — a CF Access JWT issued for a different application
   on the same team could be presented here. Mitigated by validating the `aud` claim against
   this application's specific AUD tag.

4. **JWT forgery** — only relevant if JWKS validation is implemented incorrectly (e.g.,
   accepting `alg: none`). Must explicitly validate algorithm and match against fetched JWKS.

### Our posture

**Mitigating factors for this application:**
- Personal app, single user. CF Access policy already restricts authentication to one
  identity. The practical attack surface is near zero.
- CF Access is a signed, trusted intermediary — the email claim is as authoritative as
  CF Access itself.
- PocketID is self-hosted and controlled by the app owner.

**Recommended posture (to confirm before implementing):**

Match on `email` but add defensive layers:
- Validate `aud` strictly — only accept tokens for this app's AUD tag (stops cross-app reuse).
- Validate `iss` strictly — only `https://susurrant.cloudflareaccess.com`.
- Reject if user not found (no auto-creation via MCP path) — existing UI login is the
  user creation gate.
- Log and reject if `email` claim is absent.
- Accept the email mutability risk as operational (not security) — if email changes,
  access breaks gracefully rather than dangerously.

**What we are NOT doing, and why:**
- Not checking `email_verified` (not present in CF Access JWTs).
- Not storing CF Access `sub` as a separate identifier (would require a migration and a
  new linkage table; overkill for a personal single-user app).
- Not implementing token binding or mTLS (disproportionate to threat level).

**Open question:** Does PocketID require email verification before accounts are active?
If yes, risk 1 is eliminated at source. Worth confirming in PocketID config before
signing off on this posture.

### Decision

- [x] PocketID enforces email verification — unverified-email risk eliminated at source
- [x] CF Access AUD tag confirmed — store as `CF_ACCESS_AUD` env var (never commit)
- [x] Email-match posture above is signed off — no need to store CF Access `sub` separately

**Posture is approved. Implementation of `CfAccessAuthentication` can proceed.**
