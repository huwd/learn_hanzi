class TagsController < ApplicationController
  def index
    @entry_tags = Tag.where(parent_id: nil)
  end

  def show
    @entry_tag = Tag.includes(children: :children).find(params[:id])
    @child_tags = @entry_tag.children
    @dictionary_entries_grouped = TagEntriesGrouper.new(@entry_tag, Current.user).grouped_by_learning_state
    @states = {
      new_entries: "New",
      learning:    "Learning",
      mastered:    "Mastered",
      suspended:   "Suspended",
      struggling:  "Struggling"
    }
    @due_entry_ids = Set.new(
      Current.user.user_learnings
             .where(dictionary_entry: @entry_tag.dictionary_entries)
             .where(state: %w[learning mastered])
             .due
             .pluck(:dictionary_entry_id)
    )

    subtree_learnings = Current.user.user_learnings
                                    .joins(dictionary_entry: :dictionary_entry_tags)
                                    .where(dictionary_entry_tags: { tag_id: @entry_tag.subtree_ids })
    @learning_due_count = subtree_learnings.overdue_learning.count
    @review_due_count   = subtree_learnings.due_mastered.count
  end
end
