require "rails_helper"

RSpec.describe "OAuth authorize — CIMD client resolution", type: :request do
  let(:user) { create(:user) }
  let(:client_id_url) { "https://good.example.com/mcp-client.json" }
  let(:redirect_uri) { "https://good.example.com/callback" }
  let(:metadata) do
    { client_id: client_id_url, client_name: "Test MCP Client", redirect_uris: [ redirect_uri ] }
  end
  let(:authorize_params) do
    {
      client_id: client_id_url,
      redirect_uri: redirect_uri,
      response_type: "code",
      code_challenge: "a" * 43,
      code_challenge_method: "S256"
    }
  end

  before do
    Rails.cache.clear
    allow(Resolv).to receive(:getaddresses).with("good.example.com").and_return([ "93.184.216.34" ])
  end

  context "when unauthenticated" do
    it "redirects to sign in" do
      get "/oauth/authorize", params: authorize_params
      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "when authenticated" do
    before { sign_in user }

    context "with a valid CIMD client_id" do
      before do
        stub_request(:get, client_id_url)
          .to_return(status: 200, body: metadata.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "resolves and persists the client, then renders the consent screen" do
        get "/oauth/authorize", params: authorize_params
        expect(response).to have_http_status(:ok)

        application = Doorkeeper::Application.find_by(metadata_url: client_id_url)
        expect(application).to be_present
        expect(application.name).to eq("Test MCP Client")
        expect(application.redirect_uri).to eq(redirect_uri)
        expect(application.confidential?).to be false
      end
    end

    context "when the client_id resolves to a private IP (SSRF attempt)" do
      before do
        allow(Resolv).to receive(:getaddresses).with("evil.example.com").and_return([ "127.0.0.1" ])
      end

      it "does not create an application and does not authorize the request" do
        get "/oauth/authorize", params: authorize_params.merge(
          client_id: "https://evil.example.com/client.json",
          redirect_uri: "https://evil.example.com/callback"
        )

        expect(Doorkeeper::Application.where(metadata_url: "https://evil.example.com/client.json")).not_to exist
        expect(response).not_to redirect_to(%r{\Ahttps://evil\.example\.com})
      end
    end

    context "when the CIMD document is invalid" do
      before do
        stub_request(:get, client_id_url).to_return(status: 200, body: "not json")
      end

      it "does not create an application" do
        get "/oauth/authorize", params: authorize_params
        expect(Doorkeeper::Application.where(metadata_url: client_id_url)).not_to exist
      end
    end

    context "with a non-CIMD (plain) client_id" do
      it "leaves classic client lookup untouched" do
        get "/oauth/authorize", params: authorize_params.merge(client_id: "some-plain-client-id")
        expect(Doorkeeper::Application.count).to eq(0)
      end
    end
  end
end
