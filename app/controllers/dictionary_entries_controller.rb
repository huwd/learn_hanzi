class DictionaryEntriesController < ApplicationController
  def show
    @entry = DictionaryEntry.find_with_associations(params[:id], Current.user)
    @dictionary_entry = @entry[:entry]
    preloaded_meanings = @entry[:meanings].to_a
    @dictionary_entry.association(:meanings).target = preloaded_meanings

    english_meanings = preloaded_meanings.select { |meaning| meaning.language == "en" }
    flashcard_order = @dictionary_entry.flashcard_meanings
    @meanings = flashcard_order + (english_meanings - flashcard_order)
    @user_learning = @entry[:user_learning]
    @review_logs =
      if @user_learning
        @user_learning.review_logs.order(created_at: :desc).limit(30)
      else
        ReviewLog.none
      end
    @radical_breakdown = RadicalBreakdownBuilder.call(
      user: Current.user,
      dictionary_entry: @dictionary_entry
    )
    @stroke_order_diagrams = StrokeOrderDiagramBuilder.call(dictionary_entry: @dictionary_entry)
  end
end
