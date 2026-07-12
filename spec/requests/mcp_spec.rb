require "rails_helper"

RSpec.shared_examples "an authenticated MCP session" do
  it "does not expose internal error detail on auth failure" do
    post "/mcp", headers: { "Authorization" => "Bearer not-a-real-token" }, as: :json
    expect(response.body).not_to include("ActiveRecord")
    expect(response.body).not_to include("exception")
  end

  describe "initialize" do
    let(:init_params) do
      {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2025-03-26",
          capabilities: {},
          clientInfo: { name: "TestClient", version: "1.0" }
        }
      }
    end

    it "returns a JSON-RPC 2.0 envelope with the request id" do
      post "/mcp", params: init_params, headers: auth_headers, as: :json
      body = JSON.parse(response.body)
      expect(body["jsonrpc"]).to eq("2.0")
      expect(body["id"]).to eq(1)
    end

    it "returns the negotiated protocol version" do
      post "/mcp", params: init_params, headers: auth_headers, as: :json
      body = JSON.parse(response.body)
      expect(body["result"]["protocolVersion"]).to eq("2025-03-26")
    end

    it "advertises resource capabilities" do
      post "/mcp", params: init_params, headers: auth_headers, as: :json
      body = JSON.parse(response.body)
      expect(body["result"]["capabilities"]["resources"]).to be_present
    end

    it "advertises tool capabilities" do
      post "/mcp", params: init_params, headers: auth_headers, as: :json
      body = JSON.parse(response.body)
      expect(body["result"]["capabilities"]["tools"]).to be_present
    end

    it "returns server info" do
      post "/mcp", params: init_params, headers: auth_headers, as: :json
      body = JSON.parse(response.body)
      expect(body["result"]["serverInfo"]["name"]).to eq("learn-hanzi")
    end

    it "issues a session ID in the response header" do
      post "/mcp", params: init_params, headers: auth_headers, as: :json
      expect(response.headers["Mcp-Session-Id"]).to be_present
    end
  end

  describe "notifications/initialized" do
    it "returns 200 with a valid session" do
      session_id = establish_mcp_session(auth_headers)
      post "/mcp",
        params: { jsonrpc: "2.0", method: "notifications/initialized" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 with no session ID" do
      post "/mcp",
        params: { jsonrpc: "2.0", method: "notifications/initialized" },
        headers: auth_headers,
        as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 with an unknown session ID" do
      post "/mcp",
        params: { jsonrpc: "2.0", method: "notifications/initialized" },
        headers: auth_headers.merge("Mcp-Session-Id" => "bogus-session-id"),
        as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "resources/list" do
    let(:session_id) { establish_mcp_session(auth_headers) }

    it "returns a JSON-RPC 2.0 envelope" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "resources/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      body = JSON.parse(response.body)
      expect(body["jsonrpc"]).to eq("2.0")
      expect(body["id"]).to eq(2)
    end

    it "returns all five resources" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "resources/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      resources = JSON.parse(response.body).dig("result", "resources")
      expect(resources.length).to eq(5)
    end

    it "includes all expected resource URIs" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "resources/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      uris = JSON.parse(response.body).dig("result", "resources").map { |r| r["uri"] }
      expect(uris).to contain_exactly(
        "learn-hanzi://profile",
        "learn-hanzi://vocabulary/mastered",
        "learn-hanzi://vocabulary/struggling",
        "learn-hanzi://vocabulary/recent",
        "learn-hanzi://vocabulary/active"
      )
    end

    it "includes a name and mimeType for each resource" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "resources/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      resources = JSON.parse(response.body).dig("result", "resources")
      resources.each do |resource|
        expect(resource["name"]).to be_present
        expect(resource["mimeType"]).to eq("application/json")
      end
    end
  end

  describe "tools/list" do
    let(:session_id) { establish_mcp_session(auth_headers) }

    it "returns a JSON-RPC 2.0 envelope" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "tools/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      body = JSON.parse(response.body)
      expect(body["jsonrpc"]).to eq("2.0")
      expect(body["id"]).to eq(2)
    end

    it "returns all five tools" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "tools/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      tools = JSON.parse(response.body).dig("result", "tools")
      expect(tools.length).to eq(5)
    end

    it "includes all expected tool names" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "tools/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      names = JSON.parse(response.body).dig("result", "tools").map { |t| t["name"] }
      expect(names).to contain_exactly(
        "get_learning_profile",
        "list_mastered_vocabulary",
        "list_struggling_vocabulary",
        "list_recent_vocabulary",
        "list_active_vocabulary"
      )
    end

    it "includes a description and inputSchema for each tool" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "tools/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      tools = JSON.parse(response.body).dig("result", "tools")
      tools.each do |tool|
        expect(tool["description"]).to be_present
        expect(tool["inputSchema"]["type"]).to eq("object")
      end
    end

    it "declares limit and offset arguments on the list_* tools" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "tools/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      tool = JSON.parse(response.body).dig("result", "tools").find { |t| t["name"] == "list_mastered_vocabulary" }
      expect(tool["inputSchema"]["properties"].keys).to contain_exactly("limit", "offset")
    end

    it "declares no arguments on get_learning_profile" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 2, method: "tools/list" },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      tool = JSON.parse(response.body).dig("result", "tools").find { |t| t["name"] == "get_learning_profile" }
      expect(tool["inputSchema"]["properties"]).to eq({})
    end
  end

  describe "tools/call" do
    let(:session_id) { establish_mcp_session(auth_headers) }

    def call_tool(name, arguments = {})
      post "/mcp",
        params: { jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: name, arguments: arguments } },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      JSON.parse(response.body)
    end

    it "returns -32602 for an unknown tool name" do
      body = call_tool("does_not_exist")
      expect(body["error"]["code"]).to eq(-32602)
    end

    it "does not error when arguments is not a JSON object" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 3, method: "tools/call",
                  params: { name: "list_mastered_vocabulary", arguments: [ 1, 2, 3 ] } },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("result", "structuredContent", "vocabulary")).to eq([])
    end

    it "returns -32602 when params is not a JSON object" do
      post "/mcp",
        params: { jsonrpc: "2.0", id: 3, method: "tools/call", params: [ 1, 2, 3 ] },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["error"]["code"]).to eq(-32602)
    end

    describe "get_learning_profile" do
      it "returns a JSON-RPC 2.0 envelope with text content and structuredContent" do
        body = call_tool("get_learning_profile")
        expect(body["jsonrpc"]).to eq("2.0")
        expect(body["id"]).to eq(3)
        content = body.dig("result", "content")
        expect(content).to be_an(Array)
        expect(content.first["type"]).to eq("text")
        expect(content.first["text"]).to be_present
      end

      it "returns the same data as the profile resource" do
        create(:user_learning, user: user, state: "mastered")
        body = call_tool("get_learning_profile")
        summary = body.dig("result", "structuredContent", "summary")
        expect(summary["mastered"]).to eq(1)
      end

      it "scopes results to the authenticated user" do
        create(:user_learning, user: create(:user), state: "mastered")
        body = call_tool("get_learning_profile")
        summary = body.dig("result", "structuredContent", "summary")
        expect(summary["total"]).to eq(0)
      end
    end

    describe "list_mastered_vocabulary" do
      it "returns the same data as the mastered vocabulary resource" do
        create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago)
        body = call_tool("list_mastered_vocabulary")
        vocabulary = body.dig("result", "structuredContent", "vocabulary")
        expect(vocabulary.length).to eq(1)
      end

      it "applies a default limit" do
        6.times { create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago) }
        body = call_tool("list_mastered_vocabulary")
        vocabulary = body.dig("result", "structuredContent", "vocabulary")
        expect(vocabulary.length).to be <= 50
      end

      it "honours a supplied limit" do
        3.times { create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago) }
        body = call_tool("list_mastered_vocabulary", limit: 2)
        vocabulary = body.dig("result", "structuredContent", "vocabulary")
        expect(vocabulary.length).to eq(2)
      end

      it "honours a supplied offset" do
        older = create(:user_learning, user: user, state: "mastered", mastered_at: 2.days.ago)
        newer = create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago)
        body = call_tool("list_mastered_vocabulary", limit: 1, offset: 1)
        vocabulary = body.dig("result", "structuredContent", "vocabulary")
        expect(vocabulary.first["hanzi"]).to eq(older.dictionary_entry.text)
      end

      it "falls back to the default limit when limit is not an integer" do
        create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago)
        body = call_tool("list_mastered_vocabulary", limit: "not-a-number")
        expect(body["result"]["structuredContent"]["vocabulary"].length).to eq(1)
      end

      it "clamps an oversized limit to MAX_LIST_LIMIT rather than returning everything unbounded" do
        stub_const("McpController::MAX_LIST_LIMIT", 3)
        5.times { create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago) }
        body = call_tool("list_mastered_vocabulary", limit: 999_999)
        vocabulary = body.dig("result", "structuredContent", "vocabulary")
        expect(vocabulary.length).to eq(3)
      end

      it "clamps a negative offset to zero instead of erroring" do
        create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago)
        body = call_tool("list_mastered_vocabulary", offset: -5)
        expect(body["result"]["structuredContent"]["vocabulary"].length).to eq(1)
      end
    end

    describe "list_recent_vocabulary" do
      it "returns the same data as the recent vocabulary resource" do
        create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago)
        body = call_tool("list_recent_vocabulary")
        vocabulary = body.dig("result", "structuredContent", "vocabulary")
        expect(vocabulary.length).to eq(1)
      end
    end

    describe "list_active_vocabulary" do
      it "returns the same data as the active vocabulary resource" do
        create(:user_learning, user: user, state: "learning", next_due: 1.day.from_now)
        body = call_tool("list_active_vocabulary")
        vocabulary = body.dig("result", "structuredContent", "vocabulary")
        expect(vocabulary.length).to eq(1)
      end
    end

    describe "list_struggling_vocabulary" do
      it "returns the same data as the struggling vocabulary resource" do
        ul = create(:user_learning, user: user, state: "learning")
        create(:review_log, user_learning: ul, ease: 1)
        body = call_tool("list_struggling_vocabulary")
        vocabulary = body.dig("result", "structuredContent", "vocabulary")
        expect(vocabulary.first["lapse_count"]).to eq(1)
      end

      it "honours a supplied limit" do
        3.times { create(:user_learning, user: user, state: "learning") }
        body = call_tool("list_struggling_vocabulary", limit: 1)
        vocabulary = body.dig("result", "structuredContent", "vocabulary")
        expect(vocabulary.length).to eq(1)
      end

      it "does not error on a negative offset (Ruby-side Array#drop would raise)" do
        create(:user_learning, user: user, state: "learning")
        body = call_tool("list_struggling_vocabulary", offset: -5)
        expect(body["result"]["structuredContent"]["vocabulary"].length).to eq(1)
      end

      it "does not error on a non-integer limit (Ruby-side Array#first would raise)" do
        create(:user_learning, user: user, state: "learning")
        body = call_tool("list_struggling_vocabulary", limit: "not-a-number")
        expect(body["result"]["structuredContent"]["vocabulary"].length).to eq(1)
      end
    end
  end

  describe "resources/read" do
    let(:session_id) { establish_mcp_session(auth_headers) }

    def read_resource(uri)
      post "/mcp",
        params: { jsonrpc: "2.0", id: 3, method: "resources/read", params: { uri: uri } },
        headers: auth_headers.merge("Mcp-Session-Id" => session_id),
        as: :json
      JSON.parse(response.body)
    end

    it "returns -32602 for an unknown resource URI" do
      body = read_resource("learn-hanzi://does-not-exist")
      expect(body["error"]["code"]).to eq(-32602)
    end

    describe "learn-hanzi://profile" do
      it "returns a JSON-RPC 2.0 envelope with contents" do
        body = read_resource("learn-hanzi://profile")
        expect(body["jsonrpc"]).to eq("2.0")
        expect(body["id"]).to eq(3)
        contents = body.dig("result", "contents")
        expect(contents).to be_an(Array)
        expect(contents.first["uri"]).to eq("learn-hanzi://profile")
        expect(contents.first["mimeType"]).to eq("application/json")
      end

      it "returns a parseable JSON text payload" do
        body = read_resource("learn-hanzi://profile")
        text = body.dig("result", "contents", 0, "text")
        expect { JSON.parse(text) }.not_to raise_error
      end

      it "includes state counts for the authenticated user only" do
        create(:user_learning, user: user, state: "mastered")
        create(:user_learning, user: user, state: "mastered")
        create(:user_learning, user: user, state: "learning")
        other = create(:user)
        create(:user_learning, user: other, state: "mastered")

        body   = read_resource("learn-hanzi://profile")
        summary = JSON.parse(body.dig("result", "contents", 0, "text"))["summary"]
        expect(summary["mastered"]).to eq(2)
        expect(summary["learning"]).to eq(1)
        expect(summary["total"]).to eq(3)
      end

      it "includes new and suspended counts" do
        create(:user_learning, user: user, state: "new")
        create(:user_learning, user: user, state: "suspended")

        body    = read_resource("learn-hanzi://profile")
        summary = JSON.parse(body.dig("result", "contents", 0, "text"))["summary"]
        expect(summary["new"]).to eq(1)
        expect(summary["suspended"]).to eq(1)
      end

      it "includes an hsk_breakdown key" do
        body    = read_resource("learn-hanzi://profile")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload).to have_key("hsk_breakdown")
      end

      it "returns an empty hsk_breakdown array when no HSK tags exist" do
        body    = read_resource("learn-hanzi://profile")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["hsk_breakdown"]).to eq([])
      end

      context "with an HSK tag hierarchy" do
        let!(:hsk_root)  { create(:tag, name: "HSK", parent: nil) }
        let!(:hsk3)      { create(:tag, name: "HSK 3.0", parent: hsk_root) }
        let!(:hsk1)      { create(:tag, name: "HSK 1", parent: hsk3) }
        let!(:entry)     { create(:dictionary_entry).tap { |e| e.tags << hsk1 } }
        let!(:learning)  { create(:user_learning, user: user, dictionary_entry: entry, state: "mastered") }

        it "includes the version and level names" do
          body    = read_resource("learn-hanzi://profile")
          payload = JSON.parse(body.dig("result", "contents", 0, "text"))
          version = payload["hsk_breakdown"].find { |v| v["version"] == "HSK 3.0" }
          expect(version).to be_present
          level = version["levels"].find { |l| l["name"] == "HSK 1" }
          expect(level).to be_present
        end

        it "reports the correct mastered count per level" do
          body    = read_resource("learn-hanzi://profile")
          payload = JSON.parse(body.dig("result", "contents", 0, "text"))
          level = payload["hsk_breakdown"]
            .find { |v| v["version"] == "HSK 3.0" }["levels"]
            .find { |l| l["name"] == "HSK 1" }
          expect(level["mastered"]).to eq(1)
        end
      end
    end

    describe "learn-hanzi://vocabulary/mastered" do
      it "returns vocabulary as an array" do
        body    = read_resource("learn-hanzi://vocabulary/mastered")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"]).to be_an(Array)
      end

      it "returns only the authenticated user's mastered entries" do
        create(:user_learning, user: user, state: "mastered")
        create(:user_learning, user: user, state: "mastered")
        create(:user_learning, user: create(:user), state: "mastered")

        body    = read_resource("learn-hanzi://vocabulary/mastered")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"].length).to eq(2)
      end

      it "excludes non-mastered entries" do
        create(:user_learning, user: user, state: "learning")
        body    = read_resource("learn-hanzi://vocabulary/mastered")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"]).to be_empty
      end

      it "includes hanzi, pinyin, meaning and mastered_at for each entry" do
        create(:user_learning, user: user, state: "mastered",
               mastered_at: 1.day.ago)
        body    = read_resource("learn-hanzi://vocabulary/mastered")
        entry   = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"].first
        expect(entry).to include("hanzi", "pinyin", "meaning", "mastered_at")
      end

      it "orders entries by mastered_at descending" do
        older = create(:user_learning, user: user, state: "mastered",
                       mastered_at: 2.days.ago)
        newer = create(:user_learning, user: user, state: "mastered",
                       mastered_at: 1.day.ago)
        body     = read_resource("learn-hanzi://vocabulary/mastered")
        entries  = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"]
        returned = entries.map { |e| e["hanzi"] }
        expect(returned).to eq([
          newer.dictionary_entry.text,
          older.dictionary_entry.text
        ])
      end
    end

    describe "learn-hanzi://vocabulary/active" do
      it "returns vocabulary as an array" do
        body    = read_resource("learn-hanzi://vocabulary/active")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"]).to be_an(Array)
      end

      it "only includes learning-state entries for the authenticated user" do
        create(:user_learning, user: user, state: "learning", next_due: 1.day.from_now)
        create(:user_learning, user: user, state: "mastered")
        create(:user_learning, user: create(:user), state: "learning")

        body    = read_resource("learn-hanzi://vocabulary/active")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"].length).to eq(1)
      end

      it "includes hanzi, pinyin, meaning, next_due and factor" do
        create(:user_learning, user: user, state: "learning", next_due: 1.day.from_now)
        body  = read_resource("learn-hanzi://vocabulary/active")
        entry = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"].first
        expect(entry).to include("hanzi", "pinyin", "meaning", "next_due", "factor")
      end

      it "orders by next_due ascending" do
        later  = create(:user_learning, user: user, state: "learning", next_due: 7.days.from_now)
        sooner = create(:user_learning, user: user, state: "learning", next_due: 1.day.from_now)

        body    = read_resource("learn-hanzi://vocabulary/active")
        entries = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"]
        expect(entries.first["hanzi"]).to eq(sooner.dictionary_entry.text)
        expect(entries.last["hanzi"]).to eq(later.dictionary_entry.text)
      end

      it "includes overdue entries (next_due in the past)" do
        create(:user_learning, user: user, state: "learning", next_due: 2.days.ago)
        body    = read_resource("learn-hanzi://vocabulary/active")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"].length).to eq(1)
      end
    end

    describe "learn-hanzi://vocabulary/recent" do
      it "returns vocabulary as an array" do
        body    = read_resource("learn-hanzi://vocabulary/recent")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"]).to be_an(Array)
      end

      it "includes entries mastered within the last 30 days" do
        create(:user_learning, user: user, state: "mastered", mastered_at: 15.days.ago)
        body    = read_resource("learn-hanzi://vocabulary/recent")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"].length).to eq(1)
      end

      it "excludes entries mastered more than 30 days ago" do
        create(:user_learning, user: user, state: "mastered", mastered_at: 31.days.ago)
        body    = read_resource("learn-hanzi://vocabulary/recent")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"]).to be_empty
      end

      it "excludes other users' entries" do
        create(:user_learning, user: create(:user), state: "mastered", mastered_at: 1.day.ago)
        body    = read_resource("learn-hanzi://vocabulary/recent")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"]).to be_empty
      end

      it "includes hanzi, pinyin, meaning and mastered_at" do
        create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago)
        body  = read_resource("learn-hanzi://vocabulary/recent")
        entry = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"].first
        expect(entry).to include("hanzi", "pinyin", "meaning", "mastered_at")
      end

      it "orders by mastered_at descending" do
        older = create(:user_learning, user: user, state: "mastered", mastered_at: 10.days.ago)
        newer = create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago)
        body    = read_resource("learn-hanzi://vocabulary/recent")
        entries = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"]
        expect(entries.first["hanzi"]).to eq(newer.dictionary_entry.text)
        expect(entries.last["hanzi"]).to eq(older.dictionary_entry.text)
      end
    end

    describe "learn-hanzi://vocabulary/struggling" do
      it "returns vocabulary as an array" do
        body    = read_resource("learn-hanzi://vocabulary/struggling")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"]).to be_an(Array)
      end

      it "only includes learning-state entries for the authenticated user" do
        create(:user_learning, user: user, state: "learning")
        create(:user_learning, user: user, state: "mastered")
        create(:user_learning, user: create(:user), state: "learning")

        body    = read_resource("learn-hanzi://vocabulary/struggling")
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"].length).to eq(1)
      end

      it "includes hanzi, pinyin, meaning, lapse_count and factor for each entry" do
        create(:user_learning, user: user, state: "learning")
        body  = read_resource("learn-hanzi://vocabulary/struggling")
        entry = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"].first
        expect(entry).to include("hanzi", "pinyin", "meaning", "lapse_count", "factor")
      end

      it "returns lapse_count 0 for an entry with no lapses" do
        create(:user_learning, user: user, state: "learning")
        body  = read_resource("learn-hanzi://vocabulary/struggling")
        entry = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"].first
        expect(entry["lapse_count"]).to eq(0)
      end

      it "orders by lapse_count descending" do
        low  = create(:user_learning, user: user, state: "learning")
        high = create(:user_learning, user: user, state: "learning")
        create(:review_log, user_learning: high, ease: 1)
        create(:review_log, user_learning: high, ease: 1)
        create(:review_log, user_learning: low,  ease: 1)

        body    = read_resource("learn-hanzi://vocabulary/struggling")
        entries = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"]
        expect(entries.first["lapse_count"]).to eq(2)
        expect(entries.last["lapse_count"]).to eq(1)
      end

      it "uses factor ascending as a tiebreaker" do
        lower_factor = create(:user_learning, user: user, state: "learning", factor: 1800)
        higher_factor = create(:user_learning, user: user, state: "learning", factor: 2500)

        body    = read_resource("learn-hanzi://vocabulary/struggling")
        entries = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"]
        expect(entries.first["hanzi"]).to eq(lower_factor.dictionary_entry.text)
      end

      it "counts only ease=1 logs as lapses, not other ease values" do
        ul = create(:user_learning, user: user, state: "learning")
        create(:review_log, user_learning: ul, ease: 1)
        create(:review_log, user_learning: ul, ease: 3)
        create(:review_log, user_learning: ul, ease: 4)

        body  = read_resource("learn-hanzi://vocabulary/struggling")
        entry = JSON.parse(body.dig("result", "contents", 0, "text"))["vocabulary"].first
        expect(entry["lapse_count"]).to eq(1)
      end
    end

    describe "error handling" do
      it "returns a JSON-RPC parse error (-32700) for invalid JSON" do
        post "/mcp",
          params: "not: valid json{{",
          headers: auth_headers.merge("Content-Type" => "application/json")
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq(-32700)
      end

      it "returns a JSON-RPC invalid request error (-32600) for a JSON array body" do
        post "/mcp",
          params: "[1, 2, 3]",
          headers: auth_headers.merge("Content-Type" => "application/json")
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq(-32600)
      end

      it "returns a JSON-RPC method-not-found error (-32601) for unknown methods" do
        session_id = establish_mcp_session(auth_headers)
        post "/mcp",
          params: { jsonrpc: "2.0", id: 2, method: "unknown/method" },
          headers: auth_headers.merge("Mcp-Session-Id" => session_id),
          as: :json
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq(-32601)
      end
    end
  end
end

RSpec.describe "MCP", type: :request do
  let(:user) { create(:user) }

  before do
    stub_cf_jwks
    stub_const("ENV", ENV.to_h.merge("CF_ACCESS_AUD" => CfAccessHelpers::AUD))
    Rails.cache.clear
  end

  describe "POST /mcp" do
    context "when unauthenticated" do
      it "returns 401 when no auth is presented" do
        post "/mcp", as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with a malformed CF assertion token" do
        post "/mcp", headers: cf_assertion_header("not.a.jwt"), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with a malformed bearer token" do
        post "/mcp", headers: { "Authorization" => "Bearer not-a-real-token" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with an expired CF service token" do
        token = cf_service_token(common_name: "abc123def456.access", exp: 1.hour.ago.to_i)
        post "/mcp", headers: cf_assertion_header(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with the wrong CF issuer" do
        token = cf_service_token(common_name: "abc123def456.access", iss: "https://evil.example.com")
        post "/mcp", headers: cf_assertion_header(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with the wrong CF audience" do
        token = cf_service_token(common_name: "abc123def456.access", aud: "wrong-aud")
        post "/mcp", headers: cf_assertion_header(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when the CF JWKS fetch raises an unexpected error" do
        stub_request(:get, CfAccessHelpers::JWKS_URI).to_raise(Net::OpenTimeout)
        token = cf_service_token(common_name: "abc123def456.access")
        post "/mcp", headers: cf_assertion_header(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated via service token" do
      let(:common_name) { "abc123def456.access" }
      let(:token) { cf_service_token(common_name: common_name) }
      let(:auth_headers) { cf_assertion_header(token) }

      before { user.update!(mcp_service_token_id: "abc123def456") }

      it_behaves_like "an authenticated MCP session"

      it "authenticates and returns an MCP session" do
        post "/mcp",
          headers: auth_headers,
          params: { jsonrpc: "2.0", id: 1, method: "initialize",
                    params: { protocolVersion: "2025-03-26", capabilities: {},
                              clientInfo: { name: "test", version: "1" } } },
          as: :json
        expect(response).to have_http_status(:ok)
        expect(response.headers["Mcp-Session-Id"]).to be_present
      end

      it "returns 401 when no user has a matching mcp_service_token_id" do
        user.update!(mcp_service_token_id: nil)
        post "/mcp", headers: auth_headers, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when the service token is expired" do
        expired = cf_service_token(common_name: common_name, exp: 1.hour.ago.to_i)
        post "/mcp", headers: cf_assertion_header(expired), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when common_name is absent" do
        token_without_common_name = cf_service_token(common_name: nil)
        post "/mcp", headers: cf_assertion_header(token_without_common_name), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when common_name lacks the .access suffix" do
        token_bad_format = cf_service_token(common_name: "abc123def456")
        post "/mcp", headers: cf_assertion_header(token_bad_format), as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated via Doorkeeper bearer token" do
      let(:access_token) { doorkeeper_access_token_for(user) }
      let(:auth_headers) { bearer_header(access_token) }

      it_behaves_like "an authenticated MCP session"

      it "authenticates and returns an MCP session" do
        post "/mcp",
          headers: auth_headers,
          params: { jsonrpc: "2.0", id: 1, method: "initialize",
                    params: { protocolVersion: "2025-03-26", capabilities: {},
                              clientInfo: { name: "test", version: "1" } } },
          as: :json
        expect(response).to have_http_status(:ok)
        expect(response.headers["Mcp-Session-Id"]).to be_present
      end

      it "returns 401 with an expired token" do
        expired = doorkeeper_access_token_for(user, expires_in: -1)
        post "/mcp", headers: bearer_header(expired), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with a revoked token" do
        access_token.revoke
        post "/mcp", headers: auth_headers, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with a token missing the mcp scope" do
        scopeless = doorkeeper_access_token_for(user, scopes: "")
        post "/mcp", headers: bearer_header(scopeless), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "cannot read another user's resources" do
        other_user = create(:user)
        create(:user_learning, user: other_user, state: "mastered")

        session_id = establish_mcp_session(auth_headers)
        post "/mcp",
          params: { jsonrpc: "2.0", id: 3, method: "resources/read",
                    params: { uri: "learn-hanzi://vocabulary/mastered" } },
          headers: auth_headers.merge("Mcp-Session-Id" => session_id),
          as: :json
        body = JSON.parse(response.body)
        payload = JSON.parse(body.dig("result", "contents", 0, "text"))
        expect(payload["vocabulary"]).to be_empty
      end
    end
  end

  def establish_mcp_session(headers)
    post "/mcp",
      params: {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "Test", version: "1.0" } }
      },
      headers: headers,
      as: :json
    response.headers["Mcp-Session-Id"]
  end
end
