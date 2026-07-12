# Threat Assessment: MCP OAuth 2.1 Authorization Server (Doorkeeper + CIMD)

## Status

Accepted — implementation may proceed. The CF service-token fallback
described below has since been fully removed (#401); `/mcp` is Doorkeeper-only
as of that change. A live pentest against this flow is still planned before
Cloudflare Access is opened to "allow anyone" (see "Outstanding
configuration").

## Context

The existing MCP auth model (`docs/threat_assessments/MCP_OAUTH_AUTH.md`) relies
on Cloudflare Access to gate `/mcp`: a service token is minted in the Cloudflare
Zero Trust dashboard and linked to a `User` via `mcp_service_token_id`. Only
whoever holds that dashboard can mint a token, which rules out ever letting
other people self-serve access to their own data through this server.

This change makes the Rails app itself an OAuth 2.1 authorization server for
MCP clients:

- **Doorkeeper** (`config/initializers/doorkeeper.rb`) provides the
  authorization-code + PKCE + token/refresh lifecycle. Every application this
  server ever creates is a public client (`confidential: false`) — there is no
  path that issues a `client_secret`.
- **`Oauth::CimdClientResolver`** (`app/services/oauth/cimd_client_resolver.rb`)
  resolves clients via OAuth Client ID Metadata Documents (CIMD,
  draft-ietf-oauth-client-id-metadata-document) instead of classic RFC 7591
  Dynamic Client Registration. A client's `client_id` is an `https://` URL
  pointing at a JSON document describing it; the server fetches and validates
  it on demand rather than exposing a stateful, unauthenticated `POST
  /register` endpoint. This is deliberate: the MCP authorization spec's
  November 2025 revision made CIMD the recommended (SHOULD) mechanism and
  downgraded DCR to optional (MAY), specifically because CIMD has no
  registration call to spam.
- The resource-owner login step (`resource_owner_authenticator` in the
  Doorkeeper initializer) reuses the app's existing session (the same
  PocketID-backed login every other page uses) — there is no second identity
  system.
- `McpController` (via `McpAuthentication`) originally accepted a Doorkeeper
  bearer token **or** the pre-existing CF Access service-token branch, as a
  transitional fallback while existing clients migrated. The CF Access
  **email-match** branch was deleted first (`cc0c7fa`, "feat: accept
  Doorkeeper bearer tokens on /mcp, drop email auth") — it relied on
  Cloudflare Access's own policy having vetted who could get a JWT in the
  first place, an assumption that would have broken the moment the Access
  policy was loosened to "allow anyone." The
  **service-token** branch was removed in full afterwards (#401), once the
  Doorkeeper flow was confirmed working end-to-end in production — `/mcp` is
  now Doorkeeper-only.

## What the specs say

### MCP Authorization spec (2025-11-25 revision) — Client ID Metadata Documents

> Authorization servers SHOULD support the OAuth Client ID Metadata Document
> mechanism... MCP clients and authorization servers MAY additionally support
> the OAuth 2.0 Dynamic Client Registration Protocol.

This is why DCR is out of scope for this work — CIMD is the primary,
spec-preferred mechanism for clients with no prior relationship to the server,
and building both would mean auditing two client-onboarding code paths instead
of one.

### draft-ietf-oauth-client-id-metadata-document — validation requirements

The draft requires: `client_id` must be an `https://` URL with no fragment,
userinfo, or default port ambiguity; the document's own `client_id` field must
string-match the URL it was fetched from; `token_endpoint_auth_method` must
not indicate a confidential/symmetric method (CIMD clients are inherently
public — there's no channel to deliver a secret through). All of these are
validated in `Oauth::CimdClientResolver#validate_url_shape!` and
`#fetch_and_validate_metadata`.

### OAuth 2.1 (draft) — PKCE is mandatory for public clients

Every application this server registers is public, so PKCE must not be
optional. Enforced via `force_pkce` in the Doorkeeper initializer, which
rejects any authorization request from a non-confidential client that omits
`code_challenge`.

### RFC 6819 §4.4 / general SSRF guidance — server-side requests to
user-supplied URLs

Fetching a CIMD document means making a server-side HTTP request to a URL an
unauthenticated (well, authenticated-but-untrusted) party controls. This is
the single highest-risk piece of this design, addressed in Threat vector 1
below.

## Threat vectors

### 1. SSRF via CIMD metadata fetch

**Description:** An attacker sets `client_id` to a URL that resolves to an
internal address (loopback, RFC 1918 private ranges, link-local/cloud-metadata
addresses like `169.254.169.254`), attempting to make the Rails server issue
requests against internal infrastructure on their behalf.

**Preconditions:** The attacker can reach `/oauth/authorize` (it requires an
authenticated session — see Threat vector 6 — but any logged-in user can
trigger a fetch to an arbitrary URL).

**Mitigation:** `Oauth::CimdClientResolver#fetch_body` uses the `ssrf_filter`
gem rather than a hand-rolled resolve-then-connect check. `ssrf_filter`
resolves the hostname, rejects any result in the standard reserved/private/
loopback/link-local/multicast ranges (IPv4 and IPv6, including IPv4-mapped and
NAT64-encoded IPv6 forms), and — critically — connects to the *validated* IP
address directly (`Net::HTTP.start(hostname, port, ipaddr: validated_ip)`),
not by re-resolving the hostname a second time. This closes the DNS-rebinding
TOCTOU gap a naive "check then connect" implementation would leave open.
HTTPS-only, 3-second open/read timeouts, no redirects followed (`max_redirects:
0` — a redirect is treated as a failure, not silently followed to a different,
unvalidated URL).

**Verdict: Mitigated.** This is the one piece of this design most worth an
independent second look before the planned pentest — see Outstanding
configuration.

### 2. Oversized or slow response (resource exhaustion)

**Description:** A malicious or compromised client host serves an extremely
large or slow-draining response to tie up a Puma worker or exhaust memory.

**Mitigation:** `MAX_BODY_BYTES` (10KB) enforced by aborting the streamed
`read_body` block the instant the accumulated size is exceeded, rather than
buffering the full response first. `OPEN_TIMEOUT`/`READ_TIMEOUT` (3s each)
bound worst-case latency per fetch.

**Verdict: Mitigated.**

### 3. Redirect-based bypass

**Description:** A CIMD URL that passes validation redirects to a second,
unvalidated URL (potentially resolving to a private address, or serving
different content than what was validated).

**Mitigation:** `max_redirects: 0` — any redirect response is treated as a
fetch failure rather than followed. Fail closed.

**Verdict: Mitigated.**

### 4. Cache staleness and negative-result caching

**Description:** A successfully fetched document is cached for
`Oauth::CimdClientResolver::CACHE_TTL` (1 hour) to avoid refetching on every
authorization request. If a *failed* fetch or validation were cached, a
transient failure could incorrectly deny a legitimate client for the TTL
window; conversely, if a since-revoked/compromised document's old redirect_uri
were trusted indefinitely, a compromised client host could take longer than
expected to lose access.

**Mitigation:** Only a successful `fetch_and_validate_metadata` result is
passed into `Rails.cache.fetch` — a raised exception propagates out of the
block without writing anything to the cache, confirmed by spec
(`"does not cache the failure"` in `cimd_client_resolver_spec.rb`). The 1-hour
TTL bounds how long a compromised or since-changed document's old data is
trusted.

**Verdict: Accepted.** An hour is a deliberate balance between "don't refetch
on every single authorize request" and "don't trust stale client metadata
indefinitely." Revisit if real-world usage shows this needs to be shorter.

### 5. Confused deputy across users

**Description:** An access token issued to one user's consent could, through
an implementation error, be usable to read a different user's data.

**Mitigation:** `resource_owner_authenticator` binds the grant to whatever
`Current.user` resolves to via the existing session at consent time — not a
client-asserted identity. `McpAuthentication#user_from_doorkeeper_token` looks
up `User.find_by(id: doorkeeper_token.resource_owner_id)`, and every MCP
resource read is already scoped to that resolved user (unchanged from the
pre-existing CF Access implementation). `spec/requests/mcp_spec.rb` has an
explicit regression test ("cannot read another user's resources") proving a
token minted for one user returns empty results when used to read a resource
scoped to a different user's data.

**Verdict: Mitigated,** with explicit regression coverage.

### 6. Anonymous-triggered fetches / rate limiting

**Description:** `/oauth/authorize` triggers a CIMD fetch as a side effect of
resolving an unrecognized `client_id`. An unauthenticated party spamming this
endpoint with many distinct fake `client_id` URLs could generate significant
outbound request volume or `Doorkeeper::Application` rows.

**Mitigation:** Two layers. First, `Oauth::AuthorizationsController` runs CIMD
resolution in a plain `before_action` (not `prepend_before_action`), which
Rails runs *after* the inherited `authenticate_resource_owner!` — an
unauthenticated visitor is redirected to sign in before any fetch is
attempted, not after. Second, `config/initializers/rack_attack.rb` throttles
`/oauth/authorize` to 30 requests/minute/IP and `/oauth/token` to 20/minute/IP,
sharing counters across Puma workers via the existing `solid_cache` store.

**Verdict: Mitigated.** No TTL-based garbage collection of unused
CIMD-sourced `Doorkeeper::Application` rows exists yet — see Outstanding
configuration.

### 7. PKCE downgrade

**Description:** A client attempts the authorization-code flow without PKCE,
or with a mismatched verifier, to obtain a token without proving possession of
the original authorization request.

**Mitigation:** `force_pkce` in the Doorkeeper initializer. Verified end-to-end
in `spec/requests/oauth/authorization_code_flow_spec.rb`: the token exchange
is rejected both when `code_verifier` is missing entirely and when it doesn't
match the `code_challenge` presented at authorize time.

**Verdict: Mitigated.**

### 8. CF Access transitional exposure — resolved

**Description:** At the time this assessment was written, the service-token
fallback in `McpAuthentication` remained active, and Huw intended to loosen
the Cloudflare Access edge policy to "allow anyone" once Doorkeeper shipped —
at which point Access would provide no identity gating at all for anything it
fronts, becoming pass-through infrastructure, same as Cloudflare Tunnel
already is for ingress.

**Analysis (at the time):** The service-token branch's security did **not**
depend on the Access policy — a service token is a possession-based secret
Cloudflare merely passes through as a header, unrelated to who Access lets
past its own login challenge. It would have remained as safe after the
policy change as before. This is exactly why the *email-match* branch (which
did depend on the policy) was deleted outright rather than kept as part of
that same transition.

**Resolution:** The service-token fallback itself was removed outright in
#401 rather than left running under a loosened Access policy — `/mcp` is now
Doorkeeper-only, so this exposure no longer exists in any form.

**Verdict: Resolved.** No further action needed; superseded by #401.

## What we are not doing, and why

| Measure | Reason not adopted |
|---|---|
| Classic RFC 7591 Dynamic Client Registration | Spec marks it optional (MAY) now that CIMD covers self-registration for MCP clients with no prior relationship to the server; adding both means auditing two onboarding paths for one problem |
| `client_credentials`, `password`, or `implicit` grants | `grant_flows %w[authorization_code]` only — no MCP client needs them, and each additional grant type is additional surface to secure and test |
| Public token introspection endpoint | `allow_token_introspection false` — no third-party resource server consumes these tokens, only this app's own `/mcp`, which validates via `doorkeeper_token` directly |
| Confidential (secret-bearing) clients | Every application this server creates is public (`confidential: false`); `force_pkce` covers the resulting need for proof-of-possession |
| Doorkeeper's own `/oauth/applications` admin UI | Skipped in routing (`skip_controllers :applications, :authorized_applications`) — replaced by the CIMD resolver (automatic) and the settings "Connected apps" panel (user-facing, revoke-only) |
| TTL/garbage-collection job for unused CIMD-sourced applications | Deferred — CIMD rows are cheap (one per distinct client metadata URL) and the security-critical work was the fetch-time hardening, not row cleanup. Track as a follow-up. |
| mTLS / DPoP (RFC 9449) | Disproportionate to the threat level for this app's scale, consistent with the posture already accepted in `MCP_OAUTH_AUTH.md` |

## Approved posture

1. `Oauth::CimdClientResolver` validates client_id URL shape, fetches via
   `ssrf_filter` (validated-IP pinning, HTTPS-only, no redirects, 3s
   timeouts, 10KB cap), and validates document shape (matching client_id,
   non-empty `redirect_uris`, no `client_secret`, no confidential auth
   method) before ever persisting a `Doorkeeper::Application`.
2. Failed fetches/validation are never cached; successful ones are cached for
   1 hour.
3. `force_pkce` is enabled; every application is `confidential: false`.
4. `resource_owner_authenticator` reuses the existing session — no new
   identity system, no credentials this app doesn't already manage.
5. `/oauth/authorize` and `/oauth/token` are throttled via `rack-attack`,
   sharing state across workers via `solid_cache`.
6. `McpController` accepts a Doorkeeper bearer token only — both the
   email-match and service-token CF Access branches have been deleted (#401).
7. Every MCP resource read is scoped to the resolved token's resource owner,
   with an explicit cross-user regression test.

## Outstanding configuration

- **Live pentest before broad release.** This document and the accompanying
  code review are the static/design-level review; a dynamic pentest against a
  running instance is planned before Cloudflare Access is opened to "allow
  anyone" and self-service registration is advertised publicly. The SSRF
  hardening in `Oauth::CimdClientResolver` is the top priority for that
  exercise.
- **CF Access policy change is out-of-band.** Loosening the Cloudflare Access
  policy to "allow anyone" happens in the Cloudflare dashboard, not this
  repo, and should happen only after the Doorkeeper flow is confirmed working
  end-to-end against a real MCP client (Claude Desktop or equivalent).
- **CF service-token fallback sunset — done.** Removed in #401 once the
  Doorkeeper flow was confirmed working end-to-end in production. The
  `CF_ACCESS_AUD` env var and the Cloudflare Access policy in front of `/mcp`
  can now be retired from the deployment stack.
- **CIMD garbage collection.** Not built in this change; track as a follow-up
  if `oauth_applications` grows unexpectedly large in practice.

## References

- MCP Authorization spec (2025-11-25 revision): https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization
- OAuth Client ID Metadata Document (draft): https://datatracker.ietf.org/doc/html/draft-ietf-oauth-client-id-metadata-document
- OAuth 2.1 Authorization Framework (draft): https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1
- RFC 7636 (PKCE): https://www.rfc-editor.org/rfc/rfc7636
- RFC 9728 (OAuth Protected Resource Metadata): https://www.rfc-editor.org/rfc/rfc9728
- RFC 8414 (OAuth Authorization Server Metadata): https://www.rfc-editor.org/rfc/rfc8414
- Doorkeeper gem: https://github.com/doorkeeper-gem/doorkeeper
- ssrf_filter gem: https://github.com/arkadiyt/ssrf_filter
- Prior assessment this supersedes for MCP identity resolution:
  `docs/threat_assessments/MCP_OAUTH_AUTH.md`
