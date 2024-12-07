class DictionaryEntry < ApplicationRecord
  has_many :dictionary_entry_tags, dependent: :destroy
  has_many :tags, through: :dictionary_entry_tags
  has_many :meanings, dependent: :destroy

  validates :text, presence: true
  validates :pinyin, presence: true
  validate :must_have_at_least_one_meaning

  accepts_nested_attributes_for :meanings, allow_destroy: true

  private

  def must_have_at_least_one_meaning
    errors.add(:meanings, "must have at least one associated meaning") if meanings.empty?
  end
end
