class AddCompositeIndexToMeanings < ActiveRecord::Migration[8.0]
  def change
    add_index :meanings, [ :dictionary_entry_id, :language, :text, :source_id ], unique: true, name: "index_meanings_on_dictionary_entry_id_and_source"
  end
end
