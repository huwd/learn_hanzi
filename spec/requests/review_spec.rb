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

        it "creates a LearningSession record" do
          expect { get review_path }.to change(LearningSession, :count).by(1)
        end

        it "creates LearningSessionCard records for each queued card" do
          expect { get review_path }.to change(LearningSessionCard, :count).by(1)
        end

        it "stores the learning session id in the cookie session" do
          get review_path
          expect(session[:learning_session_id]).to eq(LearningSession.last.id)
        end

        it "creates the session in in_progress state" do
          get review_path
          expect(LearningSession.last.state).to eq("in_progress")
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
          expect(LearningSession.last.card_count).to eq(2)
        end
      end

      context "when there is already an in_progress session" do
        let!(:existing_session) do
          ls = create(:learning_session, user: user, state: "in_progress",
                      started_at: 10.minutes.ago, card_count: 3)
          create(:learning_session_card, learning_session: ls,
                 user_learning: user_learning, position: 0)
          ls
        end

        it "renders the resume prompt" do
          get review_path
          expect(response).to have_http_status(:ok)
        end

        it "does not create a new LearningSession" do
          expect { get review_path }.not_to change(LearningSession, :count)
        end

        it "shows the number of cards remaining" do
          get review_path
          expect(response.body).to include("3")
        end
      end

      context "with a tag_id param" do
        let(:tag)   { create(:tag, name: "HSK 4") }
        let(:other) { create(:tag, name: "HSK 2") }

        let!(:in_tag_learning) do
          entry = create(:dictionary_entry).tap { |e| e.tags << tag }
          create(:user_learning, user: user, dictionary_entry: entry,
                 state: "learning", next_due: 1.day.ago, last_interval: 1)
        end

        before { user_learning.dictionary_entry.tags << other }

        it "only queues cards within that tag" do
          get review_path, params: { tag_id: tag.id }
          ls = LearningSession.last
          expect(ls.learning_session_cards.map(&:user_learning_id)).to eq([ in_tag_learning.id ])
        end

        it "excludes cards outside that tag" do
          get review_path, params: { tag_id: tag.id }
          ls = LearningSession.last
          expect(ls.learning_session_cards.map(&:user_learning_id)).not_to include(user_learning.id)
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

        it "does not create a LearningSession" do
          expect { get review_path }.not_to change(LearningSession, :count)
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

    context "when authenticated with no active session" do
      before { sign_in user }

      it "redirects to review start" do
        get review_card_path
        expect(response).to redirect_to(review_path)
      end
    end

    context "when authenticated with an active session" do
      before do
        sign_in user
        get review_path
      end

      it "returns 200" do
        get review_card_path
        expect(response).to have_http_status(:ok)
      end

      it "shows position and total" do
        get review_card_path
        expect(response.body).to include("1")
      end
    end
  end

  # -------------------------------------------------------------------------
  # GET /review/resume — resume an in-progress session
  # -------------------------------------------------------------------------
  describe "GET /review/resume" do
    context "when unauthenticated" do
      it "redirects to login" do
        get review_resume_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated with an in_progress session" do
      let!(:ls) do
        ls = create(:learning_session, user: user, state: "in_progress",
                    started_at: 10.minutes.ago, card_count: 3)
        create(:learning_session_card, learning_session: ls,
               user_learning: user_learning, position: 0,
               reviewed_at: 5.minutes.ago, ease: 3)
        create(:learning_session_card, learning_session: ls,
               user_learning: create(:user_learning, user: user), position: 1)
        create(:learning_session_card, learning_session: ls,
               user_learning: create(:user_learning, user: user), position: 2)
        ls
      end

      before { sign_in user }

      it "redirects to the card path" do
        get review_resume_path
        expect(response).to redirect_to(review_card_path)
      end

      it "sets the session cookie to the existing session" do
        get review_resume_path
        expect(session[:learning_session_id]).to eq(ls.id)
      end

      it "derives position from the number of already-reviewed cards" do
        get review_resume_path
        expect(session[:review_position]).to eq(1)
      end
    end

    context "when authenticated with no in_progress session" do
      before { sign_in user }

      it "redirects to review start" do
        get review_resume_path
        expect(response).to redirect_to(review_path)
      end
    end
  end

  # -------------------------------------------------------------------------
  # POST /review/abandon — abandon an in-progress session
  # -------------------------------------------------------------------------
  describe "POST /review/abandon" do
    context "when unauthenticated" do
      it "redirects to login" do
        post review_abandon_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated with an in_progress session" do
      let!(:ls) do
        create(:learning_session, user: user, state: "in_progress",
               started_at: 10.minutes.ago, card_count: 1)
      end

      before { sign_in user }

      it "marks the session as abandoned" do
        post review_abandon_path
        expect(ls.reload.state).to eq("abandoned")
      end

      it "redirects to review start" do
        post review_abandon_path
        expect(response).to redirect_to(review_path)
      end
    end

    context "when authenticated with no in_progress session" do
      before { sign_in user }

      it "redirects to review start" do
        post review_abandon_path
        expect(response).to redirect_to(review_path)
      end
    end
  end

  # -------------------------------------------------------------------------
  # POST /review/card — submit a card review
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

        it "records the ease on the LearningSessionCard" do
          post review_card_path, params: { ease: 3 }
          card = LearningSession.last.learning_session_cards.first
          expect(card.ease).to eq(3)
        end

        it "sets reviewed_at on the LearningSessionCard" do
          post review_card_path, params: { ease: 3 }
          card = LearningSession.last.learning_session_cards.first
          expect(card.reviewed_at).to be_present
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
        it "marks the LearningSession as completed" do
          post review_card_path, params: { ease: 3 }
          expect(LearningSession.last.state).to eq("completed")
        end

        it "sets completed_at" do
          post review_card_path, params: { ease: 3 }
          expect(LearningSession.last.completed_at).to be_present
        end

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

        before { get review_path } # rebuild queue with both cards

        it "redirects to the card path" do
          post review_card_path, params: { ease: 3 }
          expect(response).to redirect_to(review_card_path)
        end

        it "does not complete the session yet" do
          post review_card_path, params: { ease: 3 }
          expect(LearningSession.last.state).to eq("in_progress")
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

  # -------------------------------------------------------------------------
  # GET /review/history — session history
  # -------------------------------------------------------------------------
  describe "GET /review/history" do
    context "when unauthenticated" do
      it "redirects to login" do
        get review_history_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns 200" do
        get review_history_path
        expect(response).to have_http_status(:ok)
      end

      it "shows completed sessions" do
        create(:learning_session, user: user, state: "completed",
               started_at: 1.hour.ago, completed_at: 30.minutes.ago, card_count: 5)
        get review_history_path
        expect(response.body).to include("5")
      end

      it "does not show in_progress sessions" do
        create(:learning_session, user: user, state: "in_progress",
               started_at: 1.hour.ago, card_count: 3)
        get review_history_path
        expect(response.body).not_to include("in_progress")
      end
    end
  end
end
