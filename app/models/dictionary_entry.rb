class DictionaryEntry < ApplicationRecord
  CEDICT_DEPRIORITISED_SENSE_PATTERN = /\b(?:surname|archaic|classical|literary|dialect|old(?:\s+variant)?|variant(?:\s+of)?|also\s+written)\b/i

  has_many :dictionary_entry_tags, dependent: :destroy
  has_many :tags, through: :dictionary_entry_tags
  has_many :meanings, dependent: :destroy
  has_many :user_learnings, dependent: :destroy

  validates :text, presence: true
  validates :frequency_rank, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
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
    meanings = entry.meanings.includes(:source)
    user_learning = entry.user_learning_for(user)
    { entry: entry, meanings: meanings, user_learning: user_learning }
  end

  def flashcard_meanings
    english_meanings = if persisted?
      Meaning.includes(:source).where(dictionary_entry_id: id, language: "en").order(:id).to_a
    else
      meanings.select { |meaning| meaning.language == "en" }
    end

    candidate_meanings = english_meanings.reject { |meaning| meaning.text.start_with?("CL:") }

    return candidate_meanings unless candidate_meanings.any? { |meaning| cc_cedict_meaning?(meaning) }

    keep_obscure_first = candidate_meanings.none? do |meaning|
      cc_cedict_meaning?(meaning) && !obscure_cedict_meaning?(meaning)
    end

    candidate_meanings.each_with_index
                      .sort_by { |meaning, index| [ deprioritise_obscure?(meaning, keep_obscure_first), index ] }
                      .map(&:first)
  end

  def flashcard_primary_meaning
    flashcard_meanings.first
  end

  private

  def cc_cedict_meaning?(meaning)
    meaning.source&.name == "CC-CEDICT"
  end

  def obscure_cedict_meaning?(meaning)
    meaning.text.match?(CEDICT_DEPRIORITISED_SENSE_PATTERN)
  end

  def deprioritise_obscure?(meaning, keep_obscure_first)
    return 0 unless cc_cedict_meaning?(meaning)
    return 0 if keep_obscure_first

    obscure_cedict_meaning?(meaning) ? 1 : 0
  end

  def must_have_at_least_one_meaning
    errors.add(:dictionary_entry, "must have at least one associated meaning") if meanings.empty?
  end
end
