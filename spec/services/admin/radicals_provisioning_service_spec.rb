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

    it "downloads source files when paths are missing" do
      service = described_class.new(
        dictionary_path: dictionary_path.to_s,
        graphics_path: graphics_path.to_s
      )

      FileUtils.rm_f(dictionary_path)
      FileUtils.rm_f(graphics_path)

      expect(service).to receive(:download_file_to_tmp)
        .with(Admin::MakemeahanziSourceProvisioningService::DICTIONARY_URL, dictionary_path.to_s)
        .ordered do |_url, dest|
          File.write(dest, "{\"character\":\"语\",\"decomposition\":\"⿰讠吾\"}\n")
        end

      expect(service).to receive(:confirm_file_presence)
        .with("dictionary.txt", dictionary_path.dirname)
        .ordered

      expect(service).to receive(:download_file_to_tmp)
        .with(Admin::MakemeahanziSourceProvisioningService::GRAPHICS_URL, graphics_path.to_s)
        .ordered do |_url, dest|
          File.write(dest, "{\"character\":\"吾\",\"strokes\":[\"a\"]}\n")
        end

      expect(service).to receive(:confirm_file_presence)
        .with("graphics.txt", graphics_path.dirname)
        .ordered

      result = service.call
      expect(result).to include(entries_processed: 1, associations_created: 2)
    end

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

    it "imports in insert batches for larger datasets" do
      many_entries = 200.times.map do |idx|
        character = [ 0x4E00 + idx ].pack("U")
        create(:dictionary_entry, text: character)
        { "character" => character, "decomposition" => "⿰讠吾" }
      end

      File.write(
        dictionary_path,
        many_entries.map(&:to_json).join("\n") + "\n"
      )

      result = described_class.call(dictionary_path: dictionary_path.to_s, graphics_path: graphics_path.to_s)

      expect(result).to include(entries_processed: 200, associations_created: 400)
      expect(DictionaryEntryRadical.count).to eq(400)
    end
  end
end
