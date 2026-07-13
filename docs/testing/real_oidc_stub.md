# Real OIDC test stub

Every login in this test suite — request specs, system specs, everything
else — authenticates via OmniAuth's `test_mode`/`mock_auth`
(`spec/support/authentication_helpers.rb`), which substitutes a canned auth
hash directly at the strategy level. That's fast and hermetic, but it means
none of those specs ever exercise the real `omniauth_openid_connect`
integration: discovery document parsing, JWKS validation, redirect_uri
handling, or the actual authorization-code + PKCE exchange
(`config/initializers/omniauth.rb` sets `pkce: true` on the login flow).

This tier exists to close that gap: a small number of specs drive the real
OIDC handshake against a stub server that speaks the actual protocol over
HTTP (real discovery document, real JWKS, real redirect), but is
pre-configured with one canned test identity so there's no interactive
login UI/passkey step involved, unlike real PocketID.

## What this tier proves, and what it doesn't

**Proves:** the app's own OIDC integration code actually works end-to-end —
discovery lookup, redirect to the authorization endpoint, the callback
handler, ID token verification, and `User.find_or_create_by_omniauth`
correctly creating/reusing a user from a real (stub) token response.

**Doesn't prove:** anything about real PocketID specifically. The stub is not
a PocketID clone and isn't meant to be — it's a generic, spec-compliant OIDC
provider. If you need to manually verify against real PocketID, that's a
separate, interactive workflow (see the Playwright MCP section of this
repo's `CLAUDE.md`).

**Canned identity, not a general test helper:** unlike `sign_in`/
`sign_in_via_browser`, which can authenticate as any FactoryBot `User` on the
fly, this tier only ever authenticates as the one user baked into
`spec/support/imposter/config/imposter-config.yaml`
(`test-user` / `oidc-stub@learn-hanzi.test`). Use `sign_in`/
`sign_in_via_browser` for ordinary feature specs; reach for this tier only
when you specifically need to prove something about the OIDC wiring itself.

## Upstream issuer bug (fixed in v5.19.2)

The `oidc-server` plugin (part of [Imposter](https://www.imposter.sh)) had a
bug: its discovery document and issued ID tokens declared an `issuer` that
omitted the configured `path_prefix`, while every other endpoint URL in the
same document correctly included it. Since `path_prefix` defaults to
`/oidc` (there's no way to configure a genuinely empty one), the declared
issuer never matched where the document was actually served — a violation of
RFC 8414 §3.3 / OIDC Discovery §4.3 that strict relying parties (including
the `openid_connect` gem this app uses) reject outright with
`InvalidIssuer: Invalid ID token: Issuer does not match`.

The fix ([`imposter-project/imposter-go@3ffc939`](https://github.com/imposter-project/imposter-go/commit/3ffc939e8ddcd5eaa7640c46c379576a5baa7b3a))
shipped upstream in
[`imposter-go` v5.19.2](https://github.com/imposter-project/imposter-go/releases/tag/v5.19.2).
`bin/oidc_stub_setup` and `bin/oidc_stub` pin `IMPOSTER_ENGINE_VERSION` to
`5.19.3` (the latest release at time of writing, which includes the fix), so
both CI and local runs now use the corrected engine and no longer need to
relax `OpenIDConnect.validate_discovery_issuer` (see `spec/rails_helper.rb`).

## Running locally

One-time setup — `bin/oidc_stub_setup` (the same script `.github/workflows/ci.yml`
runs) downloads a pinned-version Imposter CLI release tarball, verifies it
against that release's published `checksums.txt` before extracting anything,
installs it to `/usr/local/bin`, then installs the `oidc-server` plugin
pinned to a specific Imposter engine version — not `curl | bash` from `main`,
and not "whatever `latest` resolves to today", so this stays auditable and
reproducible on both a laptop and a CI runner (Linux and macOS, amd64 and
arm64):

```bash
bin/oidc_stub_setup
```

Start the stub (leave running in its own terminal):

```bash
bin/oidc_stub
```

Run the tier (in another terminal):

```bash
REAL_OIDC=1 \
  OIDC_ISSUER="http://localhost:8080/oidc" \
  OIDC_CLIENT_ID="dev-client-id" \
  OIDC_CLIENT_SECRET="dev-client-secret" \
  OIDC_REDIRECT_URI="http://localhost:31337/auth/oidc/callback" \
  bundle exec rspec --tag real_oidc
```

`bundle exec rspec` with no arguments (the normal way to run this suite)
never touches this tier at all — `spec/rails_helper.rb` excludes anything
tagged `real_oidc: true` unless `REAL_OIDC` is set.
