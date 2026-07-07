require "rails_helper"

RSpec.describe "OAuth/MCP security controls", type: :request do
  before do
    Rails.cache.clear
    Rack::Attack.cache.store.clear
  end

  after do
    Rack::Attack.cache.store.clear
  end

  describe "PKCE configuration" do
    let(:user) { create(:user) }
    let(:client_id_url) { "https://good.example.com/mcp-client.json" }
    let(:redirect_uri) { "https://good.example.com/callback" }
    let(:metadata) do
      { client_id: client_id_url, client_name: "Test MCP Client", redirect_uris: [ redirect_uri ] }
    end

    before do
      allow(Resolv).to receive(:getaddresses).with("good.example.com").and_return([ "93.184.216.34" ])
      stub_request(:get, client_id_url)
        .to_return(status: 200, body: metadata.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "advertises and enforces S256 as the only PKCE challenge method" do
      get "/.well-known/oauth-authorization-server"
      body = JSON.parse(response.body)

      expect(body["code_challenge_methods_supported"]).to eq([ "S256" ])
      expect(Doorkeeper.config.pkce_code_challenge_methods_supported).to eq([ "S256" ])
    end

    it "rejects authorization requests that try to use plain PKCE" do
      sign_in user

      get "/oauth/authorize", params: {
        client_id: client_id_url,
        redirect_uri: redirect_uri,
        response_type: "code",
        code_challenge: "plain-verifier-plain-verifier-plain-verifier",
        code_challenge_method: "plain"
      }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include("code_challenge_method must be S256")
    end
  end

  describe "MCP bearer token placement" do
    it "does not accept access tokens from query parameters" do
      post "/mcp",
        params: { access_token: "not-a-real-token", jsonrpc: "2.0", id: 1, method: "initialize", params: {} },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "OAuth throttles" do
    let(:authorize_path) do
      "/oauth/authorize?client_id=plain-client&redirect_uri=http%3A%2F%2Flocalhost%3A9999%2Fcb" \
        "&response_type=code&code_challenge=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
        "&code_challenge_method=S256"
    end

    it "throttles /oauth/authorize by remote address and ignores X-Forwarded-For by default" do
      30.times do
        get authorize_path, headers: { "REMOTE_ADDR" => "198.51.100.10" }
        expect(response).to have_http_status(:found)
      end

      get authorize_path, headers: { "REMOTE_ADDR" => "198.51.100.10" }
      expect(response).to have_http_status(:too_many_requests)

      get authorize_path, headers: {
        "REMOTE_ADDR" => "198.51.100.10",
        "X-Forwarded-For" => "203.0.113.123"
      }
      expect(response).to have_http_status(:too_many_requests)
    end

    it "throttles /oauth/token by remote address and ignores X-Forwarded-For by default" do
      token_params = {
        grant_type: "authorization_code",
        code: "bogus",
        redirect_uri: "http://localhost:9999/cb",
        client_id: "bogus"
      }

      20.times do
        post "/oauth/token", params: token_params, headers: { "REMOTE_ADDR" => "198.51.100.20" }
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post "/oauth/token", params: token_params, headers: { "REMOTE_ADDR" => "198.51.100.20" }
      expect(response).to have_http_status(:too_many_requests)

      post "/oauth/token", params: token_params, headers: {
        "REMOTE_ADDR" => "198.51.100.20",
        "X-Forwarded-For" => "203.0.113.124"
      }
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
