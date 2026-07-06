require "rails_helper"

RSpec.describe "Well-known OAuth discovery endpoints", type: :request do
  describe "GET /.well-known/oauth-protected-resource" do
    it "returns 200 with the resource metadata" do
      get "/.well-known/oauth-protected-resource"
      expect(response).to have_http_status(:ok)
    end

    it "identifies the MCP endpoint as the resource" do
      get "/.well-known/oauth-protected-resource"
      body = JSON.parse(response.body)
      expect(body["resource"]).to eq(mcp_url(host: "www.example.com"))
    end

    it "advertises this app as the authorization server" do
      get "/.well-known/oauth-protected-resource"
      body = JSON.parse(response.body)
      expect(body["authorization_servers"]).to eq([ root_url(host: "www.example.com").chomp("/") ])
    end

    it "advertises the mcp scope and header bearer method" do
      get "/.well-known/oauth-protected-resource"
      body = JSON.parse(response.body)
      expect(body["scopes_supported"]).to eq([ "mcp" ])
      expect(body["bearer_methods_supported"]).to eq([ "header" ])
    end
  end

  describe "GET /.well-known/oauth-authorization-server" do
    it "returns 200 with the authorization server metadata" do
      get "/.well-known/oauth-authorization-server"
      expect(response).to have_http_status(:ok)
    end

    it "advertises the authorization, token, and revocation endpoints" do
      get "/.well-known/oauth-authorization-server"
      body = JSON.parse(response.body)
      expect(body["authorization_endpoint"]).to eq(oauth_authorization_url(host: "www.example.com"))
      expect(body["token_endpoint"]).to eq(oauth_token_url(host: "www.example.com"))
      expect(body["revocation_endpoint"]).to eq(oauth_revoke_url(host: "www.example.com"))
    end

    it "advertises authorization_code and refresh_token as the supported grant types" do
      get "/.well-known/oauth-authorization-server"
      body = JSON.parse(response.body)
      expect(body["grant_types_supported"]).to eq([ "authorization_code", "refresh_token" ])
    end

    it "advertises S256 PKCE support" do
      get "/.well-known/oauth-authorization-server"
      body = JSON.parse(response.body)
      expect(body["code_challenge_methods_supported"]).to eq([ "S256" ])
    end

    it "advertises CIMD support and no client_secret auth methods" do
      get "/.well-known/oauth-authorization-server"
      body = JSON.parse(response.body)
      expect(body["client_id_metadata_document_supported"]).to be true
      expect(body["token_endpoint_auth_methods_supported"]).to eq([ "none" ])
    end

    it "does not advertise a registration_endpoint" do
      get "/.well-known/oauth-authorization-server"
      body = JSON.parse(response.body)
      expect(body).not_to have_key("registration_endpoint")
    end
  end
end
