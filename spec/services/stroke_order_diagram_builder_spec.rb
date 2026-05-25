require "rails_helper"

RSpec.describe StrokeOrderDiagramBuilder do
  describe ".call" do
    # -------------------------------------------------------------------
    # Query count: proves eager-loading eliminates the stroke_order_datum
    # DB round-trip (1 query saved: SELECT stroke_order_data).
    # -------------------------------------------------------------------
    describe "query count" do
      let!(:entry) do
        e = create(:dictionary_entry, text: "语")
        create(:stroke_order_datum, dictionary_entry: e,
               strokes: [ "M 0 0" ], medians: [ [ [ 0, 0 ], [ 1, 1 ] ] ])
        e
      end

      it "eliminates 1 query (stroke_order_datum load) when association is pre-loaded" do
        fresh_entry     = DictionaryEntry.find(entry.id)
        preloaded_entry = DictionaryEntry.includes(:stroke_order_datum).find(entry.id)

        baseline  = count_queries { described_class.call(dictionary_entry: fresh_entry) }
        optimised = count_queries { described_class.call(dictionary_entry: preloaded_entry) }

        expect(baseline - optimised).to eq(1),
          "expected pre-loading to save 1 query (stroke_order_datum load), " \
          "but saved #{baseline - optimised} (#{baseline} → #{optimised})"
      end
    end

    it "returns a diagram for a single-character entry with stroke data" do
      entry = create(:dictionary_entry, text: "语")
      create(:stroke_order_datum, dictionary_entry: entry,
             strokes: [ "M 0 0", "M 1 1" ], medians: [ [ [ 0, 0 ] ], [ [ 1, 1 ] ] ])

      result = described_class.call(dictionary_entry: entry)

      expect(result.size).to eq(1)
      expect(result.first.character).to eq("语")
      expect(result.first.stroke_count).to eq(2)
    end

    it "returns an empty array when the entry has no stroke data" do
      entry = create(:dictionary_entry, text: "语")
      result = described_class.call(dictionary_entry: entry)
      expect(result).to be_empty
    end

    it "falls back to per-character diagrams for a multi-character entry" do
      phrase = create(:dictionary_entry, text: "学习")

      xue = create(:dictionary_entry, text: "学")
      create(:stroke_order_datum, dictionary_entry: xue,
             strokes: [ "M 0 0" ], medians: [ [ [ 0, 0 ] ] ])

      xi = create(:dictionary_entry, text: "习")
      create(:stroke_order_datum, dictionary_entry: xi,
             strokes: [ "M 1 1", "M 2 2" ], medians: [ [ [ 1, 1 ] ], [ [ 2, 2 ] ] ])

      result = described_class.call(dictionary_entry: phrase)

      expect(result.map(&:character)).to eq(%w[学 习])
      expect(result.map(&:stroke_count)).to eq([ 1, 2 ])
    end

    it "skips characters with missing stroke data in fallback mode" do
      phrase = create(:dictionary_entry, text: "学习")
      create(:dictionary_entry, text: "学")
      xi = create(:dictionary_entry, text: "习")
      create(:stroke_order_datum, dictionary_entry: xi,
             strokes: [ "M 1 1" ], medians: [ [ [ 1, 1 ] ] ])

      result = described_class.call(dictionary_entry: phrase)

      expect(result.map(&:character)).to eq(%w[习])
    end
  end
end
