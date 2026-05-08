class RelatedAnchorBuilder
  Result = Struct.new(:user_learning, :full_token_match, :matched_characters, keyword_init: true)

  class << self
    def call(user:, target_learning:, limit: 5)
      new(user: user, target_learning: target_learning, limit: limit).call
    end
  end

  def initialize(user:, target_learning:, limit:)
    @user = user
    @target_learning = target_learning
    @limit = limit
  end

  def call
    matches = build_match_map.values

    matches
      .sort_by { |result| sort_key(result) }
      .first(limit)
  end

  private

  attr_reader :user, :target_learning, :limit

  def build_match_map
    map = {}

    full_token_matches.each do |learning|
      map[learning.id] = Result.new(
        user_learning: learning,
        full_token_match: true,
        matched_characters: []
      )
    end

    per_character_matches.each do |learning, chars|
      existing = map[learning.id]
      if existing
        existing.matched_characters = chars
      else
        map[learning.id] = Result.new(
          user_learning: learning,
          full_token_match: false,
          matched_characters: chars
        )
      end
    end

    map
  end

  def full_token_matches
    target = target_text
    return [] if target.blank?

    mastered_scope
      .where("dictionary_entries.text LIKE ?", "%#{escape_like(target)}%")
      .to_a
  end

  def per_character_matches
    chars = target_characters
    return [] if chars.empty?

    pattern = chars.map { "dictionary_entries.text LIKE ?" }.join(" OR ")
    values = chars.map { |char| "%#{escape_like(char)}%" }

    mastered_scope
      .where(pattern, *values)
      .to_a
      .map { |learning| [ learning, matching_characters_for(learning, chars) ] }
  end

  def matching_characters_for(learning, chars)
    text = learning.dictionary_entry.text
    chars.select { |char| text.include?(char) }
  end

  def sort_key(result)
    [
      result.full_token_match ? 0 : 1,
      frequency_presence_rank(result.user_learning.dictionary_entry),
      result.user_learning.dictionary_entry.frequency_rank || Float::INFINITY,
      result.user_learning.dictionary_entry.text
    ]
  end

  def frequency_presence_rank(entry)
    entry.frequency_rank.present? ? 0 : 1
  end

  def target_text
    target_learning.dictionary_entry.text
  end

  def target_characters
    target_text.to_s.each_char.uniq
  end

  def mastered_scope
    user.user_learnings
        .mastered
        .joins(:dictionary_entry)
        .where.not(id: target_learning.id)
        .includes(dictionary_entry: { meanings: :source })
  end

  def escape_like(value)
    ActiveRecord::Base.sanitize_sql_like(value)
  end
end
