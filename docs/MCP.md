# MCP Server

learn-hanzi exposes a read-only [Model Context Protocol](https://modelcontextprotocol.io/) server at `/mcp`, allowing AI assistants (Claude, etc.) to query your learning data.

## Authentication

The `/mcp` endpoint sits behind Cloudflare Access. Authentication uses a **Cloudflare Access service token** — a static client ID + secret pair that you create once and embed in your AI client's config.

### One-time setup

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

---

## Connecting Claude Desktop

Add the following to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS, `%APPDATA%\Claude\claude_desktop_config.json` on Windows):

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

Restart Claude Desktop after saving.

---

## Smoke test

Verify the server is reachable and your credentials work:

```bash
curl -sS -i -X POST https://xue.huwdiprose.co.uk/mcp \
  -H "CF-Access-Client-Id: <your-client-id>" \
  -H "CF-Access-Client-Secret: <your-client-secret>" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-03-26",
      "capabilities": {},
      "clientInfo": { "name": "test", "version": "1" }
    }
  }'
```

A successful response returns HTTP 200 with a `Mcp-Session-Id` header and a JSON body describing the server's capabilities.

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
