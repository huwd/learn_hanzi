require "rails_helper"

RSpec.describe "OAuth authorization code + PKCE flow, end to end", type: :request do
  let(:user) { create(:user) }
  let(:client_id_url) { "https://good.example.com/mcp-client.json" }
  let(:redirect_uri) { "https://good.example.com/callback" }
  let(:code_verifier) { "a" * 43 }
  let(:code_challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false) }
  let(:metadata) do
    { client_id: client_id_url, client_name: "Test MCP Client", redirect_uris: [ redirect_uri ] }
  end

  before do
    Rails.cache.clear
    allow(Resolv).to receive(:getaddresses).with("good.example.com").and_return([ "93.184.216.34" ])
    stub_request(:get, client_id_url)
      .to_return(status: 200, body: metadata.to_json, headers: { "Content-Type" => "application/json" })
    sign_in user
  end

  it "completes authorize -> consent -> token -> /mcp for a CIMD client" do
    # 1. The client's browser lands on the authorize endpoint; the CIMD
    #    document is resolved and the consent screen renders.
    get "/oauth/authorize", params: {
      client_id: client_id_url,
      redirect_uri: redirect_uri,
      response_type: "code",
      code_challenge: code_challenge,
      code_challenge_method: "S256"
    }
    expect(response).to have_http_status(:ok)

    # 2. The user clicks "Authorize" — this is the form the consent view
    #    actually submits, carrying the same params back as hidden fields.
    post "/oauth/authorize", params: {
      client_id: client_id_url,
      redirect_uri: redirect_uri,
      response_type: "code",
      code_challenge: code_challenge,
      code_challenge_method: "S256"
    }
    expect(response).to have_http_status(:found)
    expect(response.location).to start_with(redirect_uri)

    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    expect(code).to be_present

    # 3. The client exchanges the code for a token, proving the verifier
    #    presented here actually has to match the challenge sent in step 1.
    post "/oauth/token", params: {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: client_id_url,
      code_verifier: code_verifier
    }
    expect(response).to have_http_status(:ok)
    token_body = JSON.parse(response.body)
    access_token = token_body["access_token"]
    expect(access_token).to be_present
    expect(token_body["refresh_token"]).to be_present

    # 4. The resulting bearer token actually authenticates against /mcp,
    #    scoped to the user who completed the consent screen.
    post "/mcp",
      headers: { "Authorization" => "Bearer #{access_token}" },
      params: { jsonrpc: "2.0", id: 1, method: "initialize",
                params: { protocolVersion: "2025-03-26", capabilities: {},
                          clientInfo: { name: "test", version: "1" } } },
      as: :json
    expect(response).to have_http_status(:ok)
  end

  it "rejects the token exchange when the code_verifier does not match the challenge" do
    get "/oauth/authorize", params: {
      client_id: client_id_url, redirect_uri: redirect_uri, response_type: "code",
      code_challenge: code_challenge, code_challenge_method: "S256"
    }
    post "/oauth/authorize", params: {
      client_id: client_id_url, redirect_uri: redirect_uri, response_type: "code",
      code_challenge: code_challenge, code_challenge_method: "S256"
    }
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]

    post "/oauth/token", params: {
      grant_type: "authorization_code", code: code, redirect_uri: redirect_uri,
      client_id: client_id_url, code_verifier: "wrong-verifier-wrong-verifier-wrong-verifier"
    }
    expect(response).to have_http_status(:bad_request)
  end

  it "rejects the token exchange when no code_verifier is presented at all" do
    get "/oauth/authorize", params: {
      client_id: client_id_url, redirect_uri: redirect_uri, response_type: "code",
      code_challenge: code_challenge, code_challenge_method: "S256"
    }
    post "/oauth/authorize", params: {
      client_id: client_id_url, redirect_uri: redirect_uri, response_type: "code",
      code_challenge: code_challenge, code_challenge_method: "S256"
    }
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]

    post "/oauth/token", params: {
      grant_type: "authorization_code", code: code, redirect_uri: redirect_uri, client_id: client_id_url
    }
    expect(response).to have_http_status(:bad_request)
  end
end
