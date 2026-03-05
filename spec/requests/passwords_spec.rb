require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  let(:user) { create(:user, email_address: "test@example.com") }

  describe "GET /passwords/new" do
    it "returns a successful response" do
      get new_password_path
      expect(response).to have_http_status(:success)
    end

    it "renders the new template" do
      get new_password_path
      expect(response.body).to include("Forgot your password?")
    end
  end

  describe "POST /passwords" do
    context "when user exists" do
      it "sends password reset instructions" do
        expect {
          post passwords_path, params: { email_address: user.email_address }
        }.to have_enqueued_mail(PasswordsMailer, :reset)
        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include("Password reset instructions sent")
      end
    end

    context "when user does not exist" do
      it "redirects to the new session path with a notice" do
        post passwords_path, params: { email_address: "nonexistent@example.com" }
        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include("Password reset instructions sent")
      end
    end
  end

  describe "GET /passwords/:token/edit" do
    context "with a valid token" do
      let(:token) { "valid_token" }

      before do
        allow(User).to receive(:find_by_password_reset_token!).with( token).and_return(user)
      end

      it "returns the update password form" do
        get edit_password_path(token)
        expect(response.body).to include("Update your password")
      end
    end

    context "without a valid token" do
      let(:token) { "bloop" }

      it "redirects to new password and prints an alert" do
        get edit_password_path(token)
        expect(response).to redirect_to(new_password_path)
        follow_redirect!
        expect(response.body).to include("Password reset link is invalid or has expired.")
      end
    end
  end

  describe "PATCH /passwords/:token" do
    let(:token) { "valid_token" }

    before do
      allow(User).to receive(:find_by_password_reset_token!).with( token).and_return(user)
    end

    context "with valid parameters" do
      let(:valid_params) do
        {
          password: "newpassword",
          password_confirmation: "newpassword"
        }
      end

      it "updates the user's password" do
        patch password_path(token), params: valid_params
        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include("Password has been reset")
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          password: "newpassword",
          password_confirmation: "mismatch"
        }
      end

      it "does not update the user's password" do
        patch password_path(token), params: invalid_params
        expect(response).to redirect_to(edit_password_path(token))
        follow_redirect!
        expect(response.body).to include("Passwords did not match")
      end
    end
  end
end
