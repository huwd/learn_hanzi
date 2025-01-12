class DictionaryEntriesController < ApplicationController
  def show
    @entry = DictionaryEntry.find_with_associations(params[:id], Current.user)
    @dictionary_entry = @entry[:entry]
    @meanings = @entry[:meanings].where(language: "en")
    @user_learning = @entry[:user_learning]
  end
end
