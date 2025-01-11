class AddCompositeIndexToMeanings < ActiveRecord::Migration[8.0]
  def change
    add_index :meanings, [ :dictionary_entry_id, :language, :text, :pinyin, :source_id ], name: "index_meanings_on_dictionary_entry_source_and_content", unique: true
  end
end
