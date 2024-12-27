class CreateMeanings < ActiveRecord::Migration[8.0]
  def change
    create_table :meanings do |t|
      t.references :dictionary_entry, null: false, foreign_key: true
      t.string :language, null: false
      t.text :text, null: false

      t.timestamps
    end

    add_index :meanings, [ :dictionary_entry_id, :language, :text ], unique: true
  end
end
