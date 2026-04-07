class DictionaryEntry < ApplicationRecord
  has_many :dictionary_entry_tags, dependent: :destroy
  has_many :tags, through: :dictionary_entry_tags
  has_many :meanings, dependent: :destroy
  has_many :user_learnings, dependent: :destroy

  validates :text, presence: true
  validate :must_have_at_least_one_meaning

  accepts_nested_attributes_for :meanings, allow_destroy: true

  def add_tag(tag)
    DictionaryEntryTag.find_or_create_by(dictionary_entry: self, tag: tag)
  end

  def user_learning_for(user)
    user_learnings.find_by(user: user)
  end

  def self.find_with_associations(id, user)
    entry = includes(tags: :parent).find(id)
    meanings = entry.meanings
    user_learning = entry.user_learning_for(user)
    { entry: entry, meanings: meanings, user_learning: user_learning }
  end

  private

  def must_have_at_least_one_meaning
    errors.add(:dictionary_entry, "must have at least one associated meaning") if meanings.empty?
  end
end
