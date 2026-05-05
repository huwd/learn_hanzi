require 'rails_helper'

RSpec.describe "Settings", type: :request do
  let(:user) { create(:user) }

  # -------------------------------------------------------------------------
  # GET /settings
  # -------------------------------------------------------------------------
  describe "GET /settings" do
    context "when unauthenticated" do
      it "redirects to login" do
        get settings_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns 200" do
        get settings_path
        expect(response).to have_http_status(:ok)
      end

      context "when settings differ from the advisor's recommendation" do
        before do
          create(:user_learning, user: user)
          # user defaults: session_size 20, new_cards_per_session 5
          # lapsed advisor (no review_logs) recommends: size 15, new_cap 0 — both differ
        end

        it "shows the advisor suggestion callout" do
          get settings_path
          expect(response.body).to include("Advisor suggestion")
        end

        it "includes an align-to-recommendation button" do
          get settings_path
          expect(response.body).to include("Align to recommendation")
        end
      end

      context "when settings match the advisor's recommendation" do
        # no user_learnings → empty profile recommends size 20, new_cap 5 — matches DB defaults
        it "does not show the advisor suggestion callout" do
          get settings_path
          expect(response.body).not_to include("Advisor suggestion")
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # PATCH /settings
  # -------------------------------------------------------------------------
  describe "PATCH /settings" do
    context "when unauthenticated" do
      it "redirects to login" do
        patch settings_path, params: { user: { session_size: 30 } }
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      context "with valid params" do
        it "updates session_size and redirects back to settings" do
          patch settings_path, params: { user: { session_size: 30, new_cards_per_session: 8 } }
          expect(user.reload.session_size).to eq(30)
          expect(user.reload.new_cards_per_session).to eq(8)
          expect(response).to redirect_to(settings_path)
        end
      end

      context "with invalid params" do
        it "re-renders the form when session_size is out of range" do
          patch settings_path, params: { user: { session_size: 0, new_cards_per_session: 5 } }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "re-renders the form when new_cards_per_session exceeds session_size" do
          patch settings_path, params: { user: { session_size: 5, new_cards_per_session: 10 } }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end
end
