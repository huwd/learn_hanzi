OIDC_PROVIDER_NAME = ENV.fetch("OIDC_PROVIDER_NAME", "oidc").freeze

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect, {
    name: OIDC_PROVIDER_NAME,
    discovery: true,
    issuer: ENV.fetch("OIDC_ISSUER", "http://localhost:8080"),
    scope: %i[openid email profile],
    response_type: :code,
    pkce: true,
    client_options: {
      identifier: ENV.fetch("OIDC_CLIENT_ID", "dev-client-id"),
      secret: ENV.fetch("OIDC_CLIENT_SECRET", "dev-client-secret"),
      redirect_uri: ENV.fetch("OIDC_REDIRECT_URI", "http://localhost:3000/auth/oidc/callback")
    }
  }
end

OmniAuth.config.allowed_request_methods = %i[get post]
