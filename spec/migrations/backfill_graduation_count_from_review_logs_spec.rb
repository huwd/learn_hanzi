require 'rails_helper'
require Rails.root.join('db/migrate/20260712104951_backfill_graduation_count_from_review_logs')

# Tests for the BackfillGraduationCountFromReviewLogs data migration.
#
# Counts every learning -> mastered crossing in a word's review history,
# independent of the current (possibly lapsed) state. Feeds
# Mastery::Trajectory's Chronic classification. See #391.
RSpec.describe "BackfillGraduationCountFromReviewLogs migration" do
  let(:migration) { BackfillGraduationCountFromReviewLogs.new }
  let(:user)      { create(:user) }

  describe "#up" do
    it "counts a single graduation" do
      ul = create(:user_learning, user: user, state: "mastered")
      create(:review_log, user_learning: ul, ease: 3, created_at: 2.days.ago)
      create(:review_log, user_learning: ul, ease: 3, created_at: 1.day.ago)

      migration.up

      expect(ul.reload.graduation_count).to eq(1)
    end

    it "counts multiple graduations across relapses" do
      ul = create(:user_learning, user: user, state: "mastered")
      create(:review_log, user_learning: ul, ease: 3, created_at: 10.days.ago) # -> learning
      create(:review_log, user_learning: ul, ease: 3, created_at: 9.days.ago)  # -> mastered (1st)
      create(:review_log, user_learning: ul, ease: 1, created_at: 5.days.ago)  # -> learning
      create(:review_log, user_learning: ul, ease: 3, created_at: 1.day.ago)   # -> mastered (2nd)

      migration.up

      expect(ul.reload.graduation_count).to eq(2)
    end

    it "leaves graduation_count at zero for a word that never graduated" do
      ul = create(:user_learning, user: user, state: "learning")
      create(:review_log, user_learning: ul, ease: 1, created_at: 2.days.ago)
      create(:review_log, user_learning: ul, ease: 2, created_at: 1.day.ago)

      migration.up

      expect(ul.reload.graduation_count).to eq(0)
    end

    it "leaves graduation_count at zero for a word with no review history" do
      ul = create(:user_learning, user: user, state: "new")

      migration.up

      expect(ul.reload.graduation_count).to eq(0)
    end

    it "orders by time (not insertion order) when created_at ties, as with a batch Anki import" do
      # All four logs share created_at, as a batch-imported Anki import
      # would. Inserted in reverse chronological order (by `time`) so that
      # falling back to created_at/id order alone would replay them
      # backwards and silently under-count graduations.
      ul = create(:user_learning, user: user, state: "learning")
      same_created_at = 1.day.ago
      create(:review_log, user_learning: ul, ease: 3, time: 4000, created_at: same_created_at) # true order: 4th
      create(:review_log, user_learning: ul, ease: 1, time: 3000, created_at: same_created_at) # true order: 3rd
      create(:review_log, user_learning: ul, ease: 3, time: 2000, created_at: same_created_at) # true order: 2nd
      create(:review_log, user_learning: ul, ease: 1, time: 1000, created_at: same_created_at) # true order: 1st

      migration.up

      # Correct time order [1, 3, 1, 3]: new->learning->mastered->learning->mastered = 2 graduations.
      # Naive created_at/insertion order [3, 1, 3, 1]: new->learning->learning->mastered->learning = 1.
      expect(ul.reload.graduation_count).to eq(2)
    end
  end
end
