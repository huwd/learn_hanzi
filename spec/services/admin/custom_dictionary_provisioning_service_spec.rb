require "rails_helper"

RSpec.describe Admin::CustomDictionaryProvisioningService do
  describe ".call" do
    subject(:result) { described_class.call }

    let(:yaml_content) do
      {
        "entries" => [
          { "text" => "打篮球", "meanings" => [ { "text" => "to play basketball", "pinyin" => "dǎ lánqiú" } ] }
        ]
      }
    end

    before do
      allow(YAML).to receive(:safe_load_file).and_return(yaml_content)
    end

    it "returns a hash with created and updated counts" do
      expect(result).to include(:created, :updated)
    end

    it "creates a new dictionary entry for a new text" do
      create(:source, name: "learn_hanzi")
      expect { result }.to change { DictionaryEntry.count }.by(1)
    end

    it "returns created count of 1 for a new entry" do
      create(:source, name: "learn_hanzi")
      expect(result[:created]).to eq(1)
      expect(result[:updated]).to eq(0)
    end

    it "returns updated count of 1 for an existing entry" do
      create(:source, name: "learn_hanzi")
      create(:dictionary_entry, text: "打篮球")
      expect(result[:updated]).to eq(1)
      expect(result[:created]).to eq(0)
    end
  end
end
