require 'rails_helper'
require 'rake'

RSpec.describe "dictionary_import", type: :task do
  before do
    Rake.application.rake_require("tasks/dictionary_import")
    Rake::Task.define_task(:environment)
  end

  describe "cc_cedict" do
    let(:fixture_file_path) { Rails.root.join("spec", "fixtures", "cedict_ts.u8") }
    let(:default_file_path) { Rails.root.join("tmp", "cedict_ts.u8").to_s}
    let(:temp_zip_path) { Rails.root.join("tmp", "cedict.zip") }
    let(:unzip_dir) { Rails.root.join("tmp", "cedict") }
    let(:mock_zip) { Rails.root.join("spec", "fixtures", "cedict.zip") }

    before do
      DictionaryEntry.delete_all
      Meaning.delete_all
      Source.delete_all
      # Stub the file download
      stub_request(:get, "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip")
        .to_return(body: File.new(mock_zip))

      # Ensure clean state for temp files
      FileUtils.rm_rf(temp_zip_path) if File.exist?(temp_zip_path)
      FileUtils.rm_rf(unzip_dir)
    end

    after do
      Rake::Task["dictionary_import:cc_cedict"].reenable
    end

    it "uses the provided file path if given" do
      test_file_path = "spec/fixtures/test_cedict.u8"
      output = capture_output { Rake::Task["dictionary_import:cc_cedict"].invoke(test_file_path) }

      expect(output).to include("Processing CC-CEDICT file at #{test_file_path}")
    end

    it "defaults to tmp/cedict_ts.u8 if no file path is provided" do
      output = capture_output { Rake::Task["dictionary_import:cc_cedict"].invoke }

      expect(output).to include("No file path provided, defaulting to tmp/cedict_ts.u8")
      expect(output).to include("Processing CC-CEDICT file at #{default_file_path}")
    end

    it "calls find_or_create_cc_cedict_source" do
      expect(self).to receive(:find_or_create_cc_cedict_source).with(
        "CC-CEDICT",
        "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
      ).and_call_original

      silence_output { Rake::Task["dictionary_import:cc_cedict"].invoke }
    end

    it "invokes the download task if the default file is missing" do
      allow(File).to receive(:exist?).with(default_file_path).and_return(false)

      expect(Rake::Task["dictionary_import:download_cc_cedict"]).to receive(:invoke)

      Rake::Task["dictionary_import:cc_cedict"].invoke
    end

    it "does not invoke the download task if the default file exists" do
      allow(File).to receive(:exist?).with(default_file_path).and_return(true)

      expect(Rake::Task["dictionary_import:download_cc_cedict"]).not_to receive(:invoke)

      Rake::Task["dictionary_import:cc_cedict"].invoke
    end
  end
end
