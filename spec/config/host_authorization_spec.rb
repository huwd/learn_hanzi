require "rails_helper"

# Regression coverage for security/pentests/2026-07-MCP_OAuth.md F-003: Rails
# only sets a default config.hosts allowlist in development
# (railties/lib/rails/application/configuration.rb checks Rails.env.development?
# specifically), so production previously ran with no Host Authorization
# middleware at all — a spoofed Host/X-Forwarded-Host header was reflected
# straight into the OAuth discovery endpoints' issuer/authorization_endpoint.
#
# This can't be exercised as a full request spec without either destabilizing
# the test environment's own middleware stack (which Capybara-driven system
# specs depend on, hitting the app over 127.0.0.1:<random port> — see the
# pentest doc's "Outstanding / follow-ups") or reloading the app with a
# different Rails.env mid-suite. Instead: a unit test proves the mechanism
# itself does what production.rb configures it to do, and a content check
# guards against config/environments/production.rb silently losing the line
# that wires it up.
RSpec.describe "Host Authorization" do
  describe "the ActionDispatch::HostAuthorization mechanism" do
    let(:inner_app) { ->(_env) { [ 200, {}, [ "ok" ] ] } }
    let(:middleware) { ActionDispatch::HostAuthorization.new(inner_app, [ "good.example.com" ]) }

    def call_with_host(host)
      middleware.call(Rack::MockRequest.env_for("/", "HTTP_HOST" => host))
    end

    it "allows a request with an allowlisted Host header" do
      status, = call_with_host("good.example.com")
      expect(status).to eq(200)
    end

    it "blocks a request with an unlisted Host header" do
      status, = call_with_host("evil.example")
      expect(status).to eq(403)
    end

    it "blocks a request that spoofs X-Forwarded-Host rather than Host" do
      status, = middleware.call(
        Rack::MockRequest.env_for("/", "HTTP_HOST" => "good.example.com", "HTTP_X_FORWARDED_HOST" => "evil.example")
      )
      expect(status).to eq(403)
    end
  end

  describe "config/environments/production.rb" do
    let(:source) { File.read(Rails.root.join("config/environments/production.rb")) }

    it "sets config.hosts from a required APP_HOST env var" do
      expect(source).to match(/config\.hosts\s*<<\s*ENV\.fetch\(["']APP_HOST["']\)/)
    end

    it "excludes the health check endpoint from host authorization" do
      expect(source).to match(/config\.host_authorization\s*=\s*\{\s*exclude:/)
    end
  end
end
