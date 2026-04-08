require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET /" do
    context "when unauthenticated" do
      it "redirects to the login page" do
        get root_path
        expect(response).to redirect_to("/sign_in")
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

      it "includes a link to the import page in the nav" do
        get root_path
        expect(response.body).to include(new_anki_import_path)
      end

      context "when the user has no learning data" do
        it "shows the import prompt" do
          get root_path
          expect(response.body).to include("No learning data yet")
        end

        it "names the supported deck" do
          get root_path
          expect(response.body).to include(AnkiImportService::DECK_NAME)
        end

        it "links to the Anki import page" do
          get root_path
          expect(response.body).to include(new_anki_import_path)
        end

        it "links to the data import page" do
          get root_path
          expect(response.body).to include(new_data_import_path)
        end

        it "does not show the advisor narrative" do
          get root_path
          LearningAdvisor::NARRATIVES.each_value do |narrative|
            expect(response.body).not_to include(narrative)
          end
        end
      end

      context "when the user has learning data" do
        before { create(:user_learning, user: user) }

        it "does not show the import prompt" do
          get root_path
          expect(response.body).not_to include("No learning data yet")
        end

        it "shows the advisor narrative" do
          get root_path
          expect(response.body).to include(CGI.escapeHTML(LearningAdvisor::NARRATIVES[:lapsed]))
        end
      end

      context "with an overdue learning card" do
        before do
          create(:user_learning, user: user, state: "learning",
                 next_due: 1.day.ago, last_interval: 3)
        end

        it "shows 1 in the in-progress due row" do
          get root_path
          expect(response.body).to match(%r{In progress</dt>\s*<dd[^>]*>1</dd>})
        end

        it "shows 0 in the to-review due row" do
          get root_path
          expect(response.body).to match(%r{To review</dt>\s*<dd[^>]*>0</dd>})
        end
      end

      context "with a mastered card due for review" do
        before do
          create(:user_learning, user: user, state: "mastered",
                 next_due: 1.day.ago, last_interval: 30)
        end

        it "shows 0 in the in-progress due row" do
          get root_path
          expect(response.body).to match(%r{In progress</dt>\s*<dd[^>]*>0</dd>})
        end

        it "shows 1 in the to-review due row" do
          get root_path
          expect(response.body).to match(%r{To review</dt>\s*<dd[^>]*>1</dd>})
        end
      end

      context "with no cards due" do
        before do
          create(:user_learning, user: user, state: "learning",
                 next_due: 7.days.from_now, last_interval: 1)
        end

        it "shows zero for both due counts" do
          get root_path
          expect(response.body).to match(%r{In progress</dt>\s*<dd[^>]*>0</dd>})
          expect(response.body).to match(%r{To review</dt>\s*<dd[^>]*>0</dd>})
        end
      end

      context "with an HSK tag hierarchy" do
        let!(:hsk_root)    { create(:tag, name: "HSK") }
        let!(:hsk_version) { create(:tag, name: "HSK 2.0", parent: hsk_root) }
        let!(:hsk_level)   { create(:tag, name: "HSK 1",   parent: hsk_version) }
        let!(:entry)       { create(:dictionary_entry).tap { |e| e.tags << hsk_level } }
        let!(:learning)    { create(:user_learning, user: user, dictionary_entry: entry) }

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
          before { learning.update!(state: "mastered") }

          it "includes mastered count in the level stats" do
            get root_path
            expect(response.body).to include("1")
          end
        end
      end
    end
  end
end
