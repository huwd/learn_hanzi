class Meaning < ApplicationRecord
  belongs_to :dictionary_entry
  belongs_to :source

  validates :language, presence: true
  validates :text, presence: true
end
