oidc_issuer        = Rails.env.production? ? ENV.fetch("OIDC_ISSUER")        : ENV.fetch("OIDC_ISSUER", "http://localhost:8080")
oidc_client_id     = Rails.env.production? ? ENV.fetch("OIDC_CLIENT_ID")     : ENV.fetch("OIDC_CLIENT_ID", "dev-client-id")
oidc_client_secret = Rails.env.production? ? ENV.fetch("OIDC_CLIENT_SECRET") : ENV.fetch("OIDC_CLIENT_SECRET", "dev-client-secret")
oidc_redirect_uri  = Rails.env.production? ? ENV.fetch("OIDC_REDIRECT_URI")  : ENV.fetch("OIDC_REDIRECT_URI", "http://localhost:3000/auth/oidc/callback")

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect, {
    name: :oidc,
    discovery: true,
    issuer: oidc_issuer,
    scope: %i[openid email profile],
    response_type: :code,
    pkce: true,
    client_options: {
      identifier: oidc_client_id,
      secret: oidc_client_secret,
      redirect_uri: oidc_redirect_uri
    }
  }
end

OmniAuth.config.allowed_request_methods = %i[get post]
