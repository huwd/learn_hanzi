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
    return [] if limit <= 0

    results = full_token_results
    remaining = limit - results.size
    return results if remaining <= 0

    results + per_character_results(excluding_ids: results.map { |result| result.user_learning.id }, limit: remaining)
  end

  private

  attr_reader :user, :target_learning, :limit

  def full_token_results
    target = target_text
    return [] if target.blank?

    ids = ordered_mastered_scope
      .where("dictionary_entries.text LIKE ?", "%#{escape_like(target)}%")
      .limit(limit)
      .pluck(:id)

    load_with_includes(ids, target_characters, full_token_match: true)
  end

  def per_character_results(excluding_ids:, limit:)
    chars = target_characters
    return [] if chars.empty?

    pattern = chars.map { "dictionary_entries.text LIKE ?" }.join(" OR ")
    values = chars.map { |char| "%#{escape_like(char)}%" }

    scope = ordered_mastered_scope.where(pattern, *values)
    scope = scope.where.not(id: excluding_ids) if excluding_ids.any?

    ids = scope.limit(limit).pluck(:id)
    load_with_includes(ids, chars, full_token_match: false)
  end

  # Loads user_learnings by ID with full associations, preserving the given ID order.
  # Separated from the filtering query so that LIKE + ORDER BY + LIMIT work on a
  # simple join without Rails switching to eager_load mode (which would apply LIMIT
  # to joined rows rather than to user_learnings).
  def load_with_includes(ids, chars, full_token_match:)
    return [] if ids.empty?

    by_id = UserLearning.where(id: ids)
                        .includes(dictionary_entry: { meanings: :source })
                        .index_by(&:id)
    ids.filter_map do |id|
      learning = by_id[id]
      next unless learning
      Result.new(
        user_learning: learning,
        full_token_match: full_token_match,
        matched_characters: matching_characters_for(learning, chars)
      )
    end
  end

  def matching_characters_for(learning, chars)
    text = learning.dictionary_entry.text
    chars.select { |char| text.include?(char) }
  end

  def target_text
    target_learning.dictionary_entry.text
  end

  def target_characters
    target_text.to_s.each_char.uniq
  end

  def ordered_mastered_scope
    user.user_learnings
        .mastered
        .joins(:dictionary_entry)
        .where.not(id: target_learning.id)
        .order(Arel.sql("CASE WHEN dictionary_entries.frequency_rank IS NULL THEN 1 ELSE 0 END"))
        .order("dictionary_entries.frequency_rank ASC")
        .order("dictionary_entries.text ASC")
  end

  def escape_like(value)
    ActiveRecord::Base.sanitize_sql_like(value)
  end
end
