class AddUniqueIndexToDictionaryEntriesText < ActiveRecord::Migration[8.1]
  def change
    add_index :dictionary_entries, :text, unique: true
  end
end
