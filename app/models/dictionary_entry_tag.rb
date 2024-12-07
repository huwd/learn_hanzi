class DictionaryEntryTag < ApplicationRecord
  belongs_to :dictionary_entry
  belongs_to :tag
end
