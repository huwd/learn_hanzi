class DictionaryEntriesController < ApplicationController
  def show
    @dictionary_entry = DictionaryEntry.find_by_id(params[:id])
    @meanings = @dictionary_entry.meanings.select { |meaning| meaning.language == "en" }
  end
end
