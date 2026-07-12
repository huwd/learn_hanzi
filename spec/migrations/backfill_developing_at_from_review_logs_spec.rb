require 'rails_helper'
require Rails.root.join('db/migrate/20260712125908_backfill_developing_at_from_review_logs')

# Tests for the BackfillDevelopingAtFromReviewLogs data migration.
#
# developing_at marks the moment review_count first reached
# Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT while the word
# had not yet graduated. See #391.
RSpec.describe "BackfillDevelopingAtFromReviewLogs migration" do
  let(:migration) { BackfillDevelopingAtFromReviewLogs.new }
  let(:user)      { create(:user) }
  let(:threshold) { Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT }

  # ReviewLog's own after_create callback (see app/models/review_log.rb)
  # already sets developing_at going forward, and fires on every factory
  # `create(:review_log, ...)` below too -- these tests build raw review
  # history directly, the way an Anki import would, without also replaying
  # user_learning.update!(state: ...) the way ReviewController#submit does.
  # Reset developing_at after setup so each test verifies the MIGRATION's
  # own replay logic in isolation from that live callback's side effects.
  def reset_developing_at(ul)
    ul.update_column(:developing_at, nil)
  end

  describe "#up" do
    it "sets developing_at at the threshold-th review when not yet graduated" do
      ul = create(:user_learning, user: user, state: "learning")
      (threshold - 1).times { |i| create(:review_log, user_learning: ul, ease: 1, created_at: (10 - i).days.ago) }
      threshold_log = create(:review_log, user_learning: ul, ease: 1, created_at: 1.day.ago)
      reset_developing_at(ul)

      migration.up

      expect(ul.reload.developing_at).to be_within(1.second).of(threshold_log.created_at)
    end

    it "does not set developing_at if the word graduates before the threshold" do
      ul = create(:user_learning, user: user, state: "mastered")
      create(:review_log, user_learning: ul, ease: 3, created_at: 3.days.ago)
      create(:review_log, user_learning: ul, ease: 3, created_at: 2.days.ago) # graduates here (review 2)
      (threshold - 2).times { |i| create(:review_log, user_learning: ul, ease: 3, created_at: (1.days.ago - i.hours)) }
      reset_developing_at(ul)

      migration.up

      expect(ul.reload.developing_at).to be_nil
    end

    it "does not set developing_at at the threshold-th review if it graduates there" do
      ul = create(:user_learning, user: user, state: "mastered")
      create(:review_log, user_learning: ul, ease: 1, created_at: 5.days.ago)
      (threshold - 2).times { |i| create(:review_log, user_learning: ul, ease: 1, created_at: (4 - i).days.ago) }
      create(:review_log, user_learning: ul, ease: 3, created_at: 1.day.ago) # graduates at review `threshold`
      reset_developing_at(ul)

      migration.up

      expect(ul.reload.developing_at).to be_nil
    end

    it "does not set developing_at if the word graduated earlier and has since relapsed" do
      # Graduates on review 2, relapses on review 3, keeps accumulating
      # reviews without regraduating -- still Established (durable), never
      # Developing, even though it's currently "learning" at review threshold.
      ul = create(:user_learning, user: user, state: "learning")
      create(:review_log, user_learning: ul, ease: 3, created_at: 6.days.ago)
      create(:review_log, user_learning: ul, ease: 3, created_at: 5.days.ago) # graduates (review 2)
      create(:review_log, user_learning: ul, ease: 1, created_at: 4.days.ago) # relapses
      (threshold - 3).times { |i| create(:review_log, user_learning: ul, ease: 1, created_at: (3 - i).days.ago) }
      reset_developing_at(ul)

      migration.up

      expect(ul.reload.developing_at).to be_nil
    end

    it "leaves developing_at nil for a word with fewer reviews than the threshold" do
      ul = create(:user_learning, user: user, state: "learning")
      (threshold - 1).times { |i| create(:review_log, user_learning: ul, ease: 1, created_at: (2 - i).days.ago) }
      reset_developing_at(ul)

      migration.up

      expect(ul.reload.developing_at).to be_nil
    end
  end
end
