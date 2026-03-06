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

      meanings = dictionary_entry.meanings
      source = Source.find_by(name: "CC-CEDICT")

      expect(meanings.map(&:text)).to eq([ "one breath", "in one breath", "at a stretch" ])
      expect(meanings.map(&:language)).to eq([ 'en', 'en', 'en' ])
      expect(meanings.map(&:source)).to eq(Array.new(3, source))
      expect(meanings.map(&:pinyin)).to eq(Array.new(3, 'yī kǒu qì'))
    end

    context 'when the DictionaryEntry already exists' do
      before do
        @source = Source.find_or_create_by(name: sample_source[:name], url: sample_source[:url], date_accessed: Date.today)
        @existing_entry = DictionaryEntry.build(text: '一口气')
        @existing_entry.meanings << Meaning.build(text: "one breath", language: "en", pinyin: 'yī kǒu qì', source: @source)
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

    it 'raises an error if the line cannot be parsed' do
      invalid_line = 'Invalid line format'
      expect {
        find_or_create_dictionary_entry(invalid_line, sample_source)
      }.to raise_error(RuntimeError, "Error parsing line: #{invalid_line}")
    end

    context 'when passed a pre-loaded Source object instead of a hash' do
      let(:pre_loaded_source) do
        Source.create!(
          name: "CC-CEDICT",
          url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip",
          date_accessed: Date.today
        )
      end

      it 'creates the entry and meanings using the provided source' do
        expect {
          DictionaryImportHelper.find_or_create_dictionary_entry(sample_string, pre_loaded_source)
        }.to change(DictionaryEntry, :count).by(1)
          .and change(Meaning, :count).by(3)

        meanings = DictionaryEntry.find_by!(text: "一口气").meanings
        expect(meanings.map(&:source).uniq).to eq([ pre_loaded_source ])
      end

      it 'does not call find_or_create_cc_cedict_source' do
        expect(DictionaryImportHelper).not_to receive(:find_or_create_cc_cedict_source)
        DictionaryImportHelper.find_or_create_dictionary_entry(sample_string, pre_loaded_source)
      end
    end

    # Regression anchors: real CC-CEDICT lines that caused UNIQUE constraint
    # failures (logged in log/dictionary_import_errors.log) because the same
    # meaning text appears more than once within a single entry's meaning string.
    context 'when a CEDICT entry contains duplicate meanings' do
      let(:di_line) do
        "底 底 [di3] /background/bottom/base/end (of the month, year etc)/remnants/(math.) radix/base/"
      end
      let(:pan_line) do
        "盤 盘 [pan2] /plate/dish/tray/board/hard drive (computing)/to build/to coil/to check/" \
          "to examine/to transfer (property)/to make over/classifier for food: dish, helping/" \
          "to coil/classifier for coils of wire/classifier for games of chess/"
      end

      it 'imports 底 without raising a constraint error' do
        expect { find_or_create_dictionary_entry(di_line, sample_source) }.not_to raise_error
      end

      it 'stores only one meaning for the repeated text in 底' do
        find_or_create_dictionary_entry(di_line, sample_source)
        entry = DictionaryEntry.find_by!(text: "底")
        expect(entry.meanings.where(text: "base").count).to eq(1)
      end

      it 'imports 盘 without raising a constraint error' do
        expect { find_or_create_dictionary_entry(pan_line, sample_source) }.not_to raise_error
      end

      it 'stores only one meaning for the repeated text in 盘' do
        find_or_create_dictionary_entry(pan_line, sample_source)
        entry = DictionaryEntry.find_by!(text: "盘")
        expect(entry.meanings.where(text: "to coil").count).to eq(1)
      end
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
      expect(parse_cc_cedict_line(sample_string, sample_source)[:meaning_attributes].map { |meaning| meaning[:pinyin] })
        .to eq(Array.new(3, "yī kǒu qì"))
    end

    it "pulls out the meanings as an array" do
      expect(parse_cc_cedict_line(sample_string, sample_source)[:meaning_attributes]).to eq(
        [
          { text: "one breath", pinyin: "yī kǒu qì", language: "en", source_attributes: sample_source },
          { text: "in one breath", language: "en", pinyin: "yī kǒu qì", source_attributes: sample_source  },
          { text: "at a stretch", language: "en", pinyin: "yī kǒu qì", source_attributes: sample_source  }
        ]
      )
    end

    context "with known buggy CC-CEDICT lines" do
      buggy_lines = [
        "% % [pa1] /percent (Tw)/\r\n",
        "〇 〇 [ling2] /zero/\r\n",
        "11區 11区 [Shi2 yi1 Qu1] /(ACG) Japan (from the anime \"Code Geass\", in which Japan was renamed Area 11)/\r\n"
      ]

      buggy_lines.each do |line|
        it "parses the line #{line}" do
          expect(parse_cc_cedict_line(line, sample_source)).not_to be_nil

          expect(parse_cc_cedict_line(line, sample_source).keys).to include(
            :simplified,
            :traditional,
            :meaning_attributes
          )
        end
      end
    end
  end
end
