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
  end
end
