require "rails_helper"
require "rake"

RSpec.describe "frequency", type: :task do
  before do
    Rake.application.rake_require("tasks/frequency")
    Rake::Task.define_task(:environment)
  end

  describe "download" do
    let(:file_path) { Rails.root.join("tmp", "frequency", "SUBTLEX_CH_131210_CE.utf8") }

    before do
      stub_request(:get, "https://raw.githubusercontent.com/krmanik/HSK-3.0/main/Scripts%20and%20data/SUBTLEX_CH_131210_CE.utf8")
        .to_return(body: "Word\tWCount\tW.million\tDominant.PoS\n你好\t10\t1.0\tn\n")
      FileUtils.rm_f(file_path)
    end

    after do
      FileUtils.rm_f(file_path)
      Rake::Task["frequency:download"].reenable
    end

    it "downloads the SUBTLEX file to tmp/frequency" do
      silence_output { Rake::Task["frequency:download"].invoke }
      expect(File.exist?(file_path)).to be(true)
    end
  end

  describe "import" do
    let(:fixture_file_path) { Rails.root.join("spec", "fixtures", "subtlex_sample.tsv") }

    let!(:entry_nihao) { create(:dictionary_entry, text: "你好") }
    let!(:entry_ai) { create(:dictionary_entry, text: "爱") }

    after { Rake::Task["frequency:import"].reenable }

    it "assigns lower ranks to higher W.million values" do
      silence_output { Rake::Task["frequency:import"].invoke(fixture_file_path.to_s) }

      expect(entry_nihao.reload.frequency_rank).to eq(1)
      expect(entry_ai.reload.frequency_rank).to eq(2)
    end

    it "prints parsed and updated counts" do
      output = capture_output { Rake::Task["frequency:import"].invoke(fixture_file_path.to_s) }

      expect(output).to include("3 unique words parsed")
      expect(output).to include("2 dictionary entries updated")
      expect(output).to include("1 words missing from dictionary")
    end
  end
end
