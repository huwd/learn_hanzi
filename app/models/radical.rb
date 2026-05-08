class Radical < ApplicationRecord
  has_many :dictionary_entry_radicals, dependent: :destroy
  has_many :dictionary_entries, through: :dictionary_entry_radicals

  validates :character, presence: true, uniqueness: true
  validates :stroke_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
