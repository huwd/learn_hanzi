class CreateDictionaryEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :dictionary_entries do |t|
      t.string :text
      t.string :pinyin
      t.text :meanings

      t.timestamps
    end
  end
end
