require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user, email_address: "test@example.com", password: "password") }

  describe "GET /session/new" do
    it "returns a successful response" do
      get new_session_path
      expect(response).to have_http_status(:success)
    end

    it "renders the new template" do
      get new_session_path
      expect(response.body).to include("Sign in</h1>")
    end

    it "renders the new session template with Sign up as a link" do
      get new_session_path
      expect(response.body).to include("Sign up</a>")
    end

    it "renders the new session template with Sign ip as a h1" do
      get new_session_path
      expect(response.body).to include("Sign in</h1>")
    end
  end

  describe "POST /session" do
    let(:valid_params) do
      {
        email_address: user.email_address,
        password: user.password
      }
    end

    let(:invalid_params) do
      {
        email_address: user.email_address,
        password: "wrongpassword"
      }
    end

    context "with valid parameters" do
      it "signs in the user" do
        post session_path, params: valid_params
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Dashboard")
      end
    end

    context "with invalid parameters" do
      it "does not sign in the user" do
        post session_path, params: invalid_params
        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include("Try another email address or password.")
      end
    end
  end

  describe "DELETE /session" do
    before do
      sign_in user
    end

    it "signs out the user" do
      delete session_path
      expect(response).to redirect_to(new_session_path)
      follow_redirect!
    end
  end
end
