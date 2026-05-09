class StrokeOrderDiagramBuilder
  Diagram = Data.define(:character, :stroke_count, :strokes, :medians)

  def self.call(dictionary_entry:)
    new(dictionary_entry:).call
  end

  def initialize(dictionary_entry:)
    @dictionary_entry = dictionary_entry
  end

  def call
    direct_diagrams.presence || fallback_diagrams
  end

  private

  def direct_diagrams
    datum = @dictionary_entry.stroke_order_datum
    return [] unless datum&.strokes.present? && datum&.medians.present?

    [ build_diagram(@dictionary_entry.text, datum) ]
  end

  def fallback_diagrams
    characters = @dictionary_entry.text.scan(/\p{Han}/u)
    return [] unless characters.size > 1

    entries_by_text = DictionaryEntry
      .where(text: characters.uniq)
      .includes(:stroke_order_datum)
      .index_by(&:text)

    characters.filter_map do |character|
      entry = entries_by_text[character]
      datum = entry&.stroke_order_datum
      next unless datum&.strokes.present? && datum&.medians.present?

      build_diagram(character, datum)
    end
  end

  def build_diagram(character, datum)
    Diagram.new(
      character: character,
      stroke_count: datum.strokes.size,
      strokes: datum.strokes,
      medians: datum.medians
    )
  end
end
