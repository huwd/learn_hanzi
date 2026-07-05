# Threat Assessment: MCP Server OAuth Authentication

## Status

Accepted — email-match posture approved, implementation may proceed.

## Context

The MCP server (issue #220) exposes a user's learning state to AI agents. It sits
behind Cloudflare Access, which acts as the OAuth 2.1 authorization server. After a
client completes the CF Access OAuth flow, it presents a signed CF Access JWT as a
Bearer token. Rails must validate that JWT and resolve it to a `User` record.

The proposed resolution strategy is to extract the `email` claim from the CF Access JWT
and call `User.find_by!(email_address: email)`. This document assesses the risks of that
approach.

## What the specs say

### OpenID Connect Core §5.7 — `email_verified`

> Relying Parties MUST NOT trust an email claim unless `email_verified` is present
> and `true`.

CF Access JWTs do not include `email_verified`. However, CF Access uses `email` as the
`sub` claim — its primary stable user identifier — which is unusual. Most OIDC providers
use an opaque UUID for `sub`; CF Access uses email for both. This means email is
authoritative *within CF Access's own identity model*.

### OAuth 2.0 Security Best Current Practice (RFC 9700) §2.1

> Use `sub` for user identification. Email is mutable and potentially unverified.

The concern here is that email addresses can change and may not be verified. Both risks
are assessed below.

### RFC 9700 §4.8 — Audience restriction

> Access tokens MUST be audience-restricted. Authorization servers SHOULD include
> the `aud` claim. Resource servers MUST verify it.

CF Access JWTs include an `aud` claim containing the application's AUD tag (a
SHA-256 hash unique to each CF Access application). Failing to validate this allows
a token issued for a different CF Access application on the same Cloudflare team to be
accepted here.

## Threat vectors

### 1. Unverified email registration

**Description:** An attacker registers a PocketID account using a victim's email address
without verifying it, authenticates through CF Access, and obtains a JWT asserting the
victim's email. Rails resolves the JWT to the victim's `User` record.

**Preconditions:** PocketID does not require email verification; attacker can register a
PocketID account; CF Access policy permits that account.

**Verdict: Eliminated.** PocketID enforces email verification before accounts are
activated. An account with an unverified email cannot authenticate. Confirmed 2026-07-05.

---

### 2. Cross-application token reuse

**Description:** An attacker obtains a valid CF Access JWT issued for a different
application on the `susurrant` Cloudflare team and presents it to the MCP endpoint. If
`aud` is not validated, the token is accepted.

**Preconditions:** Attacker has legitimate access to another CF Access application on the
same team; Rails does not validate `aud`.

**Likelihood:** Low — requires the attacker to hold a valid token for a co-hosted
application. Higher risk if this Cloudflare team hosts applications with different
trust levels or different user populations.

**Mitigation:** Validate the `aud` claim strictly against this application's CF Access
AUD tag. Configured as `CF_ACCESS_AUD` in the environment. Any JWT whose `aud` does not
include this value is rejected with 401.

**Verdict: Fully mitigated by `aud` validation.**

---

### 3. Email mutability — access breakage

**Description:** A user changes their email address in PocketID. CF Access issues JWTs
with the new email. `User.find_by!(email_address: new_email)` returns nil → 401. The
user's data is not exposed, but MCP access is silently broken until the email is updated
in Rails (via a UI login, which triggers `find_or_create_by_omniauth` and updates the
stored email).

**Preconditions:** User changes email in PocketID.

**Likelihood:** Low — email changes are infrequent and the recovery path (UI login) is
simple.

**Security impact:** None. Data is not accessible to the wrong party; access is denied.

**Verdict: Operational risk only, not a security risk. Accepted.**

---

### 4. JWT forgery

**Description:** An attacker crafts a JWT asserting an arbitrary email claim and signs it
with a weak or no-op algorithm (`alg: none`, or a symmetric key they control). A naive
implementation that does not validate the signature or algorithm accepts the forged token.

**Preconditions:** Implementation fetches JWKS but does not validate the `alg` header, or
accepts tokens with `alg: none`.

**Likelihood:** Entirely dependent on implementation correctness.

**Mitigation:**
- Fetch JWKS from `https://susurrant.cloudflareaccess.com/cdn-cgi/access/certs` using
  the `kid` header to select the correct key.
- Explicitly allowlist expected algorithms (CF Access uses RS256).
- Reject any token with `alg: none` or an unexpected algorithm.
- Validate `iss == https://susurrant.cloudflareaccess.com`.
- Validate `exp` (not expired), `nbf` (not before, if present).
- Cache JWKS with a TTL; re-fetch on unknown `kid` to handle key rotation.

**Verdict: Fully mitigated by correct implementation.**

---

### 5. JWKS cache poisoning

**Description:** If the JWKS cache can be poisoned (e.g., via a DNS hijack or a
compromised CDN), an attacker could substitute their own public key and forge valid
JWTs.

**Preconditions:** Network-level attacker between the Rails server and
`susurrant.cloudflareaccess.com`; or CDN/DNS compromise of that endpoint.

**Likelihood:** Very low. The JWKS endpoint is Cloudflare-hosted infrastructure with
TLS. A network-level attacker capable of this also has much simpler attack paths.

**Mitigation:** TLS validation on the JWKS fetch (standard). No additional mitigations
warranted at this threat level.

**Verdict: Accepted.**

---

### 6. Token replay after expiry (absent)

CF Access JWTs are short-lived (typically 20 minutes). The `exp` claim is validated on
every request. A leaked token is usable only until expiry.

**Verdict: Accepted. Mitigated by expiry validation and short token lifetime.**

## What we are not doing, and why

| Measure | Reason not adopted |
|---|---|
| Check `email_verified` claim | Not present in CF Access JWTs |
| Store CF Access `sub` as a separate identifier | `sub` = email in CF Access; adds a migration and linkage table for no additional security |
| Token binding / mTLS | Disproportionate to threat level for a personal single-user app |
| Auto-create users via MCP path | User creation is gated to the UI login flow; MCP can only resolve existing users |
| Proof-of-Possession tokens (RFC 9449) | Not supported by CF Access |

## Approved posture

1. Validate JWT signature using JWKS from CF Access (RS256 only).
2. Validate `iss == https://susurrant.cloudflareaccess.com`.
3. Validate `aud` includes the application's `CF_ACCESS_AUD` environment variable.
4. Validate `exp` (reject expired tokens).
5. Extract `email` claim; reject if absent.
6. `User.find_by!(email_address: email)` — return 401 if not found (no auto-creation).
7. Log (at warn level) and reject any token that fails any of the above checks.

## Outstanding configuration

- `CF_ACCESS_AUD` must be set in the production environment before the MCP endpoint
  is deployed. Value is visible in the Cloudflare Access dashboard under the
  application's settings, and also appears as the `kid` parameter in the CF Access
  login redirect URL — it is effectively public, but must not be hardcoded in committed
  code. Treat as config, not a secret.

## References

- OpenID Connect Core 1.0 §5.7: https://openid.net/specs/openid-connect-core-1_0.html#UserInfo
- OAuth 2.0 Security BCP (RFC 9700): https://www.rfc-editor.org/rfc/rfc9700
- Cloudflare Access: Validating JWTs: https://developers.cloudflare.com/cloudflare-one/identity/authorization-cookie/validating-json/
- MCP Authorization spec (2025-03-26): https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/authorization/
