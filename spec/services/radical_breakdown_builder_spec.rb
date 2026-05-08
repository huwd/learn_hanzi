require "rails_helper"

RSpec.describe RadicalBreakdownBuilder do
  describe ".call" do
    let(:user) { create(:user) }

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
