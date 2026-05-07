require "rails_helper"

RSpec.describe Admin::FrequencyProvisioningService do
  describe ".call" do
    subject(:result) { described_class.call }

    let(:subtlex_path) { Admin::FrequencyProvisioningService::SUBTLEX_PATH }

    let(:subtlex_content) do
      <<~TSV
        Word\tWCount\tW.million\tDominant.PoS
        你好\t200\t60.0\tn
        爱\t180\t45.5\tv
        缺词\t160\t40.0\tn
      TSV
    end

    let!(:entry_nihao) { create(:dictionary_entry, text: "你好") }
    let!(:entry_ai) { create(:dictionary_entry, text: "爱") }

    before do
      stub_request(:get, Admin::FrequencyProvisioningService::SUBTLEX_URL)
        .to_return(body: subtlex_content)
      FileUtils.rm_f(subtlex_path)
    end

    after { FileUtils.rm_f(subtlex_path) }

    it "returns parsed, updated, and missing counts" do
      expect(result).to eq(
        words_parsed: 3,
        entries_updated: 2,
        missing_from_dictionary: 1
      )
    end

    it "uses source corpus positions for matched dictionary entries" do
      result

      expect(entry_nihao.reload.frequency_rank).to eq(1)
      expect(entry_ai.reload.frequency_rank).to eq(2)
    end

    it "preserves source rank positions when top words are missing" do
      stub_request(:get, Admin::FrequencyProvisioningService::SUBTLEX_URL)
        .to_return(body: <<~TSV)
          Word\tWCount\tW.million\tDominant.PoS
          缺词\t300\t90.0\tn
          你好\t200\t60.0\tn
          爱\t180\t45.5\tv
        TSV

      result

      expect(entry_nihao.reload.frequency_rank).to eq(2)
      expect(entry_ai.reload.frequency_rank).to eq(3)
    end

    it "clears ranks for entries absent from the latest import" do
      stale_entry = create(:dictionary_entry, text: "旧词", frequency_rank: 9)

      result

      expect(stale_entry.reload.frequency_rank).to be_nil
    end

    it "raises on invalid SUBTLEX headers" do
      stub_request(:get, Admin::FrequencyProvisioningService::SUBTLEX_URL)
        .to_return(body: "Token\tCount\n你好\t10\n")

      expect { result }.to raise_error(/Invalid SUBTLEX header/)
    end
  end
end
