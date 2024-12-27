class AddIndexesToMeanings < ActiveRecord::Migration[8.0]
  def change
    remove_index :meanings, column: [ :dictionary_entry_id, :language, :text, :source_id ], name: "index_meanings_on_dictionary_entry_id_and_source", unique: true
    add_index :meanings, [ :dictionary_entry_id, :language, :text, :pinyin, :source_id ], name: "index_meanings_on_dictionary_entry_source_and_content", unique: true
  end
end
