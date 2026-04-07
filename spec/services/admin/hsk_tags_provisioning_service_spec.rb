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
  end
end
