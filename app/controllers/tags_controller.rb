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
    @dictionary_entries = @entry_tag.dictionary_entries

    respond_to do |format|
      format.html # renders show.html.erb
      format.json { render json: { tag: @entry_tag, dictionary_entries: @dictionary_entries } }
    end
  end
end
