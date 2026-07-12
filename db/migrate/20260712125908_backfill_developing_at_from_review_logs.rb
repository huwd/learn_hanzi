class BackfillDevelopingAtFromReviewLogs < ActiveRecord::Migration[8.1]
  # Mirrors SpacedRepetition::SM2#calculated_state's transition table
  # (sm2.rb:56-68), same as the other review_logs replay migrations.
  TRANSITIONS = {
    "new"      => { 1 => "learning", 2 => "learning", 3 => "learning", 4 => "learning" },
    "learning" => { 1 => "learning", 2 => "learning", 3 => "mastered", 4 => "mastered" },
    "mastered" => { 1 => "learning", 2 => "mastered", 3 => "mastered", 4 => "mastered" }
  }.freeze

  def up
    UserLearning.find_each do |user_learning|
      developing_at = replay_developing_at(user_learning)
      user_learning.update_column(:developing_at, developing_at) if developing_at
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def replay_developing_at(user_learning)
    threshold = Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT
    state = "new"
    ever_graduated = false
    user_learning.review_logs.order(:created_at, :time, :id).each.with_index(1) do |log, review_count|
      new_state = TRANSITIONS.dig(state, log.ease)
      next if new_state.nil?

      ever_graduated ||= (new_state == "mastered")
      # Established (first_mastered_at, durable) takes priority over
      # Developing regardless of live state -- a word that graduated and
      # later relapsed is still Established at review 5, not Developing.
      return ever_graduated ? nil : log.created_at if review_count == threshold

      state = new_state
    end
    nil
  end
end
