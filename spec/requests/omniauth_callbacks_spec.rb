require "rails_helper"

RSpec.describe "OmniauthCallbacks", type: :request do
  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: "pocket_id",
      uid: "test-uid-123",
      info: { email: "test@example.com" }
    )
  end

  before do
    OmniAuth.config.test_mode = true
    Rails.application.env_config["omniauth.auth"] = auth_hash
  end

  after do
    OmniAuth.config.test_mode = false
    Rails.application.env_config.delete("omniauth.auth")
  end

  describe "GET /auth/pocket_id/callback" do
    context "when user does not exist" do
      it "creates a new user" do
        expect { get "/auth/pocket_id/callback" }.to change(User, :count).by(1)
      end

      it "sets the user's provider and uid" do
        get "/auth/pocket_id/callback"
        user = User.last
        expect(user.provider).to eq("pocket_id")
        expect(user.uid).to eq("test-uid-123")
        expect(user.email_address).to eq("test@example.com")
      end

      it "redirects to root" do
        get "/auth/pocket_id/callback"
        expect(response).to redirect_to(root_path)
      end

      it "creates a session" do
        expect { get "/auth/pocket_id/callback" }.to change(Session, :count).by(1)
      end
    end

    context "when user already exists with matching provider and uid" do
      let!(:user) { create(:user, provider: "pocket_id", uid: "test-uid-123") }

      it "does not create a new user" do
        expect { get "/auth/pocket_id/callback" }.not_to change(User, :count)
      end

      it "redirects to root" do
        get "/auth/pocket_id/callback"
        expect(response).to redirect_to(root_path)
      end

      it "creates a session for the existing user" do
        get "/auth/pocket_id/callback"
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
