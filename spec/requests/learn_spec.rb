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
        expect(response).to redirect_to("/auth/#{OIDC_PROVIDER_NAME}")
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
        expect(response).to redirect_to("/auth/#{OIDC_PROVIDER_NAME}")
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

      it "includes the character in the response" do
        get learn_card_path
        expect(response.body).to include(new_card.dictionary_entry.text)
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

      it "includes the character in the response" do
        get learn_review_path
        expect(response.body).to include(new_card.dictionary_entry.text)
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
    end

    context "with an invalid ease rating" do
      it "returns unprocessable content" do
        post learn_review_path, params: { ease: 5 }
        expect(response).to have_http_status(:unprocessable_entity)
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
