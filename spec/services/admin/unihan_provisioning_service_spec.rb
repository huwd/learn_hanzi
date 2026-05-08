require "rails_helper"

RSpec.describe Admin::UnihanProvisioningService do
  describe ".call" do
    subject(:result) { described_class.call }

    let(:readings_path) { Admin::UnihanProvisioningService::UNIHAN_READINGS_FILE }

    let(:readings_content) do
      <<~TXT
        # Unihan test subset
        U+4F60\tkDefinition\tyou, second person pronoun
        U+597D\tkDefinition\tgood, well
        U+0061\tkDefinition\tlatin letter a
        U+597D\tkMandarin\thao3
      TXT
    end

    before do
      allow_any_instance_of(described_class).to receive(:download_file_to_tmp)
      allow_any_instance_of(described_class).to receive(:unzip_file)
      allow_any_instance_of(described_class).to receive(:confirm_file_presence)

      FileUtils.mkdir_p(File.dirname(readings_path))
      File.write(readings_path, readings_content)
    end

    after do
      FileUtils.rm_f(readings_path)
    end

    it "creates a Unihan source with expected priority" do
      expect { result }.to change { Source.where(name: "Unihan").count }.by(1)
      expect(Source.find_by(name: "Unihan").priority).to eq(200)
    end

    it "imports only kDefinition rows for Han characters" do
      expect { result }.to change { DictionaryEntry.count }.by(2)
                       .and change { Meaning.count }.by(2)

      ni = DictionaryEntry.find_by!(text: "你")
      hao = DictionaryEntry.find_by!(text: "好")

      expect(ni.meanings.first.text).to eq("you, second person pronoun")
      expect(hao.meanings.first.text).to eq("good, well")
    end

    it "skips importing meanings when higher-priority source meaning exists" do
      wiktionary = create(:source, name: "Wiktionary", priority: 50)
      entry = create(:dictionary_entry, text: "你")
      entry.meanings.destroy_all
      create(:meaning,
             dictionary_entry: entry,
             source: wiktionary,
             language: "en",
             pinyin: "nǐ",
             text: "you")

      expect { result }.to change { Meaning.count }.by(1)
      expect(result[:skipped_higher_priority]).to eq(1)
      expect(entry.reload.meanings.where(source: Source.find_by(name: "Unihan")).count).to eq(0)
    end

    it "returns import summary stats" do
      expect(result).to include(
        definitions_parsed: 2,
        meanings_created: 2,
        skipped_higher_priority: 0
      )
    end
  end
end
