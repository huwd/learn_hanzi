class DictionaryEntry < ApplicationRecord
  CEDICT_SENSE_DEPRIORITISATION_RULES = [
    [ /\b(?:classifier|measure\s+word)\b/i, 10 ],
    [ /\b(?:archaic|classical|literary|dialect|old\s+name\s+of)\b/i, 20 ],
    [ /\b(?:old(?:\s+variant)?|variant(?:\s+of)?|also\s+written)\b/i, 40 ],
    [ /\bsurname\b/i, 50 ]
  ].freeze

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
    english_meanings = fetch_english_meanings
    return english_meanings if english_meanings.empty?

    # First, filter out any classifier-only senses
    candidate_meanings = english_meanings.reject { |meaning| meaning.text.start_with?("CL:") }
    return candidate_meanings if candidate_meanings.empty?

    # If there are no CC-CEDICT meanings, there's no sorting to do.
    return candidate_meanings unless candidate_meanings.any?(&method(:cc_cedict_meaning?))

    # Keep original order when all CC-CEDICT senses are deprioritised.
    has_plain_cedict = candidate_meanings.any? do |meaning|
      cc_cedict_meaning?(meaning) && cedict_deprioritisation_score(meaning).zero?
    end
    return candidate_meanings unless has_plain_cedict

    ordered_by_pinyin(candidate_meanings)
  end

  def flashcard_primary_pinyin
    flashcard_primary_meaning&.pinyin
  end

  def flashcard_primary_meaning
    flashcard_meanings.first
  end

  private

  def fetch_english_meanings
    # Prioritise loaded associations to avoid N+1 queries
    if association(:meanings).loaded?
      meanings.select { |m| m.language == "en" }
    elsif persisted?
      # If not preloaded, fetch from DB
      meanings.where(language: "en").includes(:source).order(:id)
    else
      # For new records not yet in the DB
      meanings.select { |m| m.language == "en" }
    end
  end

  def sort_penalty(meaning)
    return 0 unless cc_cedict_meaning?(meaning)

    cedict_deprioritisation_score(meaning)
  end

  def ordered_by_pinyin(candidate_meanings)
    indexed = candidate_meanings.each_with_index.to_a
    grouped = indexed.group_by { |meaning, _index| meaning.pinyin }

    grouped
      .sort_by { |_pinyin, meanings| pinyin_group_sort_key(meanings) }
      .flat_map do |_pinyin, meanings|
        meanings.sort_by { |meaning, index| [ sort_penalty(meaning), index ] }.map(&:first)
      end
  end

  def pinyin_group_sort_key(meanings)
    penalties = meanings.map { |meaning, _index| sort_penalty(meaning) }

    [
      penalties.min,
      -penalties.count(0),
      penalties.sum,
      meanings.first.last
    ]
  end

  def cedict_deprioritisation_score(meaning)
    text = meaning.text

    CEDICT_SENSE_DEPRIORITISATION_RULES.each do |pattern, score|
      return score if text.match?(pattern)
    end

    0
  end

  def cc_cedict_meaning?(meaning)
    meaning.source&.name == "CC-CEDICT"
  end

  def must_have_at_least_one_meaning
    errors.add(:dictionary_entry, "must have at least one associated meaning") if meanings.empty?
  end
end
