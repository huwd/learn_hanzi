require "rails_helper"

RSpec.describe Admin::MakemeahanziSourceProvisioningService do
  describe ".call" do
    let(:dictionary_path) { described_class::DICTIONARY_PATH }
    let(:graphics_path) { described_class::GRAPHICS_PATH }

    after do
      FileUtils.rm_f(dictionary_path)
      FileUtils.rm_f(graphics_path)
    end

    it "downloads both makemeahanzi source files" do
      service = described_class.new

      expect(service).to receive(:download_file_to_tmp)
        .with(described_class::DICTIONARY_URL, dictionary_path.to_s)
        .ordered do |_url, destination|
          FileUtils.mkdir_p(File.dirname(destination))
          File.write(destination, "{}\n")
        end

      expect(service).to receive(:confirm_file_presence)
        .with("dictionary.txt", dictionary_path.dirname)
        .ordered

      expect(service).to receive(:download_file_to_tmp)
        .with(described_class::GRAPHICS_URL, graphics_path.to_s)
        .ordered do |_url, destination|
          File.write(destination, "{}\n")
        end

      expect(service).to receive(:confirm_file_presence)
        .with("graphics.txt", graphics_path.dirname)
        .ordered

      result = service.call

      expect(result[:dictionary_path]).to eq(dictionary_path.to_s)
      expect(result[:graphics_path]).to eq(graphics_path.to_s)
    end

    it "reuses files when force is false" do
      FileUtils.mkdir_p(dictionary_path.dirname)
      File.write(dictionary_path, "{}\n")
      File.write(graphics_path, "{}\n")

      service = described_class.new(force: false)

      expect(service).not_to receive(:download_file_to_tmp)

      service.call
    end
  end
end
