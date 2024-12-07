class DictionaryEntry < ApplicationRecord
  validates :text, presence: true
  validates :pinyin, presence: true
  validates :meanings, presence: true
end
