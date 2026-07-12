# Authenticates /mcp requests via a Doorkeeper OAuth bearer token.
module McpAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_mcp_request!
  end

  private

  attr_reader :current_mcp_user

  def authenticate_mcp_request!
    @current_mcp_user = user_from_doorkeeper_token
    render_unauthorized unless @current_mcp_user
  end

  def user_from_doorkeeper_token
    return nil unless doorkeeper_token&.acceptable?(%w[mcp])
    User.find_by(id: doorkeeper_token.resource_owner_id)
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
