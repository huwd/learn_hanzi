OIDC_PROVIDER_NAME = ENV.fetch("OIDC_PROVIDER_NAME", "oidc").freeze

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect, {
    name: OIDC_PROVIDER_NAME,
    discovery: true,
    issuer: ENV.fetch("OIDC_ISSUER", "http://localhost:8080"),
    client_id: ENV.fetch("OIDC_CLIENT_ID", "dev-client-id"),
    client_secret: ENV.fetch("OIDC_CLIENT_SECRET", "dev-client-secret"),
    scope: %i[openid email profile],
    response_type: :code,
    pkce: true,
    redirect_uri: ENV["OIDC_REDIRECT_URI"]
  }
end

OmniAuth.config.allowed_request_methods = %i[get post]
