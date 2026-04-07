require 'rails_helper'

RSpec.describe "DictionaryEntries", type: :request do
  let(:user) { create(:user) }
  let(:dictionary_entry) { create(:dictionary_entry) }

  context "when authenticated" do
    before { sign_in user }

    describe "GET /dictionary_entries/:id" do
      it "returns a successful response" do
        get dictionary_entry_path(dictionary_entry)
        expect(response).to have_http_status(:success)
      end

      it "renders the target vocab prominently" do
        get dictionary_entry_path(dictionary_entry)
        expect(response.body).to include(dictionary_entry.text)
      end

      context "when the user has no learning record" do
        it "shows the not-started state" do
          get dictionary_entry_path(dictionary_entry)
          expect(response.body).to include("NOT STARTED")
        end

        it "does not render the review history section" do
          get dictionary_entry_path(dictionary_entry)
          expect(response.body).not_to include("Review history")
        end
      end

      context "when the user has a learning record" do
        let!(:user_learning) do
          create(:user_learning, user: user, dictionary_entry: dictionary_entry, state: "learning")
        end

        it "shows the learning state badge" do
          get dictionary_entry_path(dictionary_entry)
          expect(response.body).to include("LEARNING")
        end

        it "does not render the review history section when there are no logs" do
          get dictionary_entry_path(dictionary_entry)
          expect(response.body).not_to include("Review history")
        end

        context "with review logs" do
          before { create_list(:review_log, 3, user_learning: user_learning, ease: 3) }

          it "renders the review history section" do
            get dictionary_entry_path(dictionary_entry)
            expect(response.body).to include("Review history")
          end
        end
      end
    end
  end

  context "when unauthenticated" do
    describe "GET /dictionary_entries/:id" do
      it "redirects to the login page" do
        get dictionary_entry_path(dictionary_entry)
        expect(response).to redirect_to("/sign_in")
      end
    end
  end
end
