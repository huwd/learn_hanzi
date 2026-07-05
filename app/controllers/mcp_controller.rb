class McpController < ApplicationController
  include CfAccessAuthentication

  skip_before_action :verify_authenticity_token
  skip_before_action :require_authentication

  def handle
    render json: { status: "ok" }
  end
end
