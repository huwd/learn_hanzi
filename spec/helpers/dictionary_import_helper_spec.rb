require 'rails_helper'

include DictionaryImportHelper


describe "DictionaryImportHelper" do
  let(:sample_string) { "一口氣 一口气 [yi1 kou3 qi4] /one breath/in one breath/at a stretch/" }
  let(:sample_source) do
    {
      name: "CC-CEDICT",
      url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
    }
  end

  describe "find_or_create_cc_cedict_source" do
    it "creates a new source if it doesn't exist" do
      expect {
        find_or_create_cc_cedict_source("CC-CEDICT", "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
      }.to change(Source, :count).by(1)

      source = Source.find_by(name: "CC-CEDICT")
      expect(source).to be_present
      expect(source.url).to eq("https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
      expect(source.date_accessed).to eq(Date.today)
    end

    it "updates the date_accessed for an existing source" do
      existing_source = Source.create!(
        name: "CC-CEDICT",
        url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip",
        date_accessed: Date.yesterday
      )

      find_or_create_cc_cedict_source("CC-CEDICT", "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
      existing_source.reload

      expect(existing_source.date_accessed).to eq(Date.today)
    end
  end

  describe '#find_or_create_dictionary_entry' do
    it 'creates a new DictionaryEntry and associated Meanings' do
        expect {
        find_or_create_dictionary_entry(sample_string, sample_source)
      }.to change(DictionaryEntry, :count).by(1)
        .and change(Meaning, :count).by(3)

      dictionary_entry = DictionaryEntry.last
      expect(dictionary_entry.text).to eq('一口气')
      expect(dictionary_entry.pinyin).to eq('yī kǒu qì')

      meanings = dictionary_entry.meanings
      source = Source.find_by(name: "CC-CEDICT")

      expect(meanings.map(&:text)).to eq([ "one breath", "in one breath", "at a stretch" ])
      expect(meanings.map(&:language)).to eq([ 'en', 'en', 'en' ])
      expect(meanings.map(&:source)).to eq(Array.new(3, source))
    end

    context 'when the DictionaryEntry already exists' do
      before do
        @source = Source.find_or_create_by(name: sample_source[:name], url: sample_source[:url], date_accessed: Date.today)
        @existing_entry = DictionaryEntry.build(text: '一口气', pinyin: 'yī kǒu qì')
        @existing_entry.meanings << Meaning.build(text: "one breath", language: "en", source: @source)
        @existing_entry.save!
      end

      it 'does not create a new DictionaryEntry' do
        expect {
          find_or_create_dictionary_entry(sample_string, sample_source)
        }.not_to change(DictionaryEntry, :count)
      end

      it 'creates new Meanings and associates them with the existing DictionaryEntry' do
        expect {
          find_or_create_dictionary_entry(sample_string, sample_source)
        }.to change(Meaning, :count).by(2)

        meanings = DictionaryEntry.find_by_id(@existing_entry.id).meanings
        expect(meanings.map(&:text)).to eq([ "one breath", "in one breath", "at a stretch" ])
        expect(meanings.map(&:language)).to eq([ 'en', 'en', 'en' ])
        expect(meanings.map(&:source)).to eq(Array.new(3, @source))
      end
    end

    it 'returns nil if the line cannot be parsed' do
      invalid_line = 'Invalid line format'
      result = find_or_create_dictionary_entry(invalid_line, sample_source)
      expect(result).to be_nil
    end
  end

  describe "parse_cc_cedict_line" do
    it "pulls out the simplified chinese" do
      expect(parse_cc_cedict_line(sample_string, sample_source)[:simplified]).to eq("一口气")
    end

    it "pulls out the traditional chinese" do
      expect(parse_cc_cedict_line(sample_string, sample_source)[:traditional]).to eq("一口氣")
    end

    it "pulls out the pinyin and accents the characters" do
      expect(parse_cc_cedict_line(sample_string, sample_source)[:pinyin]).to eq("yī kǒu qì")
    end

    it "pulls out the meanings as an array" do
      expect(parse_cc_cedict_line(sample_string, sample_source)[:meaning_attributes]).to eq(
        [
          { text: "one breath", language: "en", source_attributes: sample_source },
          { text: "in one breath", language: "en", source_attributes: sample_source  },
          { text: "at a stretch", language: "en", source_attributes: sample_source  }
        ]
      )
    end
  end
end
