class RemovePinyinFromDictionaryEntries < ActiveRecord::Migration[8.0]
  def change
    remove_column :dictionary_entries, :pinyin, :string
  end
end
