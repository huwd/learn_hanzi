# During asset precompilation (Docker build) Rails boots without OIDC env vars.
# OmniAuth middleware is not needed at that stage so we skip it entirely.
return if ENV["SECRET_KEY_BASE_DUMMY"]

oidc_issuer        = Rails.env.local? ? ENV.fetch("OIDC_ISSUER", "http://localhost:8080")                      : ENV.fetch("OIDC_ISSUER")
oidc_client_id     = Rails.env.local? ? ENV.fetch("OIDC_CLIENT_ID", "dev-client-id")                          : ENV.fetch("OIDC_CLIENT_ID")
oidc_client_secret = Rails.env.local? ? ENV.fetch("OIDC_CLIENT_SECRET", "dev-client-secret")                  : ENV.fetch("OIDC_CLIENT_SECRET")
oidc_redirect_uri  = Rails.env.local? ? ENV.fetch("OIDC_REDIRECT_URI", "http://localhost:3000/auth/oidc/callback") : ENV.fetch("OIDC_REDIRECT_URI")

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
