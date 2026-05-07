class TagEntriesGrouper
  ORDER_OPTIONS = {
    "text" => "Text (A-Z)",
    "frequency_common" => "Most common first",
    "frequency_rare" => "Rarest first"
  }.freeze

  def initialize(tag, user)
    @tag = tag
    @user = user
  end

  def grouped_by_learning_state(order: "text")
    entries = @tag.dictionary_entries
                    .joins(:user_learnings)
                    .where(user_learnings: { user_id: @user.id })
                    .select("dictionary_entries.*, user_learnings.state as learning_state, user_learnings.factor as learning_factor")

    grouped = entries.group_by(&:learning_state)
    learning = apply_order(grouped["learning"] || [], order)

    unstarted = @tag.dictionary_entries.where.not(id: UserLearning.where(user: @user).select(:dictionary_entry_id)).to_a
    new_entries = apply_order((grouped["new"] || []) + unstarted, order)

    {
      new_entries:  new_entries,
      learning:     learning.reject { |e| e.learning_factor < 2000 },
      struggling:   learning.select { |e| e.learning_factor < 2000 },
      mastered:     apply_order(grouped["mastered"] || [], order),
      suspended:    apply_order(grouped["suspended"] || [], order)
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
