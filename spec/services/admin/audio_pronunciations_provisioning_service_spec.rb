require "rails_helper"

RSpec.describe Admin::AudioPronunciationsProvisioningService, type: :service do
  describe "#call" do
    let!(:hsk_tag) { create(:tag, name: "HSK 1", category: "HSK") }
    let!(:matched_entry) { create(:dictionary_entry, text: "苹果").tap { |entry| entry.tags << hsk_tag } }
    let!(:unmatched_entry) { create(:dictionary_entry, text: "香蕉").tap { |entry| entry.tags << hsk_tag } }
    let!(:out_of_scope_entry) { create(:dictionary_entry, text: "西瓜") }

    it "imports matching audio and logs unmatched HSK 1-4 entries" do
      Dir.mktmpdir do |tmpdir|
        source_archive = File.join(tmpdir, "source.zip")
        build_archive(source_archive, {
          "HSK-3.0-main/New HSK (2025)/Audio/cmn-苹果.mp3" => "audio data"
        })

        archive_path = File.join(tmpdir, "download.zip")
        extract_dir = File.join(tmpdir, "extract")
        log_path = File.join(tmpdir, "audio_import_errors.log")
        service = described_class.new(
          archive_path: archive_path,
          extract_dir: extract_dir,
          log_path: log_path
        )

        allow(service).to receive(:download_file_to_tmp) do |_url, destination|
          FileUtils.cp(source_archive, destination)
        end

        result = service.call

        expect(result[:imported]).to eq(1)
        expect(result[:unmatched]).to eq(1)
        expect(AudioPronunciation.count).to eq(1)

        pronunciation = AudioPronunciation.first
        expect(pronunciation.dictionary_entry).to eq(matched_entry)
        expect(pronunciation.source).to eq(AudioPronunciation::SOURCE_KRMANIK)
        expect(pronunciation.locale).to eq(AudioPronunciation::LOCALE_ZH_CN)
        expect(pronunciation.audio).to be_attached

        log_contents = File.read(log_path)
        expect(log_contents).to include(unmatched_entry.text)
        expect(log_contents).not_to include(out_of_scope_entry.text)
      end
    end
  end

  def build_archive(path, entries)
    Zip::File.open(path, create: true) do |zip_file|
      entries.each do |entry_path, contents|
        zip_file.get_output_stream(entry_path) { |stream| stream.write(contents) }
      end
    end
  end
end
