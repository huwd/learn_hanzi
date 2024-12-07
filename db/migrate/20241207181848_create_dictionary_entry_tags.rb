class CreateDictionaryEntryTags < ActiveRecord::Migration[8.0]
  def change
    create_table :dictionary_entry_tags do |t|
      t.references :dictionary_entry, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
  end
end
