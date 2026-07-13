# MCP Server

learn-hanzi exposes a read-only [Model Context Protocol](https://modelcontextprotocol.io/) server at `/mcp`, allowing AI assistants (Claude, etc.) to query your learning data.

The server speaks both `resources/*` and `tools/*`. Clients with a full MCP client (Claude Desktop, Claude Code) can use either; tool-centric surfaces — claude.ai custom connectors, the API's `mcp_servers` parameter, and most other agents — only ever call `tools/list` and `tools/call`, so the five tools below are what makes the server usable there.

## Authentication

The `/mcp` endpoint is an OAuth 2.1 resource server: `learn-hanzi` is its own authorization server for MCP clients (Doorkeeper), with self-service client identification via [OAuth Client ID Metadata Documents (CIMD)](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-client-id-metadata-document) rather than a manual registration step. A compliant MCP client discovers everything it needs from `/.well-known/oauth-protected-resource` and `/.well-known/oauth-authorization-server` and drives a normal browser-based authorization-code + PKCE flow — there's nothing to create or paste in ahead of time.

Signing in during that flow uses your existing learn-hanzi account (PocketID), and you'll see a consent screen naming the client before access is granted. Revoke access at any time from **Settings → Connected apps**.

See `docs/threat_assessments/MCP_OAUTH_DOORKEEPER.md` for the design rationale and threat model.

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

## Connecting hosted custom connectors (claude.ai, ChatGPT)

Unlike Claude Desktop/Code, a hosted connector's OAuth handshake is brokered
server-side by the provider's own cloud infrastructure, not run locally in
your browser — so it's a separate compatibility question from the CIMD flow
above. Both work without any extra setup:

- **claude.ai** (Pro/Max → Customize → Connectors) — confirmed working:
  add `https://xue.huwdiprose.co.uk/mcp` as a custom connector and it
  completes the CIMD flow end-to-end against this server.
- **ChatGPT** (Apps SDK connectors) — not yet tested against this server, but
  OpenAI's own docs describe the same CIMD-first behaviour: when an
  authorization server advertises
  `client_id_metadata_document_supported: true` (as
  `/.well-known/oauth-authorization-server` does here), ChatGPT prioritizes
  CIMD over Dynamic Client Registration automatically.

Neither provider's hosted broker required Dynamic Client Registration (RFC
7591) to be added on our side — see
`docs/threat_assessments/MCP_OAUTH_DOORKEEPER.md` for the full rationale.

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

## Tools

The same five read-only queries are also available as MCP tools — each wraps the resource above unchanged, so the data is identical. A `tools/call` result includes a `structuredContent` object with the same shape as the matching resource's JSON, **and** a `content[].text` string containing a short summary line followed by that same JSON payload. The duplication matters: some hosted connectors only forward `content[].text` to the model and drop `structuredContent` entirely, so the full rows must be present there too, not just the count.

| Tool | Arguments | Backed by |
| --- | --- | --- |
| `get_learning_profile` | none | `learn-hanzi://profile` |
| `list_mastered_vocabulary` | `limit`, `offset` | `learn-hanzi://vocabulary/mastered` |
| `list_struggling_vocabulary` | `limit`, `offset` | `learn-hanzi://vocabulary/struggling` |
| `list_recent_vocabulary` | `limit`, `offset` | `learn-hanzi://vocabulary/recent` |
| `list_active_vocabulary` | `limit`, `offset` | `learn-hanzi://vocabulary/active` |

`limit` and `offset` are both optional integers, for paging through large result sets (e.g. thousands of mastered words). `limit` defaults to 50 if omitted.

---

## Protocol notes

- Transport: Streamable HTTP (JSON-RPC 2.0 over `POST /mcp`)
- Protocol version: `2025-03-26`
- Sessions: established via `initialize`, tracked by `Mcp-Session-Id` header (24-hour TTL)
- Capabilities: `resources` and `tools` (both read-only; no subscriptions or list-changed notifications)
