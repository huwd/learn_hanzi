require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations" do
    subject(:user) { build(:user) }

    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_uniqueness_of(:email_address).case_insensitive }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:uid) }
    it { is_expected.to validate_uniqueness_of(:uid).scoped_to(:provider) }
  end

  describe "session preferences" do
    subject(:user) { build(:user, session_size: 20, new_cards_per_session: 5) }

    it "is valid with defaults" do
      expect(user).to be_valid
    end

    it "requires session_size to be at least 1" do
      user.session_size = 0
      expect(user).not_to be_valid
    end

    it "requires session_size to be at most 100" do
      user.session_size = 101
      expect(user).not_to be_valid
    end

    it "requires new_cards_per_session to be at least 0" do
      user.new_cards_per_session = -1
      expect(user).not_to be_valid
    end

    it "requires new_cards_per_session not to exceed session_size" do
      user.session_size = 10
      user.new_cards_per_session = 11
      expect(user).not_to be_valid
    end

    it "allows new_cards_per_session equal to session_size" do
      user.session_size = 10
      user.new_cards_per_session = 10
      expect(user).to be_valid
    end
  end

  describe ".find_or_create_by_omniauth" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: OIDC_PROVIDER_NAME,
        uid: "uid-123",
        info: { email: "user@example.com" }
      )
    end

    it "creates a new user when none exists" do
      expect { User.find_or_create_by_omniauth(auth) }.to change(User, :count).by(1)
    end

    it "finds an existing user by provider and uid" do
      existing = create(:user, provider: OIDC_PROVIDER_NAME, uid: "uid-123")
      found = User.find_or_create_by_omniauth(auth)
      expect(found).to eq(existing)
    end

    it "sets the email from the auth info" do
      user = User.find_or_create_by_omniauth(auth)
      expect(user.email_address).to eq("user@example.com")
    end

    it "syncs the email when it has changed in the OIDC provider" do
      create(:user, provider: OIDC_PROVIDER_NAME, uid: "uid-123", email_address: "old@example.com")
      user = User.find_or_create_by_omniauth(auth)
      expect(user.email_address).to eq("user@example.com")
    end
  end
end
