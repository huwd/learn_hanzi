require "rails_helper"

RSpec.describe Admin::RadicalsProvisioningService do
  describe ".call" do
    let(:tmp_dir) { Rails.root.join("tmp", "radicals_spec") }
    let(:dictionary_path) { tmp_dir.join("dictionary.txt") }
    let(:graphics_path) { tmp_dir.join("graphics.txt") }

    let!(:entry) { create(:dictionary_entry, text: "语") }
    let!(:component_entry) { create(:dictionary_entry, text: "吾") }

    before do
      FileUtils.mkdir_p(tmp_dir)

      File.write(
        dictionary_path,
        <<~JSONL
          {"character":"语","decomposition":"⿰讠吾"}
        JSONL
      )

      File.write(
        graphics_path,
        <<~JSONL
          {"character":"讠","strokes":["a","b"]}
          {"character":"吾","strokes":["a","b","c","d","e","f","g"]}
        JSONL
      )
    end

    after { FileUtils.rm_rf(tmp_dir) }

    it "creates radicals and dictionary entry associations" do
      result = described_class.call(dictionary_path: dictionary_path.to_s, graphics_path: graphics_path.to_s)

      expect(result).to include(entries_processed: 1, radicals_created: 2, associations_created: 2)
      expect(entry.reload.dictionary_entry_radicals.order(:position).map { |row| row.radical.character }).to eq([ "讠", "吾" ])
    end

    it "populates radical meanings from existing dictionary entries when available" do
      result = described_class.call(dictionary_path: dictionary_path.to_s, graphics_path: graphics_path.to_s)

      expect(result).to include(entries_processed: 1)
      expect(Radical.find_by!(character: "讠").meaning).to be_nil
      expect(Radical.find_by!(character: "吾").meaning).to eq(component_entry.flashcard_primary_meaning.text)
    end

    it "replaces existing rows for repeated imports" do
      described_class.call(dictionary_path: dictionary_path.to_s, graphics_path: graphics_path.to_s)

      result = described_class.call(dictionary_path: dictionary_path.to_s, graphics_path: graphics_path.to_s)

      expect(result).to include(entries_processed: 1, associations_created: 2)
      expect(entry.reload.dictionary_entry_radicals.order(:position).map { |row| row.radical.character }).to eq([ "讠", "吾" ])
    end
  end
end
