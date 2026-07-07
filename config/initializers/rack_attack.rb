class Rack::Attack
  # Share the throttle counters across Puma workers via solid_cache rather
  # than each worker's own in-memory store.
  Rack::Attack.cache.store = Rails.cache

  class << self
    def throttle_client_ip(req)
      trusted_client_ip_header(req).presence || req.get_header("REMOTE_ADDR").presence || req.ip
    end

    private

    def trusted_client_ip_header(req)
      return unless ENV["TRUSTED_CLIENT_IP_HEADER"] == "CF-Connecting-IP"

      req.get_header("HTTP_CF_CONNECTING_IP")
    end
  end

  # /oauth/authorize also triggers a CIMD metadata fetch for unrecognized
  # client_id URLs (see Oauth::CimdClientResolver), so throttling it bounds
  # outbound fetch volume from a single IP as well as authorization attempts.
  throttle("oauth/authorize", limit: 30, period: 1.minute) do |req|
    Rack::Attack.throttle_client_ip(req) if req.path == "/oauth/authorize"
  end

  throttle("oauth/token", limit: 20, period: 1.minute) do |req|
    Rack::Attack.throttle_client_ip(req) if req.path == "/oauth/token" && req.post?
  end
end
