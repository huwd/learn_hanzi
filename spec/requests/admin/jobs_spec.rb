require "rails_helper"

RSpec.describe "Admin::Jobs", type: :request do
  describe "GET /admin/jobs" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        get "/admin/jobs"
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated as a non-admin" do
      let(:user) { create(:user) }
      before { sign_in user }

      it "redirects to root with an alert" do
        get "/admin/jobs"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when authenticated as an admin" do
      let(:admin) { create(:user, admin: true) }
      before { sign_in admin }

      it "returns 200" do
        get "/admin/jobs"
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
