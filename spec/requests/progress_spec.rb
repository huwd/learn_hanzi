require 'rails_helper'

RSpec.describe "Progress", type: :request do
  let(:user) { create(:user) }

  describe "GET /learn/progress" do
    context "when unauthenticated" do
      it "redirects to the login page" do
        get learn_progress_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns a successful response" do
        get learn_progress_path
        expect(response).to have_http_status(:success)
      end

      it "renders the progress heading" do
        get learn_progress_path
        expect(response.body).to include("Learning Progress")
      end
    end
  end

  describe "GET /learn/progress/chart_data" do
    context "when unauthenticated" do
      it "redirects to the login page" do
        get learn_progress_chart_data_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns JSON" do
        get learn_progress_chart_data_path
        expect(response.content_type).to include("application/json")
      end

      it "returns an array" do
        get learn_progress_chart_data_path
        data = JSON.parse(response.body)
        expect(data).to be_an(Array)
      end

      context "with user learnings" do
        let!(:mastered_old) do
          create(:user_learning, user: user, state: "mastered",
                 created_at: 10.days.ago, mastered_at: 5.days.ago)
        end
        let!(:mastered_recent) do
          create(:user_learning, user: user, state: "mastered",
                 created_at: 3.days.ago, mastered_at: 1.day.ago)
        end
        let!(:in_learning) do
          create(:user_learning, user: user, state: "learning",
                 created_at: 2.days.ago)
        end

        it "returns data points with required keys" do
          get learn_progress_chart_data_path
          data = JSON.parse(response.body)
          expect(data.first.keys).to contain_exactly("date", "seen", "mastered", "learning")
        end

        it "returns dates in ascending chronological order" do
          get learn_progress_chart_data_path
          dates = JSON.parse(response.body).map { |d| d["date"] }
          expect(dates).to eq(dates.sort)
        end

        it "accumulates seen count cumulatively" do
          get learn_progress_chart_data_path
          data = JSON.parse(response.body)
          last = data.last
          expect(last["seen"]).to eq(3)
        end

        it "accumulates mastered count cumulatively" do
          get learn_progress_chart_data_path
          data = JSON.parse(response.body)
          last = data.last
          expect(last["mastered"]).to eq(2)
        end

        it "derives learning as seen minus mastered" do
          get learn_progress_chart_data_path
          data = JSON.parse(response.body)
          last = data.last
          expect(last["learning"]).to eq(last["seen"] - last["mastered"])
        end

        it "only returns data for the current user" do
          other_user = create(:user)
          create(:user_learning, user: other_user, state: "mastered",
                 created_at: 1.day.ago, mastered_at: 1.day.ago)

          get learn_progress_chart_data_path
          data = JSON.parse(response.body)
          expect(data.last["seen"]).to eq(3)
        end
      end
    end
  end
end
