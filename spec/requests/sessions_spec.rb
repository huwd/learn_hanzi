require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user) }

  describe "unauthenticated access" do
    it "redirects to the OIDC provider" do
      get root_path
      expect(response).to redirect_to("/sign_in")
    end
  end

  describe "DELETE /session" do
    before do
      sign_in user
    end

    it "signs out the user and redirects to root" do
      delete session_path
      expect(response).to redirect_to(root_path)
    end

    it "destroys the session" do
      expect { delete session_path }.to change(Session, :count).by(-1)
    end
  end
end
