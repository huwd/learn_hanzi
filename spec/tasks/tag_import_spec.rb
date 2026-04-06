require 'rails_helper'
require 'rake'
require 'tmpdir'

RSpec.describe "tag_import", type: :task do
  before do
    Rake.application.rake_require("tasks/tag_import")
    Rake::Task.define_task(:environment)
  end

  shared_context "hsk 2 fixture directory" do
    let(:fixture_dir) do
      dir = Dir.mktmpdir("hsk_import")
      FileUtils.cp(Rails.root.join("spec", "fixtures", "hsk_sample.json"),
                   File.join(dir, "1.min.json"))
      dir
    end

    after { FileUtils.rm_rf(fixture_dir) }
  end

  shared_context "hsk 3 fixture directory" do
    let(:fixture_dir) do
      dir = Dir.mktmpdir("hsk_import")
      FileUtils.cp(Rails.root.join("spec", "fixtures", "hsk_sample.txt"),
                   File.join(dir, "HSK 1.txt"))
      dir
    end

    after { FileUtils.rm_rf(fixture_dir) }
  end

  describe "hsk_2" do
    include_context "hsk 2 fixture directory"

    let!(:entry_ai)  { create(:dictionary_entry, text: "爱") }
    let!(:entry_hao) { create(:dictionary_entry, text: "好") }

    after { Rake::Task["tag_import:hsk_2"].reenable }

    it "creates HSK 2.0 parent tag hierarchy" do
      silence_output { Rake::Task["tag_import:hsk_2"].invoke(fixture_dir) }

      expect(Tag.find_by(name: "HSK")).to be_present
      expect(Tag.find_by(name: "HSK 2.0")).to be_present
    end

    it "associates matching dictionary entries with the lesson tag" do
      silence_output { Rake::Task["tag_import:hsk_2"].invoke(fixture_dir) }

      lesson_tag = Tag.find_by(name: "HSK 1")
      expect(entry_ai.tags.reload).to include(lesson_tag)
      expect(entry_hao.tags.reload).to include(lesson_tag)
    end

    it "uses batch_associate_entries_to_tag" do
      expect(TagImportHelper).to receive(:batch_associate_entries_to_tag).and_call_original
      silence_output { Rake::Task["tag_import:hsk_2"].invoke(fixture_dir) }
    end

    it "reports elapsed time on completion" do
      output = capture_output { Rake::Task["tag_import:hsk_2"].invoke(fixture_dir) }
      expect(output).to match(/Completed in [\d.]+s/)
    end
  end

  describe "hsk_3" do
    include_context "hsk 3 fixture directory"

    let!(:entry_ai)  { create(:dictionary_entry, text: "爱") }
    let!(:entry_hao) { create(:dictionary_entry, text: "好") }

    after { Rake::Task["tag_import:hsk_3"].reenable }

    it "creates HSK 3.0 parent tag hierarchy" do
      silence_output { Rake::Task["tag_import:hsk_3"].invoke(fixture_dir) }

      expect(Tag.find_by(name: "HSK")).to be_present
      expect(Tag.find_by(name: "HSK 3.0")).to be_present
    end

    it "associates matching dictionary entries with the lesson tag" do
      silence_output { Rake::Task["tag_import:hsk_3"].invoke(fixture_dir) }

      lesson_tag = Tag.find_by(name: "HSK 1")
      expect(entry_ai.tags.reload).to include(lesson_tag)
      expect(entry_hao.tags.reload).to include(lesson_tag)
    end

    it "skips words not in the dictionary and reports the count" do
      output = capture_output { Rake::Task["tag_import:hsk_3"].invoke(fixture_dir) }

      expect(output).to match(/1 entr(?:y|ies) skipped/)
    end

    it "reports elapsed time on completion" do
      output = capture_output { Rake::Task["tag_import:hsk_3"].invoke(fixture_dir) }
      expect(output).to match(/Completed in [\d.]+s/)
    end
  end
end
