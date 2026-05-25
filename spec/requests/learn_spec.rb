require 'rails_helper'

RSpec.describe "Learn", type: :request do
  let(:user) { create(:user) }
  let!(:new_card) { create(:user_learning, user: user, state: "new") }

  # -------------------------------------------------------------------------
  # GET /learn — start session
  # -------------------------------------------------------------------------
  describe "GET /learn" do
    context "when unauthenticated" do
      it "redirects to login" do
        get learn_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      context "when new cards are available" do
        it "redirects to the learn card path" do
          get learn_path
          expect(response).to redirect_to(learn_card_path)
        end

        it "stores the queue in the session" do
          get learn_path
          expect(request.session[:learn_queue]).to include(new_card.id)
        end

        it "initialises the index at 0" do
          get learn_path
          expect(request.session[:learn_index]).to eq(0)
        end

        it "initialises learn_introduced as an empty array" do
          get learn_path
          expect(request.session[:learn_introduced]).to eq([])
        end
      end

      context "queue ordering by HSK level" do
        let(:hsk_version) { create(:tag, name: "HSK 2.0") }
        let(:hsk1_tag)    { create(:tag, name: "HSK 1", parent: hsk_version) }
        let(:hsk4_tag)    { create(:tag, name: "HSK 4", parent: hsk_version) }

        let!(:hsk4_entry) { create(:dictionary_entry).tap { |e| e.tags << hsk4_tag } }
        let!(:hsk1_entry) { create(:dictionary_entry).tap { |e| e.tags << hsk1_tag } }

        let!(:hsk4_card) { create(:user_learning, user: user, state: "new", dictionary_entry: hsk4_entry) }
        let!(:hsk1_card) { create(:user_learning, user: user, state: "new", dictionary_entry: hsk1_entry) }

        before { new_card.update!(state: "learning", next_due: 1.day.from_now, last_interval: 1) }

        it "puts the lower HSK level card first in the queue" do
          get learn_path
          queue = request.session[:learn_queue]
          expect(queue.index(hsk1_card.id)).to be < queue.index(hsk4_card.id)
        end
      end

      context "when new_cards_per_session is lower than the available new cards" do
        before do
          user.update!(new_cards_per_session: 2)
          create_list(:user_learning, 4, user: user, state: "new")
        end

        it "caps the queue at new_cards_per_session" do
          get learn_path
          expect(request.session[:learn_queue].size).to eq(2)
        end
      end

      context "when new_cards_per_session exceeds what the advisor would cap" do
        before do
          user.update!(new_cards_per_session: 8)
          create_list(:user_learning, 8, user: user, state: "new")
          new_card.update!(state: "learning", next_due: 1.day.from_now, last_interval: 1)
        end

        it "queues up to new_cards_per_session rather than the advisor's lower recommendation" do
          get learn_path
          expect(request.session[:learn_queue].size).to eq(8)
        end
      end

      context "when no new cards are available" do
        before { new_card.update!(state: "learning", next_due: 1.day.from_now, last_interval: 1) }

        it "renders the empty state" do
          get learn_path
          expect(response).to have_http_status(:success)
        end
      end

      context "with a tag_id param (tag-filtered session)" do
        let(:tag) { create(:tag) }
        let!(:tagged_entry) { create(:dictionary_entry).tap { |e| e.tags << tag } }

        before { new_card.update!(state: "learning", next_due: 1.day.from_now, last_interval: 1) }

        context "when the tag has unlearned entries (no UserLearning)" do
          it "creates UserLearning records for unlearned entries" do
            expect {
              get learn_path(tag_id: tag.id)
            }.to change(UserLearning, :count).by(1)
          end

          it "sets the new records to state new" do
            get learn_path(tag_id: tag.id)
            expect(UserLearning.last.state).to eq("new")
          end

          it "queues the newly created card" do
            get learn_path(tag_id: tag.id)
            new_ul = UserLearning.find_by(user: user, dictionary_entry: tagged_entry)
            expect(request.session[:learn_queue]).to include(new_ul.id)
          end

          it "redirects to the learn card path" do
            get learn_path(tag_id: tag.id)
            expect(response).to redirect_to(learn_card_path)
          end
        end

        context "when the tag has existing new-state entries" do
          let!(:existing_new) { create(:user_learning, user: user, state: "new", dictionary_entry: tagged_entry) }

          it "does not create duplicate UserLearning records" do
            expect {
              get learn_path(tag_id: tag.id)
            }.not_to change(UserLearning, :count)
          end

          it "queues the existing new card" do
            get learn_path(tag_id: tag.id)
            expect(request.session[:learn_queue]).to include(existing_new.id)
          end
        end

        context "prioritisation: unlearned before existing new" do
          let(:other_entry) { create(:dictionary_entry).tap { |e| e.tags << tag } }
          let!(:existing_new) { create(:user_learning, user: user, state: "new", dictionary_entry: other_entry) }

          it "puts the unlearned (newly created) card before the existing new card" do
            get learn_path(tag_id: tag.id)
            queue   = request.session[:learn_queue]
            new_ul  = UserLearning.find_by(user: user, dictionary_entry: tagged_entry)
            expect(queue.index(new_ul.id)).to be < queue.index(existing_new.id)
          end
        end

        context "when the tag has no unlearned or new entries" do
          before { tagged_entry.user_learnings.create!(user: user, state: "mastered", last_interval: 10, factor: 2500, next_due: 1.day.from_now) }

          it "renders the empty state" do
            get learn_path(tag_id: tag.id)
            expect(response).to have_http_status(:success)
          end
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # GET /learn/card — show introduction card
  # -------------------------------------------------------------------------
  describe "GET /learn/card" do
    context "when unauthenticated" do
      it "redirects to login" do
        get learn_card_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated with an active learn session" do
      before do
        sign_in user
        get learn_path
      end

      it "returns a successful response" do
        get learn_card_path
        expect(response).to have_http_status(:success)
      end

      it "wraps card content in a turbo-frame" do
        get learn_card_path
        expect(response.body).to match(/<turbo-frame[^>]*id="card"/)
      end

      it "includes the character in the response" do
        get learn_card_path
        expect(response.body).to include(new_card.dictionary_entry.text)
      end

      it "renders a responsive adaptive card container" do
        get learn_card_path
        expect(response.body).to include('data-card-layout="fixed"')
        expect(response.body).to include('data-card-text-scaling="adaptive"')
        expect(response.body).to include("learn-card")
        expect(response.body).to include("adaptive-card-text")
        expect(response.body).to include("w-full max-w-xl")
        expect(response.body).to include("min-h-[28rem] md:h-[30rem]")
      end

      it "shows a supplemental meanings toggle when available" do
        create(:meaning, dictionary_entry: new_card.dictionary_entry, text: "secondary meaning")

        get learn_card_path

        expect(response.body).to include("Show more meanings")
      end

      it "shows alternate reading pinyin alongside heteronym meanings" do
        new_card.dictionary_entry.meanings.destroy_all
        cedict_source = create(:source,
                               name: "CC-CEDICT",
                               url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
        create(:meaning, dictionary_entry: new_card.dictionary_entry,
                         source: cedict_source,
                         text: "fake", pinyin: "jiǎ")
        create(:meaning, dictionary_entry: new_card.dictionary_entry,
                         source: cedict_source,
                         text: "holiday", pinyin: "jià")

        get learn_card_path

        expect(response.body).to include("fake")
        expect(response.body).to include("jià")
        expect(response.body).to include("holiday")
      end

      it "uses learner-friendly CC-CEDICT meaning and pinyin as primary" do
        new_card.dictionary_entry.meanings.destroy_all
        cedict_source = create(:source,
                               name: "CC-CEDICT",
                               url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
        create(:meaning, dictionary_entry: new_card.dictionary_entry,
                         source: cedict_source,
                         text: "surname Li", pinyin: "Lǐ")
        create(:meaning, dictionary_entry: new_card.dictionary_entry,
                         source: cedict_source,
                         text: "plum", pinyin: "lǐ")

        get learn_card_path

        expect(response.body).to include("plum")
        expect(response.body).to include("lǐ")
      end

      it "shows full-token and per-character related anchors with labels" do
        new_card.dictionary_entry.update!(text: "学习")

        full_entry = create(:dictionary_entry, text: "学习者", frequency_rank: 120)
        per_entry = create(:dictionary_entry, text: "学校", frequency_rank: 10)

        create(:user_learning, user: user, dictionary_entry: full_entry, state: "mastered")
        create(:user_learning, user: user, dictionary_entry: per_entry, state: "mastered")

        get learn_card_path

        expect(response.body).to include("Full token")
        expect(response.body).to include("Char 学")
      end

      it "groups related anchors by shared character" do
        new_card.dictionary_entry.update!(text: "学习")

        create(:user_learning, user: user, dictionary_entry: create(:dictionary_entry, text: "学校", frequency_rank: 10), state: "mastered")
        create(:user_learning, user: user, dictionary_entry: create(:dictionary_entry, text: "练习", frequency_rank: 20), state: "mastered")

        get learn_card_path

        expect(response.body).to include("Character")
        expect(response.body).to include("学校")
        expect(response.body).to include("练习")
      end

      it "shows a full-token group separately from shared-character groups" do
        new_card.dictionary_entry.update!(text: "学习")

        create(:user_learning, user: user, dictionary_entry: create(:dictionary_entry, text: "学习者", frequency_rank: 5), state: "mastered")
        create(:user_learning, user: user, dictionary_entry: create(:dictionary_entry, text: "学校", frequency_rank: 10), state: "mastered")

        get learn_card_path

        expect(response.body).to include("Match")
        expect(response.body).to include("Full token")
        expect(response.body).to include("Character")
      end

      it "orders related anchors by match type then frequency rank" do
        new_card.dictionary_entry.update!(text: "学习")

        full_entry = create(:dictionary_entry, text: "学习者", frequency_rank: 999)
        per_entry = create(:dictionary_entry, text: "学校", frequency_rank: 1)

        create(:user_learning, user: user, dictionary_entry: per_entry, state: "mastered")
        create(:user_learning, user: user, dictionary_entry: full_entry, state: "mastered")

        get learn_card_path

        expect(response.body.index("学习者")).to be < response.body.index("学校")
      end

      it "shows entries under each shared character they match" do
        new_card.dictionary_entry.update!(text: "学习")
        create(:user_learning, user: user, dictionary_entry: create(:dictionary_entry, text: "习学", frequency_rank: 10), state: "mastered")

        get learn_card_path

        expect(response.body.scan("习学").size).to eq(2)
        expect(response.body).to include("Also matches 习")
      end

      it "shows radical breakdown details in the contextual panel" do
        radical_yan = create(:radical, character: "讠", meaning: "speech", stroke_count: 2)
        radical_wu = create(:radical, character: "吾", meaning: "I", stroke_count: 7)

        create(:dictionary_entry_radical, dictionary_entry: new_card.dictionary_entry, radical: radical_yan, position: 1)
        create(:dictionary_entry_radical, dictionary_entry: new_card.dictionary_entry, radical: radical_wu, position: 2)

        get learn_card_path

        expect(response.body).to include("Character components")
        expect(response.body).to include("讠")
        expect(response.body).to include("2 strokes")
        expect(response.body).to include("speech")
        expect(response.body).to include("吾")
        expect(response.body).to include("7 strokes")
      end

      it "shows stroke order in the contextual panel when available" do
        create(:stroke_order_datum, dictionary_entry: new_card.dictionary_entry, strokes: [ "M 0 0" ], medians: [ [ [ 0, 0 ], [ 1, 1 ] ] ])

        get learn_card_path

        expect(response.body).to include("Stroke order:")
        expect(response.body).to include('data-controller="hanzi-writer"')
      end

      it "marks a radical as mastered when the learner knows it" do
        radical_wu = create(:radical, character: "吾", meaning: "I", stroke_count: 7)
        radical_entry = create(:dictionary_entry, text: "吾")
        create(:user_learning, user: user, dictionary_entry: radical_entry, state: "mastered")
        create(:dictionary_entry_radical, dictionary_entry: new_card.dictionary_entry, radical: radical_wu, position: 1)

        get learn_card_path

        expect(response.body).to include("Mastered")
      end

      it "adds learn show performance timings to the request payload" do
        payload = nil
        callback = lambda do |_name, _start, _finish, _id, data|
          payload = data if data[:controller] == "LearnController" && data[:action] == "show"
        end

        ActiveSupport::Notifications.subscribed(callback, "process_action.action_controller") do
          get learn_card_path
        end

        expect(payload).to include(
          :perf_learn_show_total_ms,
          :perf_learn_show_user_learning_lookup_ms,
          :perf_learn_show_related_anchors_ms,
          :perf_learn_show_radical_breakdown_ms,
          :perf_learn_show_stroke_order_diagrams_ms
        )
      end
    end

    context "when authenticated without an active learn session" do
      before { sign_in user }

      it "redirects to learn start" do
        get learn_card_path
        expect(response).to redirect_to(learn_path)
      end
    end
  end

  # -------------------------------------------------------------------------
  # POST /learn/card — submit know_it / don't know it
  # -------------------------------------------------------------------------
  describe "POST /learn/card" do
    context "when authenticated with an active learn session" do
      before do
        sign_in user
        get learn_path
      end

      context "when know_it is true" do
        it "sets the card state to learning" do
          post learn_card_path, params: { know_it: "true" }
          expect(new_card.reload.state).to eq("learning")
        end

        it "adds the card to learn_introduced" do
          post learn_card_path, params: { know_it: "true" }
          expect(request.session[:learn_introduced]).to include(new_card.id)
        end

        it "adds learn submit performance timings to the request payload" do
          payload = nil
          callback = lambda do |_name, _start, _finish, _id, data|
            payload = data if data[:controller] == "LearnController" && data[:action] == "submit"
          end

          ActiveSupport::Notifications.subscribed(callback, "process_action.action_controller") do
            post learn_card_path, params: { know_it: "true" }
          end

          expect(payload).to include(
            :perf_learn_submit_total_ms,
            :perf_learn_submit_user_learning_lookup_ms,
            :perf_learn_submit_update_user_learning_ms
          )
        end
      end

      context "when know_it is false" do
        it "sets the card state to learning" do
          post learn_card_path, params: { know_it: "false" }
          expect(new_card.reload.state).to eq("learning")
        end

        it "adds the card to learn_introduced" do
          post learn_card_path, params: { know_it: "false" }
          expect(request.session[:learn_introduced]).to include(new_card.id)
        end
      end

      context "when the last card is submitted" do
        it "redirects to the learn review path" do
          post learn_card_path, params: { know_it: "true" }
          expect(response).to redirect_to(learn_review_path)
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # GET /learn/review — mini SM-2 review
  # -------------------------------------------------------------------------
  describe "GET /learn/review" do
    context "when authenticated, session complete, review phase active" do
      before do
        sign_in user
        get learn_path
        post learn_card_path, params: { know_it: "true" }
      end

      it "returns a successful response" do
        get learn_review_path
        expect(response).to have_http_status(:success)
      end

      it "wraps card content in a turbo-frame" do
        get learn_review_path
        expect(response.body).to match(/<turbo-frame[^>]*id="card"/)
      end

      it "includes the character in the response" do
        get learn_review_path
        expect(response.body).to include(new_card.dictionary_entry.text)
      end

      it "renders adaptive text sizing on review cards" do
        get learn_review_path
        expect(response.body).to include('data-card-text-scaling="adaptive"')
        expect(response.body).to include("card-flip")
        expect(response.body).to include("adaptive-card-text")
        expect(response.body).to include("w-full max-w-xl")
      end

      it "renders ease buttons with data-ease attributes for keyboard shortcuts" do
        get learn_review_path
        expect(response.body).to include('data-ease="1"')
        expect(response.body).to include('data-ease="2"')
        expect(response.body).to include('data-ease="3"')
        expect(response.body).to include('data-ease="4"')
      end

      it "shows radical breakdown in learn review" do
        radical_yan = create(:radical, character: "讠", meaning: "speech", stroke_count: 2)
        create(:dictionary_entry_radical, dictionary_entry: new_card.dictionary_entry, radical: radical_yan, position: 1)

        get learn_review_path

        expect(response.body).to include("Character components")
        expect(response.body).to include("讠")
        expect(response.body).to include("speech")
      end

      it "shows stroke order in learn review when available" do
        create(:stroke_order_datum, dictionary_entry: new_card.dictionary_entry, strokes: [ "M 0 0" ], medians: [ [ [ 0, 0 ], [ 1, 1 ] ] ])

        get learn_review_path

        expect(response.body).to include("Stroke order:")
        expect(response.body).to include('data-controller="hanzi-writer"')
      end

      it "shows a play button when pronunciation audio is available" do
        create(:audio_pronunciation, dictionary_entry: new_card.dictionary_entry)

        get learn_review_path

        expect(response.body).to include("Play audio for #{new_card.dictionary_entry.text}")
      end

      it "adds learn review show performance timings to the request payload" do
        payload = nil
        callback = lambda do |_name, _start, _finish, _id, data|
          payload = data if data[:controller] == "LearnController" && data[:action] == "review_show"
        end

        ActiveSupport::Notifications.subscribed(callback, "process_action.action_controller") do
          get learn_review_path
        end

        expect(payload).to include(
          :perf_learn_review_show_total_ms,
          :perf_learn_review_show_user_learning_lookup_ms,
          :perf_learn_review_show_related_anchors_ms,
          :perf_learn_review_show_radical_breakdown_ms,
          :perf_learn_review_show_stroke_order_diagrams_ms
        )
      end
    end

    context "when authenticated without an active review phase" do
      before { sign_in user }

      it "redirects to learn start" do
        get learn_review_path
        expect(response).to redirect_to(learn_path)
      end
    end
  end

  # -------------------------------------------------------------------------
  # POST /learn/review — submit SM-2 ease rating
  # -------------------------------------------------------------------------
  describe "POST /learn/review" do
    before do
      sign_in user
      get learn_path
      post learn_card_path, params: { know_it: "true" }
    end

    context "with a valid ease rating" do
      it "creates a ReviewLog entry" do
        expect {
          post learn_review_path, params: { ease: 3 }
        }.to change(ReviewLog, :count).by(1)
      end

      context "when the last review card is rated" do
        it "redirects to the learn summary" do
          post learn_review_path, params: { ease: 3 }
          expect(response).to redirect_to(learn_summary_path)
        end
      end

      it "adds learn review submit performance timings to the request payload" do
        payload = nil
        callback = lambda do |_name, _start, _finish, _id, data|
          payload = data if data[:controller] == "LearnController" && data[:action] == "review_submit"
        end

        ActiveSupport::Notifications.subscribed(callback, "process_action.action_controller") do
          post learn_review_path, params: { ease: 3 }
        end

        expect(payload).to include(
          :perf_learn_review_submit_total_ms,
          :perf_learn_review_submit_user_learning_lookup_ms,
          :perf_learn_review_submit_sm2_ms,
          :perf_learn_review_submit_transaction_ms
        )
      end
    end

    context "with an invalid ease rating" do
      it "returns unprocessable content" do
        post learn_review_path, params: { ease: 5 }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # -------------------------------------------------------------------------
  # GET /learn/summary
  # -------------------------------------------------------------------------
  describe "GET /learn/summary" do
    context "when authenticated with a completed session" do
      before do
        sign_in user
        get learn_path
        post learn_card_path, params: { know_it: "true" }
        post learn_review_path, params: { ease: 3 }
      end

      it "returns a successful response" do
        get learn_summary_path
        expect(response).to have_http_status(:success)
      end

      it "sets Turbo-Frame: _top to escape the card frame when requested as a frame" do
        get learn_summary_path, headers: { "Turbo-Frame" => "card" }
        expect(response.headers["Turbo-Frame"]).to eq("_top")
      end
    end

    context "when authenticated without a started session" do
      before { sign_in user }

      it "redirects to learn start" do
        get learn_summary_path
        expect(response).to redirect_to(learn_path)
      end
    end
  end
end
