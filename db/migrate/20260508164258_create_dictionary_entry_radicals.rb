class CreateDictionaryEntryRadicals < ActiveRecord::Migration[8.1]
  def change
    create_table :dictionary_entry_radicals do |t|
      t.references :dictionary_entry, null: false, foreign_key: true
      t.references :radical, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end

    add_index :dictionary_entry_radicals,
              [ :dictionary_entry_id, :position ],
              unique: true,
              name: "index_unique_radical_position_on_entry"
  end
end
