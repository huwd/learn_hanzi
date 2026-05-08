class DictionaryEntryRadical < ApplicationRecord
  belongs_to :dictionary_entry
  belongs_to :radical

  validates :position,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 },
            uniqueness: { scope: :dictionary_entry_id }
end
