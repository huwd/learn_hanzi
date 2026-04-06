require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations" do
    it "validates presence of email_address" do
      user = User.new(password: "password")
      expect(user).to validate_presence_of(:email_address)
    end

    it "validates presence of password" do
      user = User.new(email_address: "test@example.com")
      expect(user).to validate_presence_of(:password)
    end

    it "validates uniqueness of email_address" do
      User.create!(email_address: "test@example.com", password: "password")
      user = User.new(email_address: "test@example.com", password: "password")
      expect(user).to validate_uniqueness_of(:email_address).case_insensitive
    end
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

  describe "authentication" do
    it "authenticates with a valid password" do
      user = User.create(email_address: "test@example.com", password: "password")
      expect(user.authenticate("password")).to be_truthy
    end

    it "does not authenticate with an invalid password" do
      user = User.create(email_address: "test@example.com", password: "password")
      expect(user.authenticate("wrong_password")).to be_falsey
    end
  end
end
