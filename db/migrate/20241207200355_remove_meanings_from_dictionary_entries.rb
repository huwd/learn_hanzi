class RemoveMeaningsFromDictionaryEntries < ActiveRecord::Migration[8.0]
  def change
    remove_column :dictionary_entries, :meanings, :text
  end
end
