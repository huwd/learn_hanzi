require "rails_helper"

RSpec.describe Oauth::CimdClientResolver do
  let(:client_id_url) { "https://good.example.com/mcp-client.json" }
  let(:valid_metadata) do
    {
      client_id: client_id_url,
      client_name: "Test MCP Client",
      redirect_uris: [ "https://good.example.com/callback" ]
    }
  end

  before do
    Rails.cache.clear
    # SsrfFilter resolves hostnames via Resolv before ever touching webmock's
    # stubbed HTTP layer, so DNS is stubbed here rather than hitting the network.
    allow(Resolv).to receive(:getaddresses).with("good.example.com").and_return([ "93.184.216.34" ])
  end

  describe "#resolve!" do
    it "rejects a client_id that is not https" do
      resolver = described_class.new("http://good.example.com/mcp-client.json")
      expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /https/)
    end

    it "rejects a client_id with no path" do
      resolver = described_class.new("https://good.example.com")
      expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /path/)
    end

    it "rejects a client_id with a fragment" do
      resolver = described_class.new("https://good.example.com/client.json#frag")
      expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /fragment/)
    end

    it "rejects a client_id with userinfo" do
      resolver = described_class.new("https://user:pass@good.example.com/client.json")
      expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /userinfo/)
    end

    it "rejects a client_id with an explicit default port" do
      resolver = described_class.new("https://good.example.com:443/client.json")
      expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /port/)
    end

    context "when the hostname resolves to a private/loopback address" do
      before do
        allow(Resolv).to receive(:getaddresses).with("evil.example.com").and_return([ "127.0.0.1" ])
      end

      it "blocks the fetch" do
        resolver = described_class.new("https://evil.example.com/client.json")
        expect { resolver.resolve! }.to raise_error(described_class::FetchError, /blocked/)
      end
    end

    context "with a successful fetch" do
      before do
        stub_request(:get, client_id_url)
          .to_return(status: 200, body: valid_metadata.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "creates a public Doorkeeper::Application keyed by the metadata URL" do
        resolver = described_class.new(client_id_url)
        application = resolver.resolve!

        expect(application).to be_a(Doorkeeper::Application)
        expect(application.uid).to eq(client_id_url)
        expect(application.metadata_url).to eq(client_id_url)
        expect(application.confidential?).to be false
        expect(application.name).to eq("Test MCP Client")
        expect(application.redirect_uri).to eq("https://good.example.com/callback")
      end

      it "caches the fetched document and does not refetch within the TTL" do
        described_class.new(client_id_url).resolve!
        described_class.new(client_id_url).resolve!

        expect(WebMock).to have_requested(:get, client_id_url).once
      end

      it "re-syncs an existing application's fields rather than creating a duplicate" do
        first = described_class.new(client_id_url).resolve!

        Rails.cache.clear
        stub_request(:get, client_id_url)
          .to_return(status: 200, body: valid_metadata.merge(client_name: "Renamed Client").to_json,
                     headers: { "Content-Type" => "application/json" })

        second = described_class.new(client_id_url).resolve!

        expect(second.id).to eq(first.id)
        expect(second.name).to eq("Renamed Client")
        expect(Doorkeeper::Application.where(metadata_url: client_id_url).count).to eq(1)
      end
    end

    context "when the fetch times out" do
      before do
        stub_request(:get, client_id_url).to_timeout
      end

      it "raises a FetchError" do
        resolver = described_class.new(client_id_url)
        expect { resolver.resolve! }.to raise_error(described_class::FetchError)
      end

      it "does not cache the failure" do
        resolver = described_class.new(client_id_url)
        expect { resolver.resolve! }.to raise_error(described_class::FetchError)
        expect(Rails.cache.exist?("cimd_client_metadata:#{client_id_url}")).to be false
      end
    end

    context "when the response exceeds the size cap" do
      before do
        oversized_body = { client_id: client_id_url, redirect_uris: [ "https://good.example.com/callback" ],
                            padding: "x" * described_class::MAX_BODY_BYTES }.to_json
        stub_request(:get, client_id_url)
          .to_return(status: 200, body: oversized_body, headers: { "Content-Type" => "application/json" })
      end

      it "raises a FetchError" do
        resolver = described_class.new(client_id_url)
        expect { resolver.resolve! }.to raise_error(described_class::FetchError, /exceeded/)
      end
    end

    context "when the response is not valid JSON" do
      before do
        stub_request(:get, client_id_url).to_return(status: 200, body: "not json")
      end

      it "raises an InvalidMetadata error" do
        resolver = described_class.new(client_id_url)
        expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /JSON/)
      end
    end

    context "when the document's client_id does not match the fetched URL" do
      before do
        stub_request(:get, client_id_url)
          .to_return(status: 200, body: valid_metadata.merge(client_id: "https://different.example.com/x.json").to_json)
      end

      it "raises an InvalidMetadata error" do
        resolver = described_class.new(client_id_url)
        expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /does not match/)
      end
    end

    context "when redirect_uris is missing" do
      before do
        stub_request(:get, client_id_url)
          .to_return(status: 200, body: valid_metadata.except(:redirect_uris).to_json)
      end

      it "raises an InvalidMetadata error" do
        resolver = described_class.new(client_id_url)
        expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /redirect_uris/)
      end
    end

    context "when the document declares a confidential auth method" do
      before do
        stub_request(:get, client_id_url)
          .to_return(status: 200, body: valid_metadata.merge(token_endpoint_auth_method: "client_secret_post").to_json)
      end

      it "raises an InvalidMetadata error" do
        resolver = described_class.new(client_id_url)
        expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /public/)
      end
    end

    context "when the document includes a client_secret" do
      before do
        stub_request(:get, client_id_url)
          .to_return(status: 200, body: valid_metadata.merge(client_secret: "sneaky").to_json)
      end

      it "raises an InvalidMetadata error" do
        resolver = described_class.new(client_id_url)
        expect { resolver.resolve! }.to raise_error(described_class::InvalidMetadata, /client_secret/)
      end
    end

    context "when the server redirects" do
      before do
        stub_request(:get, client_id_url)
          .to_return(status: 302, headers: { "Location" => "https://good.example.com/other.json" })
      end

      it "raises a FetchError rather than following the redirect" do
        resolver = described_class.new(client_id_url)
        expect { resolver.resolve! }.to raise_error(described_class::FetchError)
      end
    end
  end
end
