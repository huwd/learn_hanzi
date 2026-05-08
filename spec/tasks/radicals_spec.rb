require "rails_helper"
require "rake"

RSpec.describe "radicals", type: :task do
  before do
    Rake.application.rake_require("tasks/radicals")
    Rake::Task.define_task(:environment)
  end

  describe "import" do
    let(:tmp_dir) { Rails.root.join("tmp", "radicals_task_spec") }
    let(:dictionary_path) { tmp_dir.join("dictionary.txt") }
    let(:graphics_path) { tmp_dir.join("graphics.txt") }

    before do
      FileUtils.mkdir_p(tmp_dir)
      File.write(dictionary_path, "{\"character\":\"语\",\"decomposition\":\"⿰讠吾\"}\n")
      File.write(graphics_path, "{\"character\":\"吾\",\"strokes\":[\"a\"]}\n")
      create(:dictionary_entry, text: "语")
    end

    after do
      FileUtils.rm_rf(tmp_dir)
      Rake::Task["radicals:import"].reenable
    end

    it "imports radicals via the provisioning service" do
      output = capture_output do
        Rake::Task["radicals:import"].invoke(dictionary_path.to_s, graphics_path.to_s)
      end

      expect(output).to include("Entries processed: 1")
      expect(DictionaryEntryRadical.count).to eq(2)
    end

    it "raises when the dictionary file is missing" do
      expect {
        Rake::Task["radicals:import"].invoke("/tmp/missing_dictionary.txt", graphics_path.to_s)
      }.to raise_error(/Dictionary file not found/)

      Rake::Task["radicals:import"].reenable
    end
  end
end
