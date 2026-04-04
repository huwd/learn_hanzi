class TagsController < ApplicationController
  def index
    @entry_tags = Tag.where(parent_id: nil)
  end

  def show
    @entry_tag = Tag.find(params[:id])
    @child_tags = @entry_tag.children
    @dictionary_entries_grouped = TagEntriesGrouper.new(@entry_tag, Current.user).grouped_by_learning_state
    @states = {
      not_learned: "Not Learned yet",
      new_entries: "New",
      learning:    "Learning",
      mastered:    "Mastered",
      suspended:   "Suspended"
    }
    @due_entry_ids = Set.new(
      Current.user.user_learnings
             .where(dictionary_entry: @entry_tag.dictionary_entries)
             .where(state: %w[learning mastered])
             .due
             .pluck(:dictionary_entry_id)
    )
  end
end
