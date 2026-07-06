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

## Known upstream issue (as of writing)

The `oidc-server` plugin (part of [Imposter](https://www.imposter.sh)) has a
bug: its discovery document and issued ID tokens declare an `issuer` that
omits the configured `path_prefix`, while every other endpoint URL in the
same document correctly includes it. Since `path_prefix` defaults to
`/oidc` (there's no way to configure a genuinely empty one), the declared
issuer never matches where the document is actually served — a violation of
RFC 8414 §3.3 / OIDC Discovery §4.3 that strict relying parties (including
the `openid_connect` gem this app uses) reject outright with
`InvalidIssuer: Invalid ID token: Issuer does not match`.

A fix has been prepared and verified against this app's real login flow, but
is not yet submitted/merged upstream. Until it ships in a published
`oidc-server` plugin release:

- **CI** (`real_oidc_test` job in `.github/workflows/ci.yml`) uses the
  standard, publicly published plugin, and is **expected to fail**. It's
  deliberately not a required check (not in `publish`'s `needs:`), so this
  known, external failure doesn't block deploys. Once the fix is released
  upstream, this job should start passing with no changes needed here.
- **Local verification** against the fix uses a self-built plugin binary
  from a fork, not the CLI-installed release — see whoever is tracking the
  upstream PR for details; this isn't wired into any repo tooling since it's
  a temporary state.

## Running locally

One-time setup:

```bash
curl -fsSL https://raw.githubusercontent.com/imposter-project/imposter-cli/main/install/install_imposter.sh | bash -
imposter plugin install -d oidc-server -t native
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

Until the upstream fix ships, this will fail against the standard published
plugin — see "Known upstream issue" above.

`bundle exec rspec` with no arguments (the normal way to run this suite)
never touches this tier at all — `spec/rails_helper.rb` excludes anything
tagged `real_oidc: true` unless `REAL_OIDC` is set.
