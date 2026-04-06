require 'rails_helper'

RSpec.describe "Review", type: :request do
  let(:user) { create(:user) }
  let!(:user_learning) do
    create(:user_learning, user: user, state: "learning",
           next_due: 1.day.ago, last_interval: 3)
  end

  # -------------------------------------------------------------------------
  # GET /review — start session
  # -------------------------------------------------------------------------
  describe "GET /review" do
    context "when unauthenticated" do
      it "redirects to login" do
        get review_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in user }

      context "when cards are due" do
        it "redirects to the card path" do
          get review_path
          expect(response).to redirect_to(review_card_path)
        end

        it "stores the queue in the session" do
          get review_path
          expect(session[:review_queue]).to include(user_learning.id)
        end

        it "stores the session start time" do
          get review_path
          expect(session[:review_started_at]).to be_present
        end

        it "initialises the index at zero" do
          get review_path
          expect(session[:review_index]).to eq(0)
        end
      end

      context "when the user has custom session preferences" do
        before do
          user.update!(session_size: 2, new_cards_per_session: 0)
          # Create extra overdue cards beyond the user's custom session_size
          create_list(:user_learning, 5, user: user, state: "learning",
                      next_due: 1.day.ago, last_interval: 1)
        end

        it "limits the queue to the user's session_size" do
          get review_path
          expect(session[:review_queue].size).to eq(2)
        end
      end

      context "with a tag_id param" do
        let(:tag)      { create(:tag, name: "HSK 4") }
        let(:other)    { create(:tag, name: "HSK 2") }

        let!(:in_tag_learning) do
          entry = create(:dictionary_entry).tap { |e| e.tags << tag }
          create(:user_learning, user: user, dictionary_entry: entry,
                 state: "learning", next_due: 1.day.ago, last_interval: 1)
        end

        before { user_learning.dictionary_entry.tags << other }

        it "only queues cards within that tag" do
          get review_path, params: { tag_id: tag.id }
          expect(session[:review_queue]).to eq([ in_tag_learning.id ])
        end

        it "excludes cards outside that tag" do
          get review_path, params: { tag_id: tag.id }
          expect(session[:review_queue]).not_to include(user_learning.id)
        end

        it "redirects to the card path" do
          get review_path, params: { tag_id: tag.id }
          expect(response).to redirect_to(review_card_path)
        end
      end

      context "when no cards are due" do
        before { user_learning.update!(next_due: 7.days.from_now) }

        it "returns 200" do
          get review_path
          expect(response).to have_http_status(:ok)
        end

        it "renders the empty state" do
          get review_path
          expect(response.body).to include("No cards due")
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # GET /review/card — show current card
  # -------------------------------------------------------------------------
  describe "GET /review/card" do
    context "when unauthenticated" do
      it "redirects to login" do
        get review_card_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in user }

      context "with an active review session" do
        before { get review_path }

        it "returns 200" do
          get review_card_path
          expect(response).to have_http_status(:ok)
        end

        it "shows the character" do
          get review_card_path
          expect(response.body).to include(user_learning.dictionary_entry.text)
        end

        it "shows a progress indicator" do
          get review_card_path
          expect(response.body).to match(/1.*\/.*1/)
        end
      end

      context "with no review session" do
        it "redirects to review start" do
          get review_card_path
          expect(response).to redirect_to(review_path)
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # POST /review/card — submit ease rating
  # -------------------------------------------------------------------------
  describe "POST /review/card" do
    context "when unauthenticated" do
      it "redirects to login" do
        post review_card_path, params: { ease: 3 }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated" do
      before do
        sign_in user
        get review_path
      end

      context "with a valid ease rating" do
        it "creates a ReviewLog" do
          expect {
            post review_card_path, params: { ease: 3 }
          }.to change(ReviewLog, :count).by(1)
        end

        it "records the ease on the ReviewLog" do
          post review_card_path, params: { ease: 3 }
          expect(ReviewLog.last.ease).to eq(3)
        end

        it "updates the UserLearning next_due" do
          expect {
            post review_card_path, params: { ease: 3 }
          }.to change { user_learning.reload.next_due }
        end

        it "updates the UserLearning last_interval" do
          expect {
            post review_card_path, params: { ease: 3 }
          }.to change { user_learning.reload.last_interval }
        end
      end

      context "on the last card in the queue" do
        it "redirects to the summary" do
          post review_card_path, params: { ease: 3 }
          expect(response).to redirect_to(review_summary_path)
        end
      end

      context "with more cards remaining" do
        let!(:second_learning) do
          create(:user_learning, user: user, state: "learning",
                 next_due: 2.days.ago, last_interval: 1)
        end

        before do
          get review_path  # rebuild queue with both cards
        end

        it "advances to the next card" do
          post review_card_path, params: { ease: 3 }
          expect(session[:review_index]).to eq(1)
        end

        it "redirects to the card path" do
          post review_card_path, params: { ease: 3 }
          expect(response).to redirect_to(review_card_path)
        end
      end

      context "with an invalid ease rating" do
        it "returns unprocessable content" do
          post review_card_path, params: { ease: 99 }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "with no review session" do
      before { sign_in user }

      it "redirects to review start" do
        post review_card_path, params: { ease: 3 }
        expect(response).to redirect_to(review_path)
      end
    end
  end

  # -------------------------------------------------------------------------
  # GET /review/summary — session summary
  # -------------------------------------------------------------------------
  describe "GET /review/summary" do
    context "when unauthenticated" do
      it "redirects to login" do
        get review_summary_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in user }

      context "after completing a session" do
        before do
          get review_path
          post review_card_path, params: { ease: 3 }
          follow_redirect!
        end

        it "returns 200" do
          expect(response).to have_http_status(:ok)
        end

        it "shows the total cards reviewed" do
          expect(response.body).to include("1")
        end

        it "has a link to start a new session" do
          expect(response.body).to include(review_path)
        end
      end

      context "with no completed session" do
        it "redirects to review start" do
          get review_summary_path
          expect(response).to redirect_to(review_path)
        end
      end
    end
  end
end
