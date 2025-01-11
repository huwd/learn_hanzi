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
