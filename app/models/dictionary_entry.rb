class DictionaryEntry < ApplicationRecord
  has_many :dictionary_entry_tags, dependent: :destroy
  has_many :tags, through: :dictionary_entry_tags
  has_many :meanings, dependent: :destroy

  validates :text, presence: true
  validate :must_have_at_least_one_meaning

  accepts_nested_attributes_for :meanings, allow_destroy: true

  def add_tag(tag)
    DictionaryEntryTag.find_or_create_by(dictionary_entry: self, tag: tag)
  end

  private

  def must_have_at_least_one_meaning
    errors.add(:dictionary_entry, "must have at least one associated meaning") if meanings.empty?
  end
end
