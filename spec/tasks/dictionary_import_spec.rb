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

    it "reports elapsed time on completion" do
      output = capture_output { Rake::Task["dictionary_import:cc_cedict"].invoke(fixture_file_path) }
      expect(output).to match(/Completed in [\d.]+s/)
    end

    it "calls find_or_create_cc_cedict_source with the correct arguments" do
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

    it "calls find_or_create_cc_cedict_source exactly once regardless of how many entries the file has" do
      # Pre-optimisation: source was looked up inside find_or_create_dictionary_entry,
      # so it was called once per entry. Post-optimisation: looked up once before the
      # loop and the Source object is passed directly to the helper.
      expect(DictionaryImportHelper).to receive(:find_or_create_cc_cedict_source).once.and_call_original

      silence_output { Rake::Task["dictionary_import:cc_cedict"].invoke(fixture_file_path) }
    end

    it "uses batch_import_cc_cedict_lines to insert entries" do
      expect(DictionaryImportHelper).to receive(:batch_import_cc_cedict_lines).and_call_original

      silence_output { Rake::Task["dictionary_import:cc_cedict"].invoke(fixture_file_path) }
    end

    it "imports all entries from the fixture file" do
      silence_output { Rake::Task["dictionary_import:cc_cedict"].invoke(fixture_file_path) }

      # Fixture has 24 non-comment CC-CEDICT lines
      expect(DictionaryEntry.count).to eq(24)
    end
  end
end
