require "rails_helper"

RSpec.describe Admin::CcCedictProvisioningService do
  describe ".call" do
    subject(:result) { described_class.call }

    before do
      allow_any_instance_of(described_class).to receive(:download_file_to_tmp)
      allow_any_instance_of(described_class).to receive(:unzip_file)
      allow_any_instance_of(described_class).to receive(:confirm_file_presence)
      allow_any_instance_of(described_class)
        .to receive(:find_or_create_cc_cedict_source).and_return(build(:source))
      allow_any_instance_of(described_class).to receive(:batch_import_cc_cedict_lines)
      allow(File).to receive(:readlines).and_return([])
    end

    it "downloads the CC-CEDICT file" do
      expect_any_instance_of(described_class).to receive(:download_file_to_tmp).once
      result
    end

    it "calls batch_import_cc_cedict_lines" do
      expect_any_instance_of(described_class).to receive(:batch_import_cc_cedict_lines).once
      result
    end

    it "returns a hash with entries_before and entries_after counts" do
      expect(result).to include(:entries_before, :entries_after)
    end

    it "returns integer counts" do
      expect(result[:entries_before]).to be_a(Integer)
      expect(result[:entries_after]).to be_a(Integer)
    end
  end
end
