class RecomputeFirstMasteredAtWithStableReplayOrder < ActiveRecord::Migration[8.1]
  # BackfillFirstMasteredAtFromReviewLogs (20260712102217, already merged
  # and deployed) replayed review_logs ordered by created_at alone. That's
  # not a stable order when logs share created_at, which batch-imported
  # Anki logs commonly do (confirmed against a real export: ~15% of words
  # have at least one such tie). Recompute with the corrected order —
  # created_at, then the Anki epoch-ms `time`, then `id` as a final
  # tiebreaker — same as BackfillGraduationCountFromReviewLogs
  # (20260712104951). See #391 PR #395 review discussion.
  #
  # Measured impact on the real dataset this was checked against: 2 of
  # 5,493 words had a different first_mastered_at under the old ordering;
  # none had their presence (nil vs set) flip. This migration is a
  # precision correction, not a data-integrity emergency.
  TRANSITIONS = {
    "new"      => { 1 => "learning", 2 => "learning", 3 => "learning", 4 => "learning" },
    "learning" => { 1 => "learning", 2 => "learning", 3 => "mastered", 4 => "mastered" },
    "mastered" => { 1 => "learning", 2 => "mastered", 3 => "mastered", 4 => "mastered" }
  }.freeze

  def up
    UserLearning.find_each do |user_learning|
      first_mastered_at = replay_first_mastered_at(user_learning)
      user_learning.update_column(:first_mastered_at, first_mastered_at) if first_mastered_at
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def replay_first_mastered_at(user_learning)
    state = "new"
    user_learning.review_logs.order(:created_at, :time, :id).each do |log|
      new_state = TRANSITIONS.dig(state, log.ease)
      next if new_state.nil?

      return log.created_at if new_state == "mastered" && state != "mastered"

      state = new_state
    end
    nil
  end
end
