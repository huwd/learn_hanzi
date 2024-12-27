class DictionaryEntryTag < ApplicationRecord
  belongs_to :dictionary_entry
  belongs_to :tag

  validates :dictionary_entry_id, uniqueness: { scope: :tag_id }
end
