class AddSourceToMeanings < ActiveRecord::Migration[8.0]
  def change
    add_reference :meanings, :source, foreign_key: true
    remove_index :meanings, name: "index_meanings_on_dictionary_entry_id_and_language_and_meaning"
  end
end
