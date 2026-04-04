require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET /" do
    context "when unauthenticated" do
      it "redirects to the login page" do
        get root_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns a successful response" do
        get root_path
        expect(response).to have_http_status(:success)
      end

      it "includes a link to start a review" do
        get root_path
        expect(response.body).to include(review_path)
      end

      it "includes a link to start learning" do
        get root_path
        expect(response.body).to include(learn_path)
      end

      context "with cards due" do
        before do
          create(:user_learning, user: user, state: "learning",
                 next_due: 1.day.ago, last_interval: 3)
        end

        it "shows the number of cards due" do
          get root_path
          expect(response.body).to include("1")
        end
      end

      context "with no cards due" do
        it "shows zero cards due" do
          get root_path
          expect(response.body).to include("0")
        end
      end

      context "with an HSK tag hierarchy" do
        let!(:hsk_root)    { create(:tag, name: "HSK") }
        let!(:hsk_version) { create(:tag, name: "HSK 2.0", parent: hsk_root) }
        let!(:hsk_level)   { create(:tag, name: "HSK 1",   parent: hsk_version) }
        let!(:entry)       { create(:dictionary_entry).tap { |e| e.tags << hsk_level } }

        it "renders the version tag name" do
          get root_path
          expect(response.body).to include("HSK 2.0")
        end

        it "renders the level tag name" do
          get root_path
          expect(response.body).to include("HSK 1")
        end

        it "links to the level tag page" do
          get root_path
          expect(response.body).to include(tag_path(hsk_level))
        end

        context "with a mastered entry" do
          before { create(:user_learning, user: user, dictionary_entry: entry, state: "mastered") }

          it "includes mastered count in the level stats" do
            get root_path
            expect(response.body).to include("1")
          end
        end
      end
    end
  end
end
