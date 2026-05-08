require "rails_helper"

RSpec.describe Admin::WiktionaryProvisioningService do
  describe ".call" do
    subject(:result) { described_class.call }

    let(:jsonl_content) do
      [
        { "lang" => "English", "word" => "skip_me" }.to_json,
        { "lang" => "Chinese", "word" => "abc", "senses" => [ { "glosses" => [ "skip non hanzi" ] } ] }.to_json,
        {
          "lang" => "Chinese",
          "word" => "好",
          "senses" => [ { "glosses" => [ "good" ] } ],
          "sounds" => [ { "tags" => [ "Mandarin", "Pinyin" ], "zh_pron" => "hǎo (hao3)" } ]
        }.to_json,
        {
          "lang" => "Chinese",
          "word" => "不好",
          "senses" => [ { "glosses" => [ "bad" ] } ],
          "sounds" => [ { "tags" => [ "Mandarin", "Pinyin" ], "zh_pron" => "bù hǎo" } ]
        }.to_json,
        "invalid json {"
      ].join("\n")
    end

    before do
      allow_any_instance_of(described_class).to receive(:download_file_to_tmp)

      mock_gz = instance_double(Zlib::GzipReader)
      allow(Zlib::GzipReader).to receive(:open).and_yield(mock_gz)
      allow(mock_gz).to receive(:each_line).and_yield(jsonl_content.split("\n")[0])
                                            .and_yield(jsonl_content.split("\n")[1])
                                            .and_yield(jsonl_content.split("\n")[2])
                                            .and_yield(jsonl_content.split("\n")[3])
                                            .and_yield(jsonl_content.split("\n")[4])
    end

    it "creates a wiktionary source if it does not exist" do
      expect { result }.to change { Source.where(name: "Wiktionary").count }.by(1)
    end

    it "creates dictionary entries and meanings for valid chinese hanzi records" do
      expect { result }.to change { DictionaryEntry.count }.by(2)
                       .and change { Meaning.count }.by(2)

      entry = DictionaryEntry.find_by(text: "好")
      meaning = entry.meanings.first
      expect(meaning.text).to eq("good")
      expect(meaning.pinyin).to eq("hǎo")
      expect(meaning.source.name).to eq("Wiktionary")
    end

    it "returns the before, after, and created counts" do
      expect(result).to include(
        entries_before: 0,
        entries_after: 2,
        created_meanings: 2
      )
    end

    it "handles BATCH_SIZE correctly by flushing batches" do
      stub_const("Admin::WiktionaryProvisioningService::BATCH_SIZE", 1)
      expect { result }.to change { DictionaryEntry.count }.by(2)
                       .and change { Meaning.count }.by(2)
    end
  end
end
