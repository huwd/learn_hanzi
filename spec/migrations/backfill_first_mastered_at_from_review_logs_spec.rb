require 'rails_helper'
require Rails.root.join('db/migrate/20260712102217_backfill_first_mastered_at_from_review_logs')

# Tests for the BackfillFirstMasteredAtFromReviewLogs data migration.
#
# Replays each UserLearning's review_logs through the same new/learning/
# mastered transition table as SpacedRepetition::SM2#calculated_state to
# find the first learning -> mastered crossing, independent of the current
# (possibly lapsed) state or the live mastered_at column. See #391.
RSpec.describe "BackfillFirstMasteredAtFromReviewLogs migration" do
  let(:migration) { BackfillFirstMasteredAtFromReviewLogs.new }
  let(:user)      { create(:user) }

  describe "#up" do
    it "sets first_mastered_at to the timestamp of the graduating review" do
      ul = create(:user_learning, user: user, state: "mastered")
      create(:review_log, user_learning: ul, ease: 3, created_at: 3.days.ago)
      graduating_log = create(:review_log, user_learning: ul, ease: 3, created_at: 2.days.ago)

      migration.up

      expect(ul.reload.first_mastered_at).to be_within(1.second).of(graduating_log.created_at)
    end

    it "recovers first_mastered_at for a card that has since lapsed" do
      # Graduated on the second review, relapsed on the third — mastered_at
      # would already have been nulled by the live callback, so this is the
      # only remaining source of truth for "was this ever mastered".
      ul = create(:user_learning, user: user, state: "learning", mastered_at: nil)
      create(:review_log, user_learning: ul, ease: 3, created_at: 5.days.ago)
      graduating_log = create(:review_log, user_learning: ul, ease: 4, created_at: 4.days.ago)
      create(:review_log, user_learning: ul, ease: 1, created_at: 1.day.ago)

      migration.up

      expect(ul.reload.first_mastered_at).to be_within(1.second).of(graduating_log.created_at)
    end

    it "keeps the earliest graduation when a card graduates, relapses, and re-graduates" do
      ul = create(:user_learning, user: user, state: "mastered")
      create(:review_log, user_learning: ul, ease: 3, created_at: 10.days.ago)
      first_graduation = create(:review_log, user_learning: ul, ease: 3, created_at: 9.days.ago)
      create(:review_log, user_learning: ul, ease: 1, created_at: 5.days.ago)
      create(:review_log, user_learning: ul, ease: 3, created_at: 1.day.ago)

      migration.up

      expect(ul.reload.first_mastered_at).to be_within(1.second).of(first_graduation.created_at)
    end

    it "leaves first_mastered_at nil for a card that never graduated" do
      ul = create(:user_learning, user: user, state: "learning")
      create(:review_log, user_learning: ul, ease: 1, created_at: 2.days.ago)
      create(:review_log, user_learning: ul, ease: 2, created_at: 1.day.ago)

      migration.up

      expect(ul.reload.first_mastered_at).to be_nil
    end

    it "leaves first_mastered_at nil for a card with no review history" do
      ul = create(:user_learning, user: user, state: "new")

      migration.up

      expect(ul.reload.first_mastered_at).to be_nil
    end
  end
end
