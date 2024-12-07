class DictionaryEntry < ApplicationRecord
  has_many :dictionary_entry_tags, dependent: :destroy
  has_many :tags, through: :dictionary_entry_tags

  validates :text, presence: true
  validates :pinyin, presence: true
  validates :meanings, presence: true
end
