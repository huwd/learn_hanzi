require "net/http"
require "uri"

# JWT-mechanics for the transitional Cloudflare Access service-token fallback
# on /mcp. Deliberately has no before_action of its own — McpAuthentication
# calls these methods explicitly as one of two auth strategies it tries.
module CfAccessAuthentication
  extend ActiveSupport::Concern

  ISSUER   = "https://susurrant.cloudflareaccess.com"
  JWKS_URI = "#{ISSUER}/cdn-cgi/access/certs"

  private

  def resolve_user_via_cf_service_token(payload)
    return nil unless payload["type"] == "app"

    common_name = payload["common_name"]
    return nil unless common_name&.end_with?(".access")
    token_id = common_name.delete_suffix(".access")
    return nil if token_id.blank?
    User.find_by(mcp_service_token_id: token_id)
  end

  def extract_cf_assertion_token
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
end
