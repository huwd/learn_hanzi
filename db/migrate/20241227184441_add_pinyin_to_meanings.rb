class AddPinyinToMeanings < ActiveRecord::Migration[8.0]
  def change
    add_column :meanings, :pinyin, :string
    remove_index :meanings, name: "index_meanings_on_dictionary_entry_id_and_source"
    add_index :meanings, [ :text, :language, :source_id, :pinyin ], unique: true, name: 'index_meanings_on_text_language_source_pinyin'
  end
end
