class McpController < ActionController::API
  include McpAuthentication

  PROTOCOL_VERSION = "2025-03-26"
  SESSION_TTL = 24.hours

  def handle
    body = parse_request_body
    return unless body

    method = body["method"]

    if method == "initialize"
      handle_initialize(body)
    else
      mcp_session = resolve_session(request.headers["Mcp-Session-Id"])
      return render json: { error: "Session not found" }, status: :not_found unless mcp_session

      case method
      when "notifications/initialized"
        head :ok
      when "resources/list"
        handle_resources_list(body)
      when "resources/read"
        handle_resources_read(body)
      when "tools/list"
        handle_tools_list(body)
      when "tools/call"
        handle_tools_call(body)
      else
        render json: jsonrpc_error(body["id"], -32601, "Method not found: #{method}")
      end
    end
  end

  private

  def parse_request_body
    body = JSON.parse(request.raw_post)
    unless body.is_a?(Hash)
      render json: jsonrpc_error(nil, -32600, "Invalid Request"), status: :bad_request
      return nil
    end
    body
  rescue JSON::ParserError
    render json: jsonrpc_error(nil, -32700, "Parse error"), status: :bad_request
    nil
  end

  def handle_initialize(body)
    session_id = SecureRandom.hex(32)
    Rails.cache.write(session_cache_key(session_id), { user_id: current_mcp_user.id }, expires_in: SESSION_TTL)
    response.set_header("Mcp-Session-Id", session_id)
    render json: {
      jsonrpc: "2.0",
      id: body["id"],
      result: {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {
          resources: { subscribe: false, listChanged: false },
          tools: { listChanged: false }
        },
        serverInfo: { name: "learn-hanzi", version: "1.0" }
      }
    }
  end

  def resolve_session(session_id)
    return nil if session_id.blank?
    Rails.cache.read(session_cache_key(session_id))
  end

  def session_cache_key(session_id)
    "mcp_session:#{session_id}"
  end

  RESOURCES = [
    {
      uri: "learn-hanzi://profile",
      name: "Learning Profile",
      description: "Summary of your learning state: counts by status and HSK level breakdown.",
      mimeType: "application/json"
    },
    {
      uri: "learn-hanzi://vocabulary/mastered",
      name: "Mastered Vocabulary",
      description: "Words you have consolidated, most recently mastered first.",
      mimeType: "application/json"
    },
    {
      uri: "learn-hanzi://vocabulary/struggling",
      name: "Struggling Vocabulary",
      description: "In-progress words ranked by lapse count and low ease factor — the words giving you the most trouble.",
      mimeType: "application/json"
    },
    {
      uri: "learn-hanzi://vocabulary/recent",
      name: "Recently Mastered",
      description: "Words graduated to mastered in the last 30 days.",
      mimeType: "application/json"
    },
    {
      uri: "learn-hanzi://vocabulary/active",
      name: "Active Learning Queue",
      description: "Words currently in the learning queue, ordered by next due date.",
      mimeType: "application/json"
    }
  ].freeze

  def handle_resources_list(body)
    render json: {
      jsonrpc: "2.0",
      id: body["id"],
      result: { resources: RESOURCES }
    }
  end

  def handle_resources_read(body)
    uri = body.dig("params", "uri")

    content = case uri
    when "learn-hanzi://profile"
      Mcp::ProfileResource.new(current_mcp_user).call
    when "learn-hanzi://vocabulary/mastered"
      Mcp::MasteredVocabularyResource.new(current_mcp_user).call
    when "learn-hanzi://vocabulary/struggling"
      Mcp::StrugglingVocabularyResource.new(current_mcp_user).call
    when "learn-hanzi://vocabulary/recent"
      Mcp::RecentVocabularyResource.new(current_mcp_user).call
    when "learn-hanzi://vocabulary/active"
      Mcp::ActiveVocabularyResource.new(current_mcp_user).call
    else
      return render json: jsonrpc_error(body["id"], -32602, "Unknown resource: #{uri}")
    end

    render json: {
      jsonrpc: "2.0",
      id: body["id"],
      result: {
        contents: [ { uri: uri, mimeType: "application/json", text: content.to_json } ]
      }
    }
  end

  DEFAULT_LIST_LIMIT = 50
  MAX_LIST_LIMIT = 200

  PAGINATION_SCHEMA = {
    type: "object",
    properties: {
      limit: {
        type: "integer",
        description: "Maximum number of entries to return. Defaults to #{DEFAULT_LIST_LIMIT}, capped at #{MAX_LIST_LIMIT}.",
        minimum: 1
      },
      offset: {
        type: "integer",
        description: "Number of entries to skip, for paging through large result sets.",
        minimum: 0
      }
    },
    additionalProperties: false
  }.freeze

  TOOLS = [
    {
      name: "get_learning_profile",
      description: "Summary of your overall learning state: counts by status and HSK level breakdown.",
      inputSchema: { type: "object", properties: {}, additionalProperties: false }
    },
    {
      name: "list_mastered_vocabulary",
      description: "Words you have consolidated, most recently mastered first.",
      inputSchema: PAGINATION_SCHEMA
    },
    {
      name: "list_struggling_vocabulary",
      description: "In-progress words ranked by lapse count and low ease factor — the words giving you the most trouble.",
      inputSchema: PAGINATION_SCHEMA
    },
    {
      name: "list_recent_vocabulary",
      description: "Words graduated to mastered in the last 30 days.",
      inputSchema: PAGINATION_SCHEMA
    },
    {
      name: "list_active_vocabulary",
      description: "Words currently in the learning queue, ordered by next due date.",
      inputSchema: PAGINATION_SCHEMA
    }
  ].freeze

  def handle_tools_list(body)
    render json: {
      jsonrpc: "2.0",
      id: body["id"],
      result: { tools: TOOLS }
    }
  end

  def handle_tools_call(body)
    name = body.dig("params", "name")
    arguments = body.dig("params", "arguments") || {}

    structured_content = case name
    when "get_learning_profile"
      Mcp::ProfileResource.new(current_mcp_user).call
    when "list_mastered_vocabulary"
      Mcp::MasteredVocabularyResource.new(current_mcp_user, **pagination_args(arguments)).call
    when "list_struggling_vocabulary"
      Mcp::StrugglingVocabularyResource.new(current_mcp_user, **pagination_args(arguments)).call
    when "list_recent_vocabulary"
      Mcp::RecentVocabularyResource.new(current_mcp_user, **pagination_args(arguments)).call
    when "list_active_vocabulary"
      Mcp::ActiveVocabularyResource.new(current_mcp_user, **pagination_args(arguments)).call
    else
      return render json: jsonrpc_error(body["id"], -32602, "Unknown tool: #{name}")
    end

    render json: {
      jsonrpc: "2.0",
      id: body["id"],
      result: {
        content: [ { type: "text", text: tool_summary_text(name, structured_content) } ],
        structuredContent: structured_content,
        isError: false
      }
    }
  end

  def pagination_args(arguments)
    { limit: coerce_limit(arguments["limit"]), offset: coerce_offset(arguments["offset"]) }
  end

  # Tool arguments are client-controlled JSON, so a non-integer or
  # out-of-range value must not reach ActiveRecord's limit/offset or
  # StrugglingVocabularyResource's Array#drop/#first — both raise on
  # invalid input (SQL error or ArgumentError/TypeError) rather than
  # coercing it themselves.
  def coerce_limit(value)
    integer = Integer(value, exception: false)
    return DEFAULT_LIST_LIMIT unless integer
    integer.clamp(1, MAX_LIST_LIMIT)
  end

  def coerce_offset(value)
    integer = Integer(value, exception: false)
    return 0 unless integer
    [ integer, 0 ].max
  end

  def tool_summary_text(name, content)
    return "Learning profile: #{content[:summary]['total']} words tracked." if name == "get_learning_profile"

    "Found #{content['vocabulary'].size} vocabulary entries."
  end

  def jsonrpc_error(id, code, message)
    { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
  end
end
