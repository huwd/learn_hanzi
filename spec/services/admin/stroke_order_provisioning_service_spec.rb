require "rails_helper"

RSpec.describe Admin::StrokeOrderProvisioningService do
  describe ".call" do
    let(:tmp_dir) { Rails.root.join("tmp", "stroke_order_spec") }
    let(:graphics_path) { tmp_dir.join("graphics.txt") }

    before do
      FileUtils.mkdir_p(tmp_dir)
      File.write(
        graphics_path,
        <<~JSONL
          {"character":"语","strokes":["a","b"],"medians":[[[0,0]],[[1,1]]]}
          {"character":"学","strokes":["c"],"medians":[[[2,2]]]}
          {"character":"词","strokes":[],"medians":[]}
        JSONL
      )
    end

    after do
      FileUtils.rm_rf(tmp_dir)
      FileUtils.rm_f(Rails.root.join("log", "stroke_order_import_errors.log"))
    end

    it "imports matching single-character entries" do
      entry = create(:dictionary_entry, text: "语")

      result = described_class.call(graphics_path: graphics_path.to_s)

      expect(result).to include(entries_processed: 1, unmatched_entries: 1, malformed_rows_skipped: 1)
      expect(entry.reload.stroke_order_datum.strokes).to eq([ "a", "b" ])
      expect(entry.stroke_order_datum.medians).to eq([ [ [ 0, 0 ] ], [ [ 1, 1 ] ] ])
    end

    it "updates existing stroke order rows" do
      entry = create(:dictionary_entry, text: "语")
      create(:stroke_order_datum, dictionary_entry: entry, strokes: [ "old" ], medians: [ [ [ 9, 9 ] ] ])

      described_class.call(graphics_path: graphics_path.to_s)

      expect(entry.reload.stroke_order_datum.strokes).to eq([ "a", "b" ])
    end

    it "logs unmatched source characters" do
      create(:dictionary_entry, text: "语")

      described_class.call(graphics_path: graphics_path.to_s)

      log_body = File.read(Rails.root.join("log", "stroke_order_import_errors.log"))
      expect(log_body).to include("学")
    end

    it "raises when the graphics file is missing" do
      expect {
        described_class.call(graphics_path: tmp_dir.join("missing.txt").to_s)
      }.to raise_error(/Graphics file not found/)
    end

    it "auto-downloads the shared makemeahanzi source for the default path" do
      default_path = Admin::MakemeahanziSourceProvisioningService.graphics_path
      service = described_class.new(graphics_path: default_path.to_s)

      FileUtils.rm_f(default_path)

      expect(Admin::MakemeahanziSourceProvisioningService).to receive(:call).with(force: false) do
        FileUtils.mkdir_p(default_path.dirname)
        File.write(default_path, File.read(graphics_path))
      end

      create(:dictionary_entry, text: "语")

      result = service.call

      expect(result[:entries_processed]).to eq(1)
    ensure
      FileUtils.rm_f(default_path)
    end
  end
end
