require 'rails_helper'
require 'rake'

RSpec.describe "dictionary_import", type: :task do
  before do
    Rake.application.rake_require("tasks/dictionary_import")
    Rake::Task.define_task(:environment)
  end

  describe "cc_cedict" do
    let(:fixture_file_path) { Rails.root.join("spec", "fixtures", "cedict_ts.u8") }
    let(:default_file_path) { Rails.root.join("tmp", "cedict_ts.u8").to_s }
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
      output = capture_output { Rake::Task["dictionary_import:cc_cedict"].invoke(fixture_file_path) }

      expect(output).to include("Processing CC-CEDICT file at #{fixture_file_path}")
    end

    it "displays progress with a fixed-width percentage (2 decimal places) to prevent terminal jitter" do
      # Float#round(2) drops trailing zeros: 0.10 becomes 0.1, producing a
      # variable-width string that leaves ghost characters when \r overwrites it.
      # format("%6.2f%%") always emits exactly 2 decimal places.
      output = capture_output { Rake::Task["dictionary_import:cc_cedict"].invoke(fixture_file_path) }
      percentages = output.scan(/Processing:\s*([\d. ]+)%/).flatten
      expect(percentages).not_to be_empty
      expect(percentages).to all(match(/\A[\d ]+\.\d{2}\z/))
    end

    it "calls find_or_create_cc_cedict_source" do
      # Mock the module method directly
      allow(DictionaryImportHelper).to receive(:find_or_create_cc_cedict_source)
        .and_return(
          Source.create!(
            name: "CC-CEDICT",
            url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip",
            date_accessed: Date.today
          )
        )

      # Expect the method to be called with the correct arguments
      expect(DictionaryImportHelper).to receive(:find_or_create_cc_cedict_source).with(
        "CC-CEDICT",
        "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
      )

      silence_output do
        Rake::Task["dictionary_import:cc_cedict"].invoke(
          fixture_file_path
        )
      end
    end
  end
end
