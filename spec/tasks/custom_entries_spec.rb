require 'rails_helper'
require 'rake'

RSpec.describe "dictionary_import:custom_entries", type: :task do
  let(:fixture_path) { Rails.root.join("spec", "fixtures", "custom_dictionary_entries.yml") }

  before do
    Rake.application.rake_require("tasks/dictionary_import")
    Rake::Task.define_task(:environment)
  end

  after do
    Rake::Task["dictionary_import:custom_entries"].reenable
  end

  def run_task(path = fixture_path)
    capture_output { Rake::Task["dictionary_import:custom_entries"].invoke(path.to_s) }
  end

  context "when the file does not exist" do
    it "prints an error and exits without creating records" do
      output = capture_output do
        expect {
          Rake::Task["dictionary_import:custom_entries"].invoke("/nonexistent.yml")
        }.to raise_error(SystemExit)
      end
      expect(output).to include("File not found")
      expect(DictionaryEntry.count).to eq(0)
    end
  end

  context "with a valid YAML file" do
    it "creates a DictionaryEntry for each entry in the file" do
      expect { run_task }.to change(DictionaryEntry, :count).by(3)
      expect(DictionaryEntry.find_by(text: "打篮球")).to be_present
      expect(DictionaryEntry.find_by(text: "弹钢琴")).to be_present
      expect(DictionaryEntry.find_by(text: "红酒")).to be_present
    end

    it "creates Meaning records with correct text, pinyin, and language" do
      run_task
      meaning = DictionaryEntry.find_by!(text: "打篮球").meanings.first
      expect(meaning.text).to eq("to play basketball")
      expect(meaning.pinyin).to eq("dǎ lánqiú")
      expect(meaning.language).to eq("en")
    end

    it "attributes meanings to a 'learn_hanzi' source" do
      run_task
      source = DictionaryEntry.find_by!(text: "红酒").meanings.first.source
      expect(source.name).to eq("learn_hanzi")
    end

    describe "idempotency" do
      it "does not create duplicate DictionaryEntries on re-run" do
        run_task
        Rake::Task["dictionary_import:custom_entries"].reenable
        expect { run_task }.not_to change(DictionaryEntry, :count)
      end

      it "does not create duplicate Meanings on re-run" do
        run_task
        Rake::Task["dictionary_import:custom_entries"].reenable
        expect { run_task }.not_to change(Meaning, :count)
      end
    end

    it "prints a completion summary" do
      output = run_task
      expect(output).to include("Done!")
    end
  end
end
