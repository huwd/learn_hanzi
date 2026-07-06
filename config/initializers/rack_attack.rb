class Rack::Attack
  # Share the throttle counters across Puma workers via solid_cache rather
  # than each worker's own in-memory store.
  Rack::Attack.cache.store = Rails.cache

  # /oauth/authorize also triggers a CIMD metadata fetch for unrecognized
  # client_id URLs (see Oauth::CimdClientResolver), so throttling it bounds
  # outbound fetch volume from a single IP as well as authorization attempts.
  throttle("oauth/authorize", limit: 30, period: 1.minute) do |req|
    req.ip if req.path == "/oauth/authorize"
  end

  throttle("oauth/token", limit: 20, period: 1.minute) do |req|
    req.ip if req.path == "/oauth/token" && req.post?
  end
end
