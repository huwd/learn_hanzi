class RadicalBreakdownBuilder
  Result = Data.define(:radical, :position, :mastered)

  def self.call(user:, dictionary_entry:)
    new(user:, dictionary_entry:).call
  end

  def initialize(user:, dictionary_entry:)
    @user = user
    @dictionary_entry = dictionary_entry
  end

  def call
    rows = @dictionary_entry
      .dictionary_entry_radicals
      .order(:position, :id)

    return [] if rows.empty?

    mastered_characters = mastered_characters(rows)

    rows.map do |row|
      Result.new(
        radical: row.radical,
        position: row.position,
        mastered: mastered_characters.include?(row.radical.character)
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
end
