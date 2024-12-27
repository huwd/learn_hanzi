class AddIndexesToDictionaryEntryTag < ActiveRecord::Migration[8.0]
  def change
    add_index :dictionary_entry_tags, [ :dictionary_entry_id, :tag_id ], name: "index_unique_tag_on_entry", unique: true
  end
end
