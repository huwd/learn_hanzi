require 'rails_helper'
require 'rake'

RSpec.describe "download", type: :task do
  before do
    Rake.application.rake_require("tasks/dictionary_download")
    Rake::Task.define_task(:environment)
  end

  describe "cc_cedict" do
    let(:temp_zip_path) { Rails.root.join("tmp", "cedict.zip") }
    let(:unzip_dir) { Rails.root.join("tmp", "cedict") }
    let(:mock_zip) { Rails.root.join("spec", "fixtures", "cedict.zip") }

    before do
      # Stub the file download
      stub_request(:get, "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
        .to_return(body: File.new(mock_zip))

      # Ensure clean state for temp files
      FileUtils.rm_rf(temp_zip_path) if File.exist?(temp_zip_path)
      FileUtils.rm_rf(unzip_dir)
    end

    after do
      # Ensure clean state for temp files
      FileUtils.rm_rf(temp_zip_path) if File.exist?(temp_zip_path)
      FileUtils.rm_rf(unzip_dir)

      # Re-enable the task for subsequent tests
      Rake::Task["dictionary_download:cc_cedict"].reenable
    end

    it "downloads the ZIP file to tmp" do
      silence_output { Rake::Task["dictionary_download:cc_cedict"].invoke }
      expect(File.exist?(temp_zip_path)).to be_truthy
    end

    it "unzips the ZIP file to the expected directory" do
      silence_output { Rake::Task["dictionary_download:cc_cedict"].invoke }
      expect(Dir.exist?(unzip_dir)).to be_truthy
      extracted_files = Dir[unzip_dir.join("*")]
      expect(extracted_files).to_not be_empty
    end

    it "confirms the presence of the CEDICT file" do
      silence_output { Rake::Task["dictionary_download:cc_cedict"].invoke }
      cedict_file = Dir[unzip_dir.join("*cedict*")].first
      expect(cedict_file).to be_present
    end
  end
end
