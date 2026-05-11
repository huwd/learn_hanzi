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

        context "when settings differ from the advisor's recommendation" do
          # user defaults (20/5) differ from lapsed recommendation (15/0)
          it "shows a nudge toward settings" do
            get root_path
            expect(response.body).to include("differ from")
          end

          it "links to the settings page in the nudge" do
            get root_path
            expect(response.body).to include("href=\"#{settings_path}\"")
          end
        end

        context "when settings match the advisor's recommendation" do
          before { user.update!(session_size: 15, new_cards_per_session: 0) }

          it "does not show a settings nudge" do
            get root_path
            expect(response.body).not_to include("differ from")
          end
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

      context "with HSK 3.0 milestone data" do
        let!(:hsk_root)    { create(:tag, name: "HSK") }
        let!(:hsk3)        { create(:tag, name: "HSK 3.0", parent: hsk_root) }
        let!(:hsk1)        { create(:tag, name: "HSK 1", parent: hsk3) }
        let!(:hsk2)        { create(:tag, name: "HSK 2", parent: hsk3) }
        let!(:hsk1_entry_a) { create(:dictionary_entry).tap { |e| e.tags << hsk1 } }
        let!(:hsk1_entry_b) { create(:dictionary_entry).tap { |e| e.tags << hsk1 } }
        let!(:hsk2_entry)   { create(:dictionary_entry).tap { |e| e.tags << hsk2 } }

        before do
          create(:user_learning, user: user, dictionary_entry: hsk1_entry_a,
                 state: "mastered")
          create(:user_learning, user: user, dictionary_entry: hsk1_entry_b,
                 state: "new")
          create(:user_learning, user: user, dictionary_entry: hsk2_entry,
                 state: "new")
        end

        it "shows words remaining until the next incomplete HSK tier" do
          get root_path
          expect(response.body).to match(%r{<div class="text-6xl font-extrabold text-gray-900 dark:text-gray-100 mb-6 text-center">\s*1\s*</div>})
          expect(response.body).to include("1 word until HSK 1 mastery")
        end

        context "when all HSK 3.0 tiers are mastered" do
          before do
            UserLearning.where(user: user).update_all(state: "mastered")
          end

          it "shows a clear completion state" do
            get root_path
            expect(response.body).to include("HSK 3.0 tiers mastered")
            expect(response.body).to match(%r{<div class="text-6xl font-extrabold text-gray-900 dark:text-gray-100 mb-6 text-center">\s*0\s*</div>})
          end
        end

        context "when HSK 3.0 tags are missing" do
          before do
            hsk3.destroy!
          end

          it "falls back to the default learn panel copy" do
            get root_path
            expect(response.body).to include("New words to introduce")
          end
        end

        context "when HSK 3.0 tiers exist but have no tagged entries" do
          let!(:hsk3_empty)   { create(:tag, name: "HSK 3.0", parent: hsk_root) }
          let!(:hsk3_empty_1) { create(:tag, name: "HSK 1", parent: hsk3_empty) }

          before do
            hsk3.destroy!
          end

          it "falls back to the default learn panel copy" do
            get root_path
            expect(response.body).to include("New words to introduce")
          end
        end

        context "when another orphan HSK 3.0 tag exists" do
          before do
            orphan_hsk3 = create(:tag, name: "HSK 3.0")
            orphan_level = create(:tag, name: "HSK 1", parent: orphan_hsk3)
            orphan_entry = create(:dictionary_entry)
            orphan_entry.tags << orphan_level
            create(:user_learning, user: user, dictionary_entry: orphan_entry,
                   state: "new")
          end

          it "uses the HSK root hierarchy for milestone calculations" do
            get root_path
            expect(response.body).to include("1 word until HSK 1 mastery")
          end
        end

        context "when multiple HSK versions are present" do
          let!(:hsk2_root) { create(:tag, name: "HSK 2.0", parent: hsk_root) }
          let!(:hsk2_level) { create(:tag, name: "HSK 2", parent: hsk2_root) }
          let!(:hsk2_version_entry) { create(:dictionary_entry, text: "额外词").tap { |e| e.tags << hsk2_level } }

          before do
            create(:user_learning, user: user, dictionary_entry: hsk2_version_entry,
                   state: "mastered")
          end

          it "shows vocabulary progress for both versions" do
            get root_path
            expect(response.body).to include("HSK 2.0")
            expect(response.body).to include("HSK 3.0")
          end

          it "keeps HSK 3.0 milestone calculations scoped to HSK 3.0" do
            get root_path
            expect(response.body).to include("1 word until HSK 1 mastery")
          end
        end
      end

      context "with mastered vocabulary containing overlapping characters" do
        let!(:entry_hello) { create(:dictionary_entry, text: "你好") }
        let!(:entry_you)   { create(:dictionary_entry, text: "你") }
        let!(:entry_good)  { create(:dictionary_entry, text: "好") }
        let!(:entry_new)   { create(:dictionary_entry, text: "学") }

        before do
          create(:user_learning, user: user, dictionary_entry: entry_hello,
                 state: "mastered")
          create(:user_learning, user: user, dictionary_entry: entry_you,
                 state: "mastered")
          create(:user_learning, user: user, dictionary_entry: entry_good,
                 state: "mastered")
          create(:user_learning, user: user, dictionary_entry: entry_new,
                 state: "new")
        end

        it "shows deduplicated mastered character count in progress" do
          get root_path
          expect(response.body).to include("Characters mastered")
          expect(response.body).to match(%r{Characters mastered</span>\s*<span[^>]*>2</span>})
        end

        it "does not render the old New row in progress" do
          get root_path
          expect(response.body).not_to include("New</dt>")
        end
      end
    end
  end
end
