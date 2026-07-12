require 'rails_helper'
require Rails.root.join('db/migrate/20260712120454_recompute_first_mastered_at_with_stable_replay_order')

# Tests for the RecomputeFirstMasteredAtWithStableReplayOrder migration.
#
# Corrects first_mastered_at values computed by the original backfill
# (20260712102217), which ordered review_logs by created_at alone --
# nondeterministic when logs share it, as batch-imported Anki logs
# commonly do. See #391 PR #395 review discussion.
RSpec.describe "RecomputeFirstMasteredAtWithStableReplayOrder migration" do
  let(:migration) { RecomputeFirstMasteredAtWithStableReplayOrder.new }
  let(:user)      { create(:user) }

  describe "#up" do
    it "recomputes first_mastered_at ordered by time when created_at ties" do
      # Two logs share created_at (batch A, as a batch Anki import would),
      # inserted in reverse-chronological (by `time`) order so a naive
      # created_at/id fallback replays them backwards. In true time order
      # batch A never crosses into mastered (new->learning->learning); in
      # naive insertion order it wrongly does (new->learning->mastered),
      # producing a different (and earlier, wrong) first_mastered_at than
      # the real graduation in the distinctly-timestamped batch B below.
      ul = create(:user_learning, user: user, state: "mastered", first_mastered_at: nil)
      batch_a_created_at = 2.days.ago
      create(:review_log, user_learning: ul, ease: 1, time: 2000, created_at: batch_a_created_at) # true order: 2nd
      create(:review_log, user_learning: ul, ease: 3, time: 1000, created_at: batch_a_created_at) # true order: 1st
      graduating_log = create(:review_log, user_learning: ul, ease: 3, created_at: 1.day.ago)

      migration.up

      expect(ul.reload.first_mastered_at).to be_within(1.second).of(graduating_log.created_at)
    end

    it "leaves an already-correct first_mastered_at unchanged" do
      ul = create(:user_learning, user: user, state: "mastered")
      create(:review_log, user_learning: ul, ease: 3, created_at: 2.days.ago)
      graduating_log = create(:review_log, user_learning: ul, ease: 3, created_at: 1.day.ago)

      migration.up

      expect(ul.reload.first_mastered_at).to be_within(1.second).of(graduating_log.created_at)
    end

    it "leaves first_mastered_at nil for a card that never graduated" do
      ul = create(:user_learning, user: user, state: "learning")
      create(:review_log, user_learning: ul, ease: 1, created_at: 2.days.ago)

      migration.up

      expect(ul.reload.first_mastered_at).to be_nil
    end
  end
end
