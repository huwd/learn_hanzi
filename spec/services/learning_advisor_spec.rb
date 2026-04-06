require "rails_helper"

RSpec.describe LearningAdvisor do
  let(:user) { create(:user) }

  # Helper: create a user_learning associated with this user
  def learning(state: "learning", next_due: 7.days.from_now)
    create(:user_learning, user: user, state: state, next_due: next_due)
  end

  # Helper: create a review_log for a user_learning
  def log_for(ul, ease: 3, created_at: Time.current)
    create(:review_log, user_learning: ul, ease: ease, created_at: created_at)
  end

  describe ".classify" do
    subject(:result) { described_class.classify(user: user) }

    # -----------------------------------------------------------------------
    # :empty
    # -----------------------------------------------------------------------
    context "when the user has no learnings" do
      it "returns :empty profile" do
        expect(result.profile).to eq(:empty)
      end

      it "returns positive recommended_size" do
        expect(result.recommended_size).to be > 0
      end

      it "does not raise" do
        expect { result }.not_to raise_error
      end
    end

    # -----------------------------------------------------------------------
    # :lapsed — has learnings but never reviewed
    # -----------------------------------------------------------------------
    context "when the user has learnings but no review logs" do
      before { learning(state: "new") }

      it "returns :lapsed profile" do
        expect(result.profile).to eq(:lapsed)
      end

      it "recommends new_cap 0" do
        expect(result.recommended_new_cap).to eq(0)
      end
    end

    # -----------------------------------------------------------------------
    # :lapsed — last review > 7 days ago
    # -----------------------------------------------------------------------
    context "when the last review was 10 days ago" do
      before do
        ul = learning
        log_for(ul, created_at: 10.days.ago)
      end

      it "returns :lapsed profile" do
        expect(result.profile).to eq(:lapsed)
      end

      it "recommends a small session size" do
        expect(result.recommended_size).to be <= 15
      end

      it "recommends new_cap 0" do
        expect(result.recommended_new_cap).to eq(0)
      end
    end

    # -----------------------------------------------------------------------
    # :catching_up — backlog > avg daily, still active
    # -----------------------------------------------------------------------
    context "when there is a backlog and the user reviewed recently" do
      before do
        # 5 overdue learning cards
        5.times { learning(state: "learning", next_due: 2.days.ago) }

        # Only 1 review log in the last 14 days (avg = ~0.07/day → backlog ratio >> 1)
        ul = learning(state: "learning", next_due: 1.day.from_now)
        log_for(ul, created_at: 2.days.ago)
      end

      it "returns :catching_up profile" do
        expect(result.profile).to eq(:catching_up)
      end

      it "recommends new_cap 0" do
        expect(result.recommended_new_cap).to eq(0)
      end
    end

    # -----------------------------------------------------------------------
    # :overloaded — high new card rate + backlog
    # -----------------------------------------------------------------------
    context "when the user is adding many new cards and has a backlog" do
      before do
        # 182 cards each with a first review in the last 7 days → new_7day_avg ≈ 26/day (> 25 threshold)
        # All are overdue, creating a backlog_ratio >> 1
        entries = create_list(:dictionary_entry, 182)
        entries.each_with_index do |entry, i|
          ul = create(:user_learning, user: user, dictionary_entry: entry,
                      state: "learning", next_due: 2.days.ago)
          create(:review_log, user_learning: ul, ease: 3,
                 created_at: (i % 7).days.ago + 1.hour)
        end
      end

      it "returns :overloaded profile" do
        expect(result.profile).to eq(:overloaded)
      end

      it "recommends a reduced new_cap" do
        expect(result.recommended_new_cap).to be <= 10
      end
    end

    # -----------------------------------------------------------------------
    # :cramming — bursty session pattern
    # -----------------------------------------------------------------------
    context "when the user crams in one day with no other sessions" do
      before do
        ul = learning
        # 60 reviews on a single day, no other days in the last 14
        60.times { log_for(ul, ease: 3, created_at: 5.days.ago + rand(0..3600).seconds) }
      end

      it "returns :cramming profile" do
        expect(result.profile).to eq(:cramming)
      end

      it "recommends a small session size" do
        expect(result.recommended_size).to be <= 15
      end
    end

    # -----------------------------------------------------------------------
    # :maintenance — highly mastered, low backlog, recent activity
    # -----------------------------------------------------------------------
    context "when most cards are mastered and backlog is very small" do
      before do
        # 10 mastered cards, reviewed recently, no backlog
        10.times do
          ul = learning(state: "mastered", next_due: 7.days.from_now)
          # Spread reviews across the last 14 days
          (1..14).each { |d| log_for(ul, ease: 4, created_at: d.days.ago) }
        end
      end

      it "returns :maintenance profile" do
        expect(result.profile).to eq(:maintenance)
      end
    end

    # -----------------------------------------------------------------------
    # :healthy — default active case
    # -----------------------------------------------------------------------
    context "when the user is reviewing regularly with no backlog" do
      before do
        # Use a learning card so mastery_pct stays below 80% (avoids :maintenance)
        ul = learning(state: "learning", next_due: 5.days.from_now)
        # Daily reviews for the last 3 days
        3.times { |d| log_for(ul, ease: 3, created_at: d.days.ago + 1.hour) }
      end

      it "returns :healthy profile" do
        expect(result.profile).to eq(:healthy)
      end

      it "returns standard size" do
        expect(result.recommended_size).to eq(20)
      end
    end

    # -----------------------------------------------------------------------
    # leech_warning overlay
    # -----------------------------------------------------------------------
    context "leech warning" do
      context "when a card has been rated 1 or 2 four or more times" do
        before do
          ul = learning
          4.times { log_for(ul, ease: 1, created_at: rand(1..30).days.ago) }
          # Also add a recent review so user is not classified as lapsed
          log_for(ul, ease: 3, created_at: 1.day.ago)
        end

        it "sets leech_warning to true" do
          expect(result.leech_warning).to be true
        end
      end

      context "when no card has enough low-ease reviews" do
        before do
          ul = learning
          3.times { log_for(ul, ease: 1, created_at: rand(1..10).days.ago) }
          log_for(ul, ease: 3, created_at: 1.day.ago)
        end

        it "sets leech_warning to false" do
          expect(result.leech_warning).to be false
        end
      end
    end

    # -----------------------------------------------------------------------
    # first_90_days overlay
    # -----------------------------------------------------------------------
    context "first_90_days overlay" do
      context "when first review was within 90 days" do
        before do
          ul = learning
          log_for(ul, created_at: 30.days.ago)
        end

        it "sets first_90_days to true" do
          expect(result.first_90_days).to be true
        end
      end

      context "when first review was more than 90 days ago" do
        before do
          ul = learning
          log_for(ul, created_at: 100.days.ago)
          # Also a recent review so user is not lapsed
          log_for(ul, created_at: 1.day.ago)
        end

        it "sets first_90_days to false" do
          expect(result.first_90_days).to be false
        end
      end

      context "when user has no review logs" do
        before { learning }

        it "sets first_90_days to true" do
          expect(result.first_90_days).to be true
        end
      end
    end

    # -----------------------------------------------------------------------
    # result structure
    # -----------------------------------------------------------------------
    describe "result structure" do
      before { learning }

      it "exposes a narrative string" do
        expect(result.narrative).to be_a(String).and be_present
      end

      it "exposes signals hash" do
        expect(result.signals).to be_a(Hash)
        expect(result.signals).to include(:total_count, :overdue_count, :avg_daily, :backlog_ratio)
      end

      it "exposes recommended_size and recommended_new_cap" do
        expect(result.recommended_size).to be_a(Integer).and be_positive
        expect(result.recommended_new_cap).to be_a(Integer).and be >= 0
      end
    end
  end
end
