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

      it "renders all four Trajectory tile labels" do
        get learn_progress_path
        expect(response.body).to include("Stable", "Recovering", "Chronic", "Stalled")
      end

      it "renders the Trajectory count for a classified word" do
        ul = create(:user_learning, user: user, state: "learning")
        create(:review_log, user_learning: ul, ease: 3)
        ul.update!(state: "mastered")

        get learn_progress_path
        doc = Nokogiri::HTML(response.body)
        stable_tile = doc.at_css('[data-trajectory-key="stable"]')
        expect(stable_tile.text).to include("1")
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

      def parsed
        JSON.parse(response.body)
      end

      def series(label)
        parsed["series"].find { |s| s["label"] == label }
      end

      it "returns JSON with labels and series keys" do
        get learn_progress_character_chart_data_path
        expect(response.content_type).to include("application/json")
        expect(parsed.keys).to contain_exactly("labels", "series")
      end

      it "returns two series: Established, Touched" do
        get learn_progress_character_chart_data_path
        expect(parsed["series"].map { |s| s["label"] }).to eq([ "Established", "Touched" ])
      end

      it "returns empty labels and series when nothing has been reviewed" do
        get learn_progress_character_chart_data_path
        expect(parsed["labels"]).to eq([])
        expect(parsed["series"]).to all(include("values" => []))
      end

      context "with mastered and touched words" do
        # A word graduating always accompanies at least one ReviewLog in the
        # real app -- matching that here rather than a bare state update.
        def graduate!(text:)
          ul = create(:user_learning, user: user, state: "learning", dictionary_entry: create(:dictionary_entry, text: text))
          create(:review_log, user_learning: ul, ease: 3)
          ul.update!(state: "mastered")
          ul
        end

        def touch!(text:)
          ul = create(:user_learning, user: user, state: "learning", dictionary_entry: create(:dictionary_entry, text: text))
          create(:review_log, user_learning: ul, ease: 1)
          ul
        end

        it "deduplicates characters across words" do
          graduate!(text: "你好") # 你, 好
          graduate!(text: "你")   # 你 already established

          get learn_progress_character_chart_data_path
          expect(series("Established")["values"].last).to eq(2)
        end

        it "counts a touched-but-not-established character in Touched" do
          touch!(text: "学")

          get learn_progress_character_chart_data_path
          expect(series("Touched")["values"].last).to eq(1)
          expect(series("Established")["values"].last).to eq(0)
        end

        it "prioritises Established over Touched for a character in both an established and a touched word" do
          graduate!(text: "你")
          touch!(text: "你好") # 你 already established; 好 merely touched

          get learn_progress_character_chart_data_path
          expect(series("Established")["values"].last).to eq(1)
          expect(series("Touched")["values"].last).to eq(1)
        end

        it "only returns data for the current user" do
          other_user = create(:user)
          other_entry = create(:dictionary_entry, text: "学")
          other_ul = create(:user_learning, user: other_user, state: "learning", dictionary_entry: other_entry)
          create(:review_log, user_learning: other_ul, ease: 3)
          other_ul.update!(state: "mastered")

          graduate!(text: "你")

          get learn_progress_character_chart_data_path
          expect(series("Established")["values"].last).to eq(1)
        end

        it "keeps a lapsed word's characters Established (does not retroactively rewrite history)" do
          lapsed = graduate!(text: "学")
          lapsed.update!(state: "learning")

          get learn_progress_character_chart_data_path
          expect(series("Established")["values"].last).to eq(1)
        end

        it "still counts an established word's characters even with no review history" do
          # Not reachable via any current code path in this app --
          # first_mastered_at can only be set alongside review history --
          # but Mastery::Coverage treats first_mastered_at as authoritative
          # regardless of review count, so this chart shouldn't silently
          # disagree if that ever drifts (e.g. reviews deleted after the
          # fact, a future import format). See #391 review discussion.
          ghost = create(:user_learning, user: user, dictionary_entry: create(:dictionary_entry, text: "谢"), state: "learning")
          ghost.update_column(:first_mastered_at, 3.days.ago)

          get learn_progress_character_chart_data_path
          expect(series("Established")["values"].last).to eq(1)
        end

        it "keeps the query count bounded regardless of word count" do
          graduate!(text: "你")
          count_with_few = count_queries { get learn_progress_character_chart_data_path }

          15.times { |i| touch!(text: "字#{i}") }

          count_with_many = count_queries { get learn_progress_character_chart_data_path }
          expect(count_with_many).to eq(count_with_few)
        end
      end
    end
  end

  describe "GET /learn/progress/coverage_chart_data" do
    context "when unauthenticated" do
      it "redirects to the login page" do
        get learn_progress_coverage_chart_data_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      def parsed
        JSON.parse(response.body)
      end

      it "returns JSON with labels and series keys" do
        get learn_progress_coverage_chart_data_path
        expect(response.content_type).to include("application/json")
        expect(parsed.keys).to contain_exactly("labels", "series")
      end

      it "returns empty labels and series when nothing has been reviewed" do
        get learn_progress_coverage_chart_data_path
        expect(parsed["labels"]).to eq([])
        expect(parsed["series"]).to all(include("values" => []))
      end

      context "with words at each coverage tier" do
        let(:threshold) { Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT }

        let!(:established_word) do
          # Graduation always accompanies at least one ReviewLog in the real
          # app (ReviewController#submit creates both together) -- matching
          # that here, rather than a bare state update with zero reviews.
          ul = create(:user_learning, user: user, state: "learning")
          create(:review_log, user_learning: ul, ease: 3)
          ul.update!(state: "mastered")
          ul
        end
        let!(:developing_word) do
          ul = create(:user_learning, user: user, state: "learning")
          threshold.times { create(:review_log, user_learning: ul, ease: 1) }
          ul
        end
        let!(:emerging_word) do
          ul = create(:user_learning, user: user, state: "learning")
          create(:review_log, user_learning: ul, ease: 1)
          ul
        end

        it "returns three series in Established, Developing, Emerging order" do
          get learn_progress_coverage_chart_data_path
          expect(parsed["series"].map { |s| s["label"] }).to eq([ "Established", "Developing", "Emerging" ])
        end

        it "counts each word in its own tier at the final bucket" do
          get learn_progress_coverage_chart_data_path
          series = parsed["series"].index_by { |s| s["label"] }
          expect(series["Established"]["values"].last).to eq(1)
          expect(series["Developing"]["values"].last).to eq(1)
          expect(series["Emerging"]["values"].last).to eq(1)
        end

        it "keeps a lapsed word in Established (durable, not retroactively rewritten)" do
          established_word.update!(state: "learning")

          get learn_progress_coverage_chart_data_path
          series = parsed["series"].index_by { |s| s["label"] }
          expect(series["Established"]["values"].last).to eq(1)
        end

        it "still counts an established word even with no review history" do
          # Not reachable via any current code path in this app --
          # first_mastered_at can only be set alongside review history --
          # but Mastery::Coverage treats first_mastered_at as authoritative
          # regardless of review count, so this chart shouldn't silently
          # disagree if that ever drifts. See #391 review discussion.
          ghost = create(:user_learning, user: user, state: "learning")
          ghost.update_column(:first_mastered_at, 3.days.ago)

          get learn_progress_coverage_chart_data_path
          series = parsed["series"].index_by { |s| s["label"] }
          expect(series["Established"]["values"].last).to eq(2)
        end

        it "only returns data for the current user" do
          other_user = create(:user)
          other_ul = create(:user_learning, user: other_user, state: "learning")
          create(:review_log, user_learning: other_ul, ease: 1)

          get learn_progress_coverage_chart_data_path
          series = parsed["series"].index_by { |s| s["label"] }
          expect(series["Emerging"]["values"].last).to eq(1)
        end

        it "keeps the query count bounded regardless of word count" do
          count_with_few = count_queries { get learn_progress_coverage_chart_data_path }

          15.times do
            ul = create(:user_learning, user: user, state: "learning", dictionary_entry: create(:dictionary_entry))
            create(:review_log, user_learning: ul, ease: 1)
          end

          count_with_many = count_queries { get learn_progress_coverage_chart_data_path }
          expect(count_with_many).to eq(count_with_few)
        end
      end
    end
  end
end
