# MCP Server

learn-hanzi exposes a read-only [Model Context Protocol](https://modelcontextprotocol.io/) server at `/mcp`, allowing AI assistants (Claude, etc.) to query your learning data.

## Authentication

The `/mcp` endpoint is an OAuth 2.1 resource server: `learn-hanzi` is its own authorization server for MCP clients (Doorkeeper), with self-service client identification via [OAuth Client ID Metadata Documents (CIMD)](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-client-id-metadata-document) rather than a manual registration step. A compliant MCP client discovers everything it needs from `/.well-known/oauth-protected-resource` and `/.well-known/oauth-authorization-server` and drives a normal browser-based authorization-code + PKCE flow — there's nothing to create or paste in ahead of time.

Signing in during that flow uses your existing learn-hanzi account (PocketID), and you'll see a consent screen naming the client before access is granted. Revoke access at any time from **Settings → Connected apps**.

See `docs/threat_assessments/MCP_OAUTH_DOORKEEPER.md` for the design rationale and threat model.

### Legacy: Cloudflare Access service token

A transitional fallback still exists for clients that only support a static bearer credential. This path is being phased out — see the threat assessment for the sunset plan — and requires the `/mcp` endpoint to still sit behind a Cloudflare Access policy that has vetted the caller:

**1. Create a service token**

In the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/):

- Access → Service Tokens → Create Service Token
- Give it a name (e.g. `claude-mcp`)
- Copy the **Client ID** and **Client Secret** — the secret is only shown once
- Treat the Client Secret as a password: do not commit it, share it, or store it in plaintext. If leaked, rotate immediately in the CF dashboard.

**2. Add the token to the learn-hanzi Access policy**

- Access → Applications → learn-hanzi → Edit
- Policies → edit your Allow policy
- Add an include rule: **Service Token** → select your token
- Save

**3. Link the token to your account**

Go to **Settings → API access (MCP)** in the app and paste your **Client ID**. This associates the service token with your user account so the MCP server knows whose data to return.

**4. Configure your client**

The OAuth-based config shown in "Connecting Claude Desktop" below doesn't apply to this path — a legacy client needs the service token's headers instead:

```json
{
  "mcpServers": {
    "learn-hanzi": {
      "type": "http",
      "url": "https://xue.huwdiprose.co.uk/mcp",
      "headers": {
        "CF-Access-Client-Id": "<your-client-id>",
        "CF-Access-Client-Secret": "<your-client-secret>"
      }
    }
  }
}
```

---

## Connecting Claude Desktop

Add the following to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS, `%APPDATA%\Claude\claude_desktop_config.json` on Windows):

```json
{
  "mcpServers": {
    "learn-hanzi": {
      "type": "http",
      "url": "https://xue.huwdiprose.co.uk/mcp"
    }
  }
}
```

Restart Claude Desktop after saving — it will open a browser window to complete sign-in and consent on first connection.

---

## Smoke test

Verify the discovery endpoints are reachable:

```bash
curl -sS https://xue.huwdiprose.co.uk/.well-known/oauth-authorization-server
```

A successful response is a JSON document listing `authorization_endpoint`, `token_endpoint`, and `client_id_metadata_document_supported: true`.

---

## Resources

The server exposes five read-only resources, all scoped to the authenticated user.

### `learn-hanzi://profile`

A summary of your overall learning state.

```json
{
  "summary": {
    "new": 120,
    "learning": 45,
    "mastered": 310,
    "suspended": 5,
    "total": 480
  },
  "hsk_breakdown": [
    {
      "version": "HSK 2.0",
      "levels": [
        { "name": "HSK 1", "mastered": 150, "learning": 0, "new": 0, "suspended": 0 },
        { "name": "HSK 2", "mastered": 98,  "learning": 12, "new": 40, "suspended": 0 }
      ]
    }
  ]
}
```

### `learn-hanzi://vocabulary/mastered`

All mastered words, most recently mastered first.

```json
{
  "vocabulary": [
    { "hanzi": "你好", "pinyin": "nǐ hǎo", "meaning": "hello", "mastered_at": "2026-06-15T10:23:00Z" }
  ]
}
```

### `learn-hanzi://vocabulary/recent`

Words graduated to mastered in the last 30 days, most recently mastered first.

Same shape as `vocabulary/mastered`.

### `learn-hanzi://vocabulary/active`

Words currently in the learning queue, ordered by next due date (soonest first).

```json
{
  "vocabulary": [
    { "hanzi": "学习", "pinyin": "xué xí", "meaning": "to study", "next_due": "2026-07-06T08:00:00Z", "factor": 2500 }
  ]
}
```

`factor` is the SRS ease factor (higher = easier, Anki-style).

### `learn-hanzi://vocabulary/struggling`

In-progress words ranked by difficulty — most lapses first, then lowest ease factor.

```json
{
  "vocabulary": [
    { "hanzi": "难", "pinyin": "nán", "meaning": "difficult", "lapse_count": 7, "factor": 1800 }
  ]
}
```

---

## Protocol notes

- Transport: Streamable HTTP (JSON-RPC 2.0 over `POST /mcp`)
- Protocol version: `2025-03-26`
- Sessions: established via `initialize`, tracked by `Mcp-Session-Id` header (24-hour TTL)
- Capabilities: `resources` (read-only; no subscriptions or list-changed notifications)
