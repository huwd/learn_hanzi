class BackfillFirstMasteredAtFromReviewLogs < ActiveRecord::Migration[8.1]
  # Mirrors SpacedRepetition::SM2#calculated_state's transition table
  # (sm2.rb:56-68) — suspended is a manual override outside this table and
  # is left untouched by review history.
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
    user_learning.review_logs.order(:created_at).each do |log|
      new_state = TRANSITIONS.dig(state, log.ease)
      next if new_state.nil?

      return log.created_at if new_state == "mastered" && state != "mastered"

      state = new_state
    end
    nil
  end
end
