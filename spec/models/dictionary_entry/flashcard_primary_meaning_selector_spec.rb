require "rails_helper"

RSpec.describe DictionaryEntry, "flashcard primary meaning selection" do
  let(:source) { create(:source, name: "CC-CEDICT") }

  def create_entry_with_meanings(text, meanings_attrs)
    entry = build(:dictionary_entry, text: text, meanings_count: 0)
    meanings_attrs.each do |attrs|
      entry.meanings << build(:meaning, attrs.merge(source: source, dictionary_entry: entry))
    end
    entry.save!
    entry
  end

  describe "for a simple entry with one reading" do
    it "returns the only meaning" do
      entry = create_entry_with_meanings("猫", [ { pinyin: "māo", text: "cat" } ])
      expect(entry.flashcard_primary_meaning.text).to eq("cat")
      expect(entry.flashcard_primary_meaning.pinyin).to eq("māo")
    end
  end

  describe "for an entry with a deprioritised surname sense" do
    it "prefers the common meaning over the surname" do
      entry = create_entry_with_meanings("赵", [
        { pinyin: "Zhào", text: "surname Zhao" },
        { pinyin: "zhào", text: "to surpass" }
      ])
      expect(entry.flashcard_primary_meaning.text).to eq("to surpass")
      expect(entry.flashcard_primary_meaning.pinyin).to eq("zhào")
    end
  end

  describe "for an entry with a deprioritised literary sense" do
    it "prefers the common meaning over the literary one" do
      entry = create_entry_with_meanings("曰", [
        { pinyin: "yuē", text: "to say (classical literary)" },
        { pinyin: "yuē", text: "to speak" }
      ])
      expect(entry.flashcard_primary_meaning.text).to eq("to speak")
      expect(entry.flashcard_primary_meaning.pinyin).to eq("yuē")
    end
  end

  describe "for an entry with an 'also written' variant" do
    it "prefers the main form" do
      entry = create_entry_with_meanings("筆畫", [
        { pinyin: "bǐ huà", text: "stroke (of a Chinese character)" },
        { pinyin: "bǐ huà", text: "also written 笔画" }
      ])
      expect(entry.flashcard_primary_meaning.text).to eq("stroke (of a Chinese character)")
      expect(entry.flashcard_primary_meaning.pinyin).to eq("bǐ huà")
    end
  end

  describe "for an entry with multiple pinyin readings" do
    it "prefers the most common pinyin and its corresponding meaning" do
      entry = create_entry_with_meanings("好", [
        { pinyin: "hǎo", text: "good" },
        { pinyin: "hào", text: "to be fond of" }
      ])
      expect(entry.flashcard_primary_meaning.text).to eq("good")
      expect(entry.flashcard_primary_meaning.pinyin).to eq("hǎo")
    end
  end

  describe "flashcard meaning groups" do
    it "keeps alternate readings grouped by pinyin in flashcard order" do
      entry = create_entry_with_meanings("假", [
        { pinyin: "jiǎ", text: "fake" },
        { pinyin: "jià", text: "holiday" },
        { pinyin: "jià", text: "vacation" }
      ])

      groups = entry.flashcard_meaning_groups
      grouped_pinyin = groups.map { |group| group.map(&:pinyin).uniq }
      grouped_text = groups.map { |group| group.map(&:text) }

      expect(grouped_pinyin.first).to eq([ entry.flashcard_primary_meaning.pinyin ])
      expect(grouped_pinyin).to contain_exactly([ "jiǎ" ], [ "jià" ])
      expect(grouped_text).to include([ "fake" ], [ "holiday", "vacation" ])
    end
  end

  describe "for an entry where one reading has several plain senses" do
    it "prefers that reading over a single plain alternative" do
      entry = create_entry_with_meanings("便宜", [
        { pinyin: "biàn yí", text: "convenient" },
        { pinyin: "pián yi", text: "cheap" },
        { pinyin: "pián yi", text: "inexpensive" }
      ])

      expect(entry.flashcard_primary_meaning.text).to eq("cheap")
      expect(entry.flashcard_primary_meaning.pinyin).to eq("pián yi")
    end
  end

  describe "for a word with a classifier variant" do
    it "deprioritises the classifier sense" do
      entry = create_entry_with_meanings("家", [
        { pinyin: "jiā", text: "home" },
        { pinyin: "jiā", text: "classifier for families or businesses" }
      ])
      expect(entry.flashcard_primary_meaning.text).to eq("home")
      expect(entry.flashcard_primary_meaning.pinyin).to eq("jiā")
    end
  end

  describe "when all senses are obscure" do
    it "returns the first available sense rather than nothing" do
      entry = create_entry_with_meanings("裔", [ { pinyin: "yì", text: "surname Yi" } ])
      expect(entry.flashcard_primary_meaning.text).to eq("surname Yi")
      expect(entry.flashcard_primary_meaning.pinyin).to eq("yì")
    end
  end
end
