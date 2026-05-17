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

  describe "GET /learn/progress/character_chart_data" do
    context "when unauthenticated" do
      it "redirects to the login page" do
        get learn_progress_character_chart_data_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns JSON" do
        get learn_progress_character_chart_data_path
        expect(response.content_type).to include("application/json")
      end

      context "with mastered words" do
        let(:entry_a) { create(:dictionary_entry, text: "你好") }
        let(:entry_b) { create(:dictionary_entry, text: "你") }

        before do
          create(:user_learning, user: user, state: "mastered",
                 dictionary_entry: entry_a, mastered_at: 2.days.ago)
          create(:user_learning, user: user, state: "mastered",
                 dictionary_entry: entry_b, mastered_at: 1.day.ago)
        end

        def parsed
          JSON.parse(response.body)
        end

        it "returns labels and series" do
          get learn_progress_character_chart_data_path
          expect(parsed.keys).to contain_exactly("labels", "series")
        end

        it "deduplicates characters across words" do
          get learn_progress_character_chart_data_path
          values = parsed["series"].first["values"]
          # 你好 = 你, 好 (2 chars on day 1); 你 already counted → only 好 is new
          # Total should be 2 unique characters, not 3
          expect(values.last).to eq(2)
        end

        it "attributes a character to the earliest mastered word" do
          get learn_progress_character_chart_data_path
          # 你 appears in 你好 (mastered 2 days ago), so it's counted on that date
          values = parsed["series"].first["values"]
          expect(values.first).to eq(2)
        end

        it "only returns data for the current user" do
          other_user = create(:user)
          other_entry = create(:dictionary_entry, text: "学")
          create(:user_learning, user: other_user, state: "mastered",
                 dictionary_entry: other_entry, mastered_at: 1.day.ago)

          get learn_progress_character_chart_data_path
          expect(parsed["series"].first["values"].last).to eq(2)
        end
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

      it "returns labels and series keys" do
        get learn_progress_chart_data_path
        data = JSON.parse(response.body)
        expect(data.keys).to contain_exactly("labels", "series")
      end

      context "with user learnings and review logs" do
        let!(:mastered_card) do
          ul = create(:user_learning, user: user, state: "mastered", mastered_at: 1.day.ago)
          create(:review_log, user_learning: ul, created_at: 3.days.ago)
          ul
        end
        let!(:learning_card) do
          ul = create(:user_learning, user: user, state: "learning")
          create(:review_log, user_learning: ul, created_at: 2.days.ago)
          ul
        end

        def parsed
          JSON.parse(response.body)
        end

        it "returns labels and series keys" do
          get learn_progress_chart_data_path
          expect(parsed.keys).to contain_exactly("labels", "series")
        end

        it "returns labels in ascending chronological order" do
          get learn_progress_chart_data_path
          expect(parsed["labels"]).to eq(parsed["labels"].sort)
        end

        it "returns two series (Mastered and In progress)" do
          get learn_progress_chart_data_path
          labels = parsed["series"].map { |s| s["label"] }
          expect(labels).to contain_exactly("Mastered", "In progress")
        end

        it "accumulates mastered count cumulatively" do
          get learn_progress_chart_data_path
          mastered = parsed["series"].find { |s| s["label"] == "Mastered" }
          expect(mastered["values"].last).to eq(1)
        end

        it "counts in_progress from first review minus mastered" do
          get learn_progress_chart_data_path
          in_progress = parsed["series"].find { |s| s["label"] == "In progress" }
          # 2 cards reviewed, 1 mastered → 1 still in progress
          expect(in_progress["values"].last).to eq(1)
        end

        it "in_progress values are never negative" do
          get learn_progress_chart_data_path
          in_progress = parsed["series"].find { |s| s["label"] == "In progress" }
          expect(in_progress["values"]).to all(be >= 0)
        end

        it "only returns data for the current user" do
          other_user = create(:user)
          other_ul = create(:user_learning, user: other_user, state: "mastered",
                            mastered_at: 1.day.ago)
          create(:review_log, user_learning: other_ul, created_at: 1.day.ago)

          get learn_progress_chart_data_path
          mastered = parsed["series"].find { |s| s["label"] == "Mastered" }
          expect(mastered["values"].last).to eq(1)
        end
      end
    end
  end
end
