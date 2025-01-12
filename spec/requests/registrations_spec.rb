require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  before do
    Session.destroy_all
  end

  describe "GET /signup" do
    it "returns a successful response" do
      get signup_path
      expect(response).to have_http_status(:success)
    end

    it "renders the new template with Sign up as a H1" do
      get signup_path
      expect(response.body).to include("Sign up /")
    end

    it "renders the new template with Sign In as a link" do
      get signup_path
      expect(response.body).to include("Sign in</a>")
    end
  end

  describe "POST /sign_up" do
    let(:user_params) do
      {
        user: {
          email_address: "test@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new user" do
        expect {
          post signup_path, params: user_params
        }.to change(User, :count).by(1)
      end

      it "redirects to the root path with a notice" do
        post signup_path, params: user_params
        expect(response).to redirect_to(root_path)
        follow_redirect!
      end
    end

    context "with invalid parameters" do
      let(:invalid_user_params) do
        {
          user: {
            email_address: "invalid",
            password: "password",
            password_confirmation: "mismatch"
          }
        }
      end

      it "does not create a new user" do
        expect {
          post signup_path, params: invalid_user_params
        }.not_to change(User, :count)
      end

      it "renders the new template with unprocessable entity status" do
        post signup_path, params: invalid_user_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Sign Up")
      end
    end
  end
end