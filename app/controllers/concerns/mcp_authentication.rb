# Dispatches /mcp authentication across two strategies: a Doorkeeper OAuth
# bearer token (the long-term path) or a Cloudflare Access service token (a
# transitional fallback while existing clients migrate — see
# CfAccessAuthentication). Trying Doorkeeper first means well-formed bearer
# tokens never touch the CF JWT/JWKS code path at all.
module McpAuthentication
  extend ActiveSupport::Concern
  include CfAccessAuthentication

  included do
    before_action :authenticate_mcp_request!
  end

  private

  attr_reader :current_mcp_user

  def authenticate_mcp_request!
    @current_mcp_user = user_from_doorkeeper_token || user_from_cf_service_token
    render_unauthorized unless @current_mcp_user
  end

  def user_from_doorkeeper_token
    return nil unless doorkeeper_token&.acceptable?(%w[mcp])
    User.find_by(id: doorkeeper_token.resource_owner_id)
  end

  def user_from_cf_service_token
    token = extract_cf_assertion_token
    return nil unless token

    payload = decode_cf_token(token)
    return nil unless payload

    resolve_user_via_cf_service_token(payload)
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
