class AddFrequencyRankToDictionaryEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :dictionary_entries, :frequency_rank, :integer
    add_index :dictionary_entries, :frequency_rank
  end
end
