require "rails_helper"

RSpec.describe "OmniauthCallbacks", type: :request do
  let(:provider_name) { OIDC_PROVIDER_NAME }

  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: provider_name,
      uid: "test-uid-123",
      info: { email: "test@example.com" }
    )
  end

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[provider_name.to_sym] = auth_hash
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(provider_name.to_sym)
  end

  # Simulate the full OIDC callback flow: request phase → redirect → callback
  def trigger_oidc_callback
    get "/auth/#{provider_name}"
    follow_redirect!
  end

  describe "OIDC callback flow" do
    context "when user does not exist" do
      it "creates a new user" do
        expect { trigger_oidc_callback }.to change(User, :count).by(1)
      end

      it "sets the user's provider, uid, and email" do
        trigger_oidc_callback
        user = User.last
        expect(user.provider).to eq(provider_name)
        expect(user.uid).to eq("test-uid-123")
        expect(user.email_address).to eq("test@example.com")
      end

      it "redirects to root" do
        trigger_oidc_callback
        expect(response).to redirect_to(root_path)
      end

      it "creates a session" do
        expect { trigger_oidc_callback }.to change(Session, :count).by(1)
      end
    end

    context "when user already exists with matching provider and uid" do
      let!(:user) { create(:user, provider: provider_name, uid: "test-uid-123") }

      it "does not create a new user" do
        expect { trigger_oidc_callback }.not_to change(User, :count)
      end

      it "redirects to root" do
        trigger_oidc_callback
        expect(response).to redirect_to(root_path)
      end

      it "creates a session for the existing user" do
        trigger_oidc_callback
        expect(Session.last.user).to eq(user)
      end
    end
  end

  describe "GET /auth/failure" do
    it "redirects to root with an alert" do
      get "/auth/failure?message=access_denied"
      expect(response).to redirect_to(root_path)
    end
  end
end
