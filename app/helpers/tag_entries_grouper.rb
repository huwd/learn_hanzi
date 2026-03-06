class TagEntriesGrouper
  def initialize(tag, user)
    @tag = tag
    @user = user
  end

  def grouped_by_learning_state
    entries = @tag.dictionary_entries
                    .joins(:user_learnings)
                    .where(user_learnings: { user_id: @user.id })
                    .select("dictionary_entries.*, user_learnings.state as learning_state")

    grouped = entries.group_by(&:learning_state)

    {
      not_learned:  @tag.dictionary_entries
                          .where.not(id: UserLearning.where(user: @user).select(:dictionary_entry_id)),
      new_entries:  grouped["new"]          || [],
      learning:     grouped["learning"]     || [],
      mastered:     grouped["mastered"]     || [],
      suspended:    grouped["suspended"]    || []
    }
  end
end
