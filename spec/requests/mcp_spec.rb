require "rails_helper"

RSpec.describe "MCP", type: :request do
  let(:user) { create(:user) }

  before do
    stub_cf_jwks
    stub_const("ENV", ENV.to_h.merge("CF_ACCESS_AUD" => CfAccessHelpers::AUD))
    Rails.cache.clear
  end

  describe "POST /mcp" do
    context "when unauthenticated" do
      it "returns 401 with no Authorization header" do
        post "/mcp", as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with a non-Bearer Authorization scheme" do
        post "/mcp", headers: { "Authorization" => "Basic dXNlcjpwYXNz" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with a malformed token" do
        post "/mcp", headers: bearer("not.a.jwt"), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with an expired token" do
        token = cf_access_token(email: user.email_address, exp: 1.hour.ago.to_i)
        post "/mcp", headers: bearer(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with the wrong issuer" do
        token = cf_access_token(email: user.email_address, iss: "https://evil.example.com")
        post "/mcp", headers: bearer(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 with the wrong audience" do
        token = cf_access_token(email: user.email_address, aud: "wrong-aud")
        post "/mcp", headers: bearer(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when the email claim is absent" do
        token = cf_access_token(email: user.email_address, omit_email: true)
        post "/mcp", headers: bearer(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when the email does not match any user" do
        token = cf_access_token(email: "nobody@example.com")
        post "/mcp", headers: bearer(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated" do
      let(:token) { cf_access_token(email: user.email_address) }

      it "returns a successful response with a valid token" do
        post "/mcp", headers: bearer(token), as: :json
        expect(response).to have_http_status(:success)
      end

      it "does not expose internal error detail on auth failure" do
        bad_token = cf_access_token(email: "nobody@example.com")
        post "/mcp", headers: bearer(bad_token), as: :json
        expect(response.body).not_to include("ActiveRecord")
        expect(response.body).not_to include("exception")
      end
    end
  end
end
