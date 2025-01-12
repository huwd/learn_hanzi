class TagsController < ApplicationController
  def index
    @entry_tags = Tag.where(parent_id: nil)

    respond_to do |format|
      format.html # renders index.html.erb
      format.json { render json: @entry_tags }
    end
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

    respond_to do |format|
      format.html # renders show.html.erb
      format.json { render json: { tag: @entry_tag, dictionary_entries: @dictionary_entries } }
    end
  end
end
