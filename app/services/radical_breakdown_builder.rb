class RadicalBreakdownBuilder
  Row = Data.define(:radical, :position, :source_character)
  Result = Data.define(:radical, :position, :mastered, :source_character)

  def self.call(user:, dictionary_entry:)
    new(user:, dictionary_entry:).call
  end

  def initialize(user:, dictionary_entry:)
    @user = user
    @dictionary_entry = dictionary_entry
  end

  def call
    rows = direct_rows
    rows = fallback_rows_for_multi_character_entry if rows.empty?

    return [] if rows.empty?

    mastered_characters = mastered_characters(rows)

    rows.map do |row|
      Result.new(
        radical: row.radical,
        position: row.position,
        mastered: mastered_characters.include?(row.radical.character),
        source_character: row.source_character
      )
    end
  end

  private

  def mastered_characters(rows)
    characters = rows.map { |row| row.radical.character }.uniq

    @user.user_learnings
         .where(state: "mastered")
         .joins(:dictionary_entry)
         .where(dictionary_entries: { text: characters })
         .pluck("dictionary_entries.text")
         .uniq
  end

  def direct_rows
    rel = @dictionary_entry.dictionary_entry_radicals
    # Use pre-loaded collection when available (controller eager-loads radical chain);
    # fall back to DB-side includes+order when called without pre-loading.
    rows = if rel.loaded?
      rel.sort_by { |r| [ r.position, r.id ] }
    else
      rel.includes(:radical).order(:position, :id).to_a
    end
    rows.map { |row| Row.new(radical: row.radical, position: row.position, source_character: nil) }
  end

  def fallback_rows_for_multi_character_entry
    characters = @dictionary_entry.text.scan(/\p{Han}/u)
    return [] unless characters.size > 1

    entries_by_text = DictionaryEntry
      .where(text: characters.uniq)
      .includes(dictionary_entry_radicals: :radical)
      .index_by(&:text)

    characters.flat_map do |character|
      entry = entries_by_text[character]
      next [] unless entry

      entry.dictionary_entry_radicals
           .sort_by { |row| [ row.position, row.id ] }
           .map do |row|
             Row.new(
               radical: row.radical,
               position: row.position,
               source_character: character
             )
           end
    end
  end
end
