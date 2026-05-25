require "rails_helper"

RSpec.describe RadicalBreakdownBuilder do
  describe ".call" do
    let(:user) { create(:user) }

    # -------------------------------------------------------------------
    # Query count: proves eager-loading eliminates the radical DB round-trips.
    #
    # Without pre-loading the builder fires 2 extra queries:
    #   1. SELECT dictionary_entry_radicals WHERE dictionary_entry_id = X
    #   2. SELECT radicals WHERE id IN (...)
    # plus the mastered_characters check.
    #
    # With pre-loading those 2 queries are eliminated; only the
    # mastered_characters check remains.
    # -------------------------------------------------------------------
    describe "query count" do
      let!(:entry) do
        e = create(:dictionary_entry, text: "语")
        radical = create(:radical, character: "讠", meaning: "speech", stroke_count: 2)
        create(:dictionary_entry_radical, dictionary_entry: e, radical: radical, position: 1)
        e
      end

      # Force the lazy `let(:user)` to execute before the count window opens,
      # so user-creation queries don't inflate the measurements.
      before { user }

      it "fires only 1 query (mastered_characters check) when associations are pre-loaded" do
        preloaded_entry = DictionaryEntry.includes(dictionary_entry_radicals: :radical).find(entry.id)
        queries = count_queries { described_class.call(user: user, dictionary_entry: preloaded_entry) }
        expect(queries).to eq(1), "expected only the mastered_characters query, got #{queries}"
      end

      it "fires more queries when associations are not pre-loaded" do
        fresh_entry     = DictionaryEntry.find(entry.id)
        preloaded_entry = DictionaryEntry.includes(dictionary_entry_radicals: :radical).find(entry.id)

        baseline  = count_queries { described_class.call(user: user, dictionary_entry: fresh_entry) }
        optimised = count_queries { described_class.call(user: user, dictionary_entry: preloaded_entry) }

        expect(baseline).to be > optimised
      end
    end

    it "returns direct radical rows for single-character entries" do
      entry = create(:dictionary_entry, text: "语")
      radical = create(:radical, character: "讠", meaning: "speech", stroke_count: 2)
      create(:dictionary_entry_radical, dictionary_entry: entry, radical: radical, position: 1)

      result = described_class.call(user: user, dictionary_entry: entry)

      expect(result.size).to eq(1)
      expect(result.first.radical.character).to eq("讠")
      expect(result.first.source_character).to be_nil
    end

    it "falls back to per-character breakdown for multi-character vocab" do
      phrase = create(:dictionary_entry, text: "学校")

      xue_entry = create(:dictionary_entry, text: "学")
      xue_radical = create(:radical, character: "子", meaning: "child", stroke_count: 3)
      create(:dictionary_entry_radical, dictionary_entry: xue_entry, radical: xue_radical, position: 1)

      xiao_entry = create(:dictionary_entry, text: "校")
      xiao_radical = create(:radical, character: "木", meaning: "wood", stroke_count: 4)
      create(:dictionary_entry_radical, dictionary_entry: xiao_entry, radical: xiao_radical, position: 1)

      result = described_class.call(user: user, dictionary_entry: phrase)

      expect(result.map { |row| [ row.source_character, row.radical.character ] }).to eq(
        [ [ "学", "子" ], [ "校", "木" ] ]
      )
    end

    it "marks fallback radicals as mastered when user knows the character" do
      phrase = create(:dictionary_entry, text: "学校")

      xue_entry = create(:dictionary_entry, text: "学")
      radical = create(:radical, character: "子", meaning: "child", stroke_count: 3)
      create(:dictionary_entry_radical, dictionary_entry: xue_entry, radical: radical, position: 1)

      create(:user_learning, user: user, dictionary_entry: create(:dictionary_entry, text: "子"), state: "mastered")

      result = described_class.call(user: user, dictionary_entry: phrase)

      expect(result.first.mastered).to be(true)
    end
  end
end
