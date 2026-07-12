require 'rails_helper'

RSpec.describe Mastery::MilestoneReplay do
  let(:user)         { create(:user) }
  let(:user_learning) { create(:user_learning, user: user, state: "learning") }
  let(:threshold)    { Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT }

  describe ".call" do
    it "returns all-nil/zero for no review history" do
      result = described_class.call([])

      expect(result.first_mastered_at).to be_nil
      expect(result.graduation_count).to eq(0)
      expect(result.developing_at).to be_nil
    end

    it "sets first_mastered_at and graduation_count on graduation" do
      create(:review_log, user_learning: user_learning, ease: 3, created_at: 2.days.ago)
      graduating_log = create(:review_log, user_learning: user_learning, ease: 3, created_at: 1.day.ago)

      result = described_class.call(user_learning.review_logs)

      expect(result.first_mastered_at).to be_within(1.second).of(graduating_log.created_at)
      expect(result.graduation_count).to eq(1)
      expect(result.developing_at).to be_nil
    end

    it "sets developing_at when review_count reaches the threshold without graduating" do
      (threshold - 1).times { |i| create(:review_log, user_learning: user_learning, ease: 1, created_at: (10 - i).days.ago) }
      threshold_log = create(:review_log, user_learning: user_learning, ease: 1, created_at: 1.day.ago)

      result = described_class.call(user_learning.review_logs)

      expect(result.developing_at).to be_within(1.second).of(threshold_log.created_at)
      expect(result.first_mastered_at).to be_nil
      expect(result.graduation_count).to eq(0)
    end

    it "does not set developing_at when the word graduates at the threshold review" do
      create(:review_log, user_learning: user_learning, ease: 1, created_at: 5.days.ago)
      (threshold - 2).times { |i| create(:review_log, user_learning: user_learning, ease: 1, created_at: (4 - i).days.ago) }
      create(:review_log, user_learning: user_learning, ease: 3, created_at: 1.day.ago) # graduates at review `threshold`

      result = described_class.call(user_learning.review_logs)

      expect(result.developing_at).to be_nil
      expect(result.first_mastered_at).to be_present
    end

    it "counts every graduation but keeps first_mastered_at at the first one" do
      create(:review_log, user_learning: user_learning, ease: 3, created_at: 12.days.ago) # new -> learning
      first_graduation = create(:review_log, user_learning: user_learning, ease: 3, created_at: 10.days.ago) # 1st graduation
      create(:review_log, user_learning: user_learning, ease: 1, created_at: 5.days.ago) # relapse
      create(:review_log, user_learning: user_learning, ease: 3, created_at: 1.day.ago) # 2nd graduation

      result = described_class.call(user_learning.review_logs)

      expect(result.graduation_count).to eq(2)
      expect(result.first_mastered_at).to be_within(1.second).of(first_graduation.created_at)
    end

    it "orders by (created_at, time, id) when created_at ties, as with a batch import" do
      # Same construction as the ordering-regression tests for the backfill
      # migrations: reverse-chronological insertion order under a shared
      # created_at, distinguished only by `time`.
      same_created_at = 1.day.ago
      create(:review_log, user_learning: user_learning, ease: 3, time: 4000, created_at: same_created_at)
      create(:review_log, user_learning: user_learning, ease: 1, time: 3000, created_at: same_created_at)
      create(:review_log, user_learning: user_learning, ease: 3, time: 2000, created_at: same_created_at)
      create(:review_log, user_learning: user_learning, ease: 1, time: 1000, created_at: same_created_at)

      result = described_class.call(user_learning.review_logs)

      # Correct time order [1, 3, 1, 3]: new->learning->mastered->learning->mastered = 2 graduations.
      expect(result.graduation_count).to eq(2)
    end
  end
end
