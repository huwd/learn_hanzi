class TagEntriesGrouper
  def initialize(tag, user)
    @tag = tag
    @user = user
  end

  def grouped_by_learning_state
    entries = @tag.dictionary_entries
                    .joins(:user_learnings)
                    .where(user_learnings: { user_id: @user.id })
                    .select("dictionary_entries.*, user_learnings.state as learning_state, user_learnings.factor as learning_factor")

    grouped = entries.group_by(&:learning_state)
    learning = grouped["learning"] || []

    unstarted = @tag.dictionary_entries
                    .where.not(id: UserLearning.where(user: @user).select(:dictionary_entry_id))

    {
      new_entries:  (grouped["new"] || []) + unstarted.to_a,
      learning:     learning.reject { |e| e.learning_factor < 2000 },
      struggling:   learning.select { |e| e.learning_factor < 2000 },
      mastered:     grouped["mastered"] || [],
      suspended:    grouped["suspended"] || []
    }
  end
end
