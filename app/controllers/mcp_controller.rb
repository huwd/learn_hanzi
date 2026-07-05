class McpController < ApplicationController
  include CfAccessAuthentication

  PROTOCOL_VERSION = "2025-03-26"
  SESSION_TTL = 24.hours

  skip_before_action :verify_authenticity_token
  skip_before_action :require_authentication

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
      else
        render json: jsonrpc_error(body["id"], -32601, "Method not found: #{method}")
      end
    end
  end

  private

  def parse_request_body
    JSON.parse(request.raw_post)
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
        capabilities: { resources: { subscribe: false, listChanged: false } },
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

  def jsonrpc_error(id, code, message)
    { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
  end
end
