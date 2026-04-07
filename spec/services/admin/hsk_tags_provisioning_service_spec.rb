require "rails_helper"

RSpec.describe Admin::HskTagsProvisioningService do
  describe ".call" do
    subject(:result) { described_class.call }

    before do
      allow_any_instance_of(described_class).to receive(:download_file_to_tmp)
      allow_any_instance_of(described_class).to receive(:confirm_file_presence)
      allow_any_instance_of(described_class).to receive(:hsk_2_files).and_return([])
      allow_any_instance_of(described_class).to receive(:hsk_3_files).and_return([])
    end

    it "downloads HSK 2 files" do
      expect_any_instance_of(described_class).to receive(:download_file_to_tmp).at_least(:once)
      result
    end

    it "returns a hash with tags_created, entries_tagged, and skipped counts" do
      expect(result).to include(:tags_created, :entries_tagged, :skipped)
    end

    it "returns integer counts" do
      expect(result[:tags_created]).to be_a(Integer)
      expect(result[:entries_tagged]).to be_a(Integer)
      expect(result[:skipped]).to be_a(Integer)
    end

    context "when HSK 2 files are present" do
      let(:fake_hsk2_path) { Rails.root.join("tmp", "hsk_2", "1.min.json") }
      let(:hsk2_json) { [ { "s" => "你好" }, { "s" => "再见" } ].to_json }

      before do
        allow_any_instance_of(described_class)
          .to receive(:hsk_2_files).and_return([ fake_hsk2_path.to_s ])
        allow(File).to receive(:read).with(fake_hsk2_path.to_s).and_return(hsk2_json)
      end

      it "creates a tag for the HSK 2 level file" do
        expect { result }.to change { Tag.count }.by_at_least(1)
      end

      it "increments tags_created" do
        expect(result[:tags_created]).to be > 0
      end
    end

    context "when HSK 3 TXT files are present" do
      let(:fake_hsk3_path) { Rails.root.join("tmp", "hsk_3", "HSK 1.txt") }

      before do
        allow_any_instance_of(described_class)
          .to receive(:hsk_3_files).and_return([ fake_hsk3_path.to_s ])
        allow(File).to receive(:readlines)
          .with(fake_hsk3_path.to_s, chomp: true).and_return([ "你", "好" ])
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?)
          .with(a_string_including("HSK 1.tsv")).and_return(false)
      end

      it "creates a tag for the HSK 3 level" do
        expect { result }.to change { Tag.count }.by_at_least(1)
      end
    end
  end
end
