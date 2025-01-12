class DictionaryEntriesController < ApplicationController
  def show
    @dictionary_entry = DictionaryEntry.find_by_id(params[:id])
    @meanings = @dictionary_entry.meanings.select { |meaning| meaning.language == "en" }
    @user_learning = UserLearning.find { |ul| ul.user == Current.user && ul.dictionary_entry == @dictionary_entry }
    @reviews = @user_learning.review_logs
  end
end
