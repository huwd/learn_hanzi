require 'rails_helper'

RSpec.describe Current, type: :model do
  describe "attributes" do
    it "allows setting and getting the session" do
      session = double("session")
      Current.session = session
      expect(Current.session).to eq(session)
    end
  end

  describe "delegations" do
    it "delegates user to session" do
      user = double("user")
      session = double("session", user: user)
      Current.session = session
      expect(Current.user).to eq(user)
    end

    it "returns nil if session is nil" do
      Current.session = nil
      expect(Current.user).to be_nil
    end
  end
end