require "rails_helper"
require "rake"

RSpec.describe "makemeahanzi", type: :task do
  before do
    Rake.application.rake_require("tasks/makemeahanzi")
    Rake::Task.define_task(:environment)
  end

  describe "download" do
    let(:output_dir) { Rails.root.join("tmp", "makemeahanzi") }
    let(:dictionary_path) { output_dir.join("dictionary.txt") }
    let(:graphics_path) { output_dir.join("graphics.txt") }

    before do
      stub_request(:get, "https://raw.githubusercontent.com/skishore/makemeahanzi/master/dictionary.txt")
        .to_return(body: "{\"character\":\"语\",\"decomposition\":\"⿰讠吾\"}\n")

      stub_request(:get, "https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt")
        .to_return(body: "{\"character\":\"吾\",\"strokes\":[\"a\"]}\n")

      FileUtils.rm_rf(output_dir)
    end

    after do
      FileUtils.rm_rf(output_dir)
      Rake::Task["makemeahanzi:download"].reenable
    end

    it "downloads dictionary.txt and graphics.txt" do
      silence_output { Rake::Task["makemeahanzi:download"].invoke }

      expect(File.exist?(dictionary_path)).to be(true)
      expect(File.exist?(graphics_path)).to be(true)
    end
  end
end
