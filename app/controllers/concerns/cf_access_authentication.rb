require "net/http"
require "uri"

module CfAccessAuthentication
  extend ActiveSupport::Concern

  ISSUER   = "https://susurrant.cloudflareaccess.com"
  JWKS_URI = "#{ISSUER}/cdn-cgi/access/certs"

  included do
    before_action :cf_access_authenticate!
  end

  private

  attr_reader :current_mcp_user

  def cf_access_authenticate!
    token = extract_bearer_token
    return render_unauthorized unless token

    payload = decode_cf_token(token)
    return render_unauthorized unless payload

    email = payload["email"].presence
    return render_unauthorized unless email

    user = User.find_by(email_address: email)
    return render_unauthorized unless user

    @current_mcp_user = user
  end

  def extract_bearer_token
    request.headers["CF-Access-Jwt-Assertion"].presence
  end

  def decode_cf_token(token)
    aud = ENV.fetch("CF_ACCESS_AUD")
    JWT.decode(token, nil, true,
      algorithms: [ "RS256" ],
      jwks: fetch_jwks,
      iss: ISSUER,
      verify_iss: true,
      aud: aud,
      verify_aud: true
    ).first
  rescue JWT::DecodeError => e
    Rails.logger.warn("CF Access JWT rejected: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.error("CF Access JWT validation error: #{e.class}: #{e.message}")
    nil
  end

  def fetch_jwks
    Rails.cache.fetch("cf_access_jwks", expires_in: 1.hour) do
      uri = URI(JWKS_URI)
      response = Net::HTTP.get_response(uri)
      raise "JWKS fetch failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
