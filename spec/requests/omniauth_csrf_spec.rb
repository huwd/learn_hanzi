# These specs exercise the omniauth-rails_csrf_protection Rack middleware at
# the HTTP level, without OmniAuth test mode. OmniAuth test mode bypasses the
# middleware entirely — do not enable it in this file.
require "rails_helper"

RSpec.describe "OmniAuth CSRF protection middleware", type: :request do
  # Enforce that OmniAuth test mode is off for the duration of these specs.
  # Test mode bypasses the CSRF middleware entirely; restoring the prior value
  # avoids leaking state into specs that legitimately enable it.
  around do |example|
    original_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false

    # The test environment disables forgery protection globally so that request
    # specs don't need to supply CSRF tokens. The middleware's TokenVerifier
    # calls verified_request?, which checks
    # ActionController::Base.allow_forgery_protection, so we re-enable it here
    # to exercise the actual CSRF check.
    original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original_allow_forgery_protection
    OmniAuth.config.test_mode = original_test_mode
  end

  # Read the configured OIDC issuer the same way the initializer does, so the
  # discovery document's issuer field matches what OmniAuth validates against.
  let(:oidc_issuer) { ENV.fetch("OIDC_ISSUER", "http://localhost:8080") }

  # SWD (the discovery client used by omniauth-openid-connect) enforces HTTPS
  # when fetching the OpenID configuration document, so the WebMock stub must
  # target the HTTPS URL even when the configured issuer uses HTTP.
  let(:oidc_discovery_url) do
    uri = URI.parse("#{oidc_issuer}/.well-known/openid-configuration")
    uri.scheme = "https"
    uri.to_s
  end

  # Minimal OIDC discovery document. Required when a request passes the CSRF
  # check and reaches the OmniAuth OIDC strategy, which fetches this before
  # building the provider redirect URL.
  let(:oidc_discovery) do
    {
      issuer: oidc_issuer,
      authorization_endpoint: "#{oidc_issuer}/auth",
      token_endpoint: "#{oidc_issuer}/token",
      jwks_uri: "#{oidc_issuer}/.well-known/jwks.json",
      userinfo_endpoint: "#{oidc_issuer}/userinfo",
      response_types_supported: %w[code],
      subject_types_supported: %w[public],
      id_token_signing_alg_values_supported: %w[RS256],
      code_challenge_methods_supported: %w[S256]
    }.to_json
  end

  describe "POST /auth/oidc" do
    context "without a CSRF token" do
      # Depending on OmniAuth/gem versions and configuration, CSRF rejection may
      # surface either as a direct 422 InvalidAuthenticityToken response or as a
      # redirect to the OmniAuth failure endpoint.
      it "is rejected" do
        post "/auth/oidc"

        if response.redirect?
          expect(response).to redirect_to(%r{/auth/failure})
        else
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "with a valid CSRF token" do
      before do
        stub_request(:get, oidc_discovery_url)
          .to_return(status: 200, body: oidc_discovery,
                     headers: { "Content-Type" => "application/json" })
      end

      it "is accepted and redirects toward the OIDC provider" do
        get "/sign_in"
        csrf_token = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1]

        post "/auth/oidc", params: { authenticity_token: csrf_token }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to start_with("#{oidc_issuer}/auth")
      end
    end
  end

  describe "GET /auth/oidc" do
    # OmniAuth is configured with allowed_request_methods: %i[post] in
    # config/initializers/omniauth.rb, so GET never reaches the strategy.
    it "is rejected regardless of CSRF token" do
      get "/auth/oidc"
      expect(response).to have_http_status(:not_found)
      expect(response.location).to be_nil
    end
  end
end
