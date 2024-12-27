class AddSourceToMeanings < ActiveRecord::Migration[8.0]
  def change
    add_reference :meanings, :source, foreign_key: true
    remove_index :meanings, columns: [ :dictionary_entry_id, :language, :text ]
  end
end
