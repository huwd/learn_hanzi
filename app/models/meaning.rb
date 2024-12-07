class Meaning < ApplicationRecord
  belongs_to :dictionary_entry

  validates :language, presence: true
  validates :text, presence: true
end
