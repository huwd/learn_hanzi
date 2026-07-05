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

      it "does not expose internal error detail on auth failure" do
        bad_token = cf_access_token(email: "nobody@example.com")
        post "/mcp", headers: bearer(bad_token), as: :json
        expect(response.body).not_to include("ActiveRecord")
        expect(response.body).not_to include("exception")
      end

      describe "initialize" do
        let(:init_params) do
          {
            jsonrpc: "2.0",
            id: 1,
            method: "initialize",
            params: {
              protocolVersion: "2025-03-26",
              capabilities: {},
              clientInfo: { name: "TestClient", version: "1.0" }
            }
          }
        end

        it "returns a JSON-RPC 2.0 envelope with the request id" do
          post "/mcp", params: init_params, headers: bearer(token), as: :json
          body = JSON.parse(response.body)
          expect(body["jsonrpc"]).to eq("2.0")
          expect(body["id"]).to eq(1)
        end

        it "returns the negotiated protocol version" do
          post "/mcp", params: init_params, headers: bearer(token), as: :json
          body = JSON.parse(response.body)
          expect(body["result"]["protocolVersion"]).to eq("2025-03-26")
        end

        it "advertises resource capabilities" do
          post "/mcp", params: init_params, headers: bearer(token), as: :json
          body = JSON.parse(response.body)
          expect(body["result"]["capabilities"]["resources"]).to be_present
        end

        it "returns server info" do
          post "/mcp", params: init_params, headers: bearer(token), as: :json
          body = JSON.parse(response.body)
          expect(body["result"]["serverInfo"]["name"]).to eq("learn-hanzi")
        end

        it "issues a session ID in the response header" do
          post "/mcp", params: init_params, headers: bearer(token), as: :json
          expect(response.headers["Mcp-Session-Id"]).to be_present
        end
      end

      describe "notifications/initialized" do
        it "returns 200 with a valid session" do
          session_id = establish_mcp_session(token)
          post "/mcp",
            params: { jsonrpc: "2.0", method: "notifications/initialized" },
            headers: bearer(token).merge("Mcp-Session-Id" => session_id),
            as: :json
          expect(response).to have_http_status(:ok)
        end

        it "returns 404 with no session ID" do
          post "/mcp",
            params: { jsonrpc: "2.0", method: "notifications/initialized" },
            headers: bearer(token),
            as: :json
          expect(response).to have_http_status(:not_found)
        end

        it "returns 404 with an unknown session ID" do
          post "/mcp",
            params: { jsonrpc: "2.0", method: "notifications/initialized" },
            headers: bearer(token).merge("Mcp-Session-Id" => "bogus-session-id"),
            as: :json
          expect(response).to have_http_status(:not_found)
        end
      end

      describe "error handling" do
        it "returns a JSON-RPC parse error (-32700) for invalid JSON" do
          post "/mcp",
            params: "not: valid json{{",
            headers: bearer(token).merge("Content-Type" => "application/json")
          body = JSON.parse(response.body)
          expect(body["error"]["code"]).to eq(-32700)
        end

        it "returns a JSON-RPC method-not-found error (-32601) for unknown methods" do
          session_id = establish_mcp_session(token)
          post "/mcp",
            params: { jsonrpc: "2.0", id: 2, method: "unknown/method" },
            headers: bearer(token).merge("Mcp-Session-Id" => session_id),
            as: :json
          body = JSON.parse(response.body)
          expect(body["error"]["code"]).to eq(-32601)
        end
      end
    end
  end

  def establish_mcp_session(token)
    post "/mcp",
      params: {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "Test", version: "1.0" } }
      },
      headers: bearer(token),
      as: :json
    response.headers["Mcp-Session-Id"]
  end
end
