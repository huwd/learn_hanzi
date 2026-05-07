class TagEntriesGrouper
  ORDER_OPTIONS = {
    "hsk" => "HSK order",
    "frequency_common" => "Most common first",
    "frequency_rare" => "Rarest first"
  }.freeze

  def initialize(tag, user)
    @tag = tag
    @user = user
  end

  def grouped_by_learning_state(order: "hsk")
    entries = @tag.dictionary_entries
                    .joins(:user_learnings)
                    .where(user_learnings: { user_id: @user.id })
                    .select("dictionary_entries.*, user_learnings.state as learning_state, user_learnings.factor as learning_factor")

    grouped = entries.group_by(&:learning_state).transform_values { |group| apply_order(group, order) }
    learning = grouped["learning"] || []

    unstarted = @tag.dictionary_entries.where.not(id: UserLearning.where(user: @user).select(:dictionary_entry_id)).to_a
    ordered_unstarted = apply_order(unstarted, order)

    {
      new_entries:  apply_order((grouped["new"] || []) + ordered_unstarted, order),
      learning:     learning.reject { |e| e.learning_factor < 2000 },
      struggling:   learning.select { |e| e.learning_factor < 2000 },
      mastered:     grouped["mastered"] || [],
      suspended:    grouped["suspended"] || []
    }
  end

  private

  def apply_order(entries, order)
    case order
    when "frequency_common"
      entries.sort_by { |entry| [ entry.frequency_rank || Float::INFINITY, entry.text ] }
    when "frequency_rare"
      entries.sort_by { |entry| [ entry.frequency_rank ? 0 : 1, -(entry.frequency_rank || 0), entry.text ] }
    else
      entries.sort_by(&:text)
    end
  end
end
