module Admin
  class AudioPronunciationsProvisioningService
    include ImportFilesHelper

    ARCHIVE_URL = "https://codeload.github.com/krmanik/HSK-3.0/zip/refs/heads/main"
    ARCHIVE_PATH = Rails.root.join("tmp", "audio", "krmanik_hsk_3_0.zip")
    EXTRACT_DIR = Rails.root.join("tmp", "audio", "krmanik_hsk_3_0")
    LOG_PATH = Rails.root.join("log", "audio_import_errors.log")
    AUDIO_DIR_GLOB = "**/New HSK (2025)/Audio".freeze
    TARGET_LEVELS = [ "HSK 1", "HSK 2", "HSK 3", "HSK 4" ].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def self.download(**kwargs)
      new(**kwargs).download
    end

    def self.import(**kwargs)
      new(**kwargs).import
    end

    def initialize(
      archive_url: ARCHIVE_URL,
      archive_path: ARCHIVE_PATH,
      extract_dir: EXTRACT_DIR,
      log_path: LOG_PATH,
      target_levels: TARGET_LEVELS,
      source_key: AudioPronunciation::SOURCE_KRMANIK,
      locale: AudioPronunciation::LOCALE_ZH_CN
    )
      @archive_url = archive_url
      @archive_path = Pathname(archive_path)
      @extract_dir = Pathname(extract_dir)
      @log_path = Pathname(log_path)
      @target_levels = target_levels
      @source_key = source_key
      @locale = locale
    end

    def call
      download.merge(import)
    end

    def download
      download_file_to_tmp(@archive_url, @archive_path.to_s)
      FileUtils.rm_rf(@extract_dir)
      unzip_file(@archive_path, @extract_dir)

      {
        archive_path: @archive_path.to_s,
        audio_dir: resolved_audio_dir.to_s,
        downloaded_files: audio_lookup.size
      }
    end

    def import
      imported = 0
      updated = 0
      unchanged = 0
      unmatched_entries = []
      lookup = audio_lookup

      target_entries.find_each do |entry|
        file_path = lookup[entry.text]

        unless file_path
          unmatched_entries << entry
          next
        end

        result = import_file_for(entry, file_path)
        imported += 1 if result == :created
        updated += 1 if result == :updated
        unchanged += 1 if result == :unchanged
      end

      write_unmatched_log(unmatched_entries)

      {
        imported: imported,
        updated: updated,
        unchanged: unchanged,
        unmatched: unmatched_entries.size,
        source: @source_key,
        locale: @locale
      }
    end

    private

    def target_entries
      DictionaryEntry.joins(:tags)
                     .where(tags: { category: "HSK", name: @target_levels })
                     .distinct
    end

    def import_file_for(entry, file_path)
      pronunciation = AudioPronunciation.find_or_initialize_by(
        dictionary_entry: entry,
        source: @source_key,
        locale: @locale
      )
      status = pronunciation.new_record? ? :created : :updated

      if same_attachment?(pronunciation, file_path)
        return :unchanged
      end

      pronunciation.audio.purge if pronunciation.audio.attached?

      pronunciation.audio.attach(
        io: StringIO.new(File.binread(file_path)),
        filename: File.basename(file_path),
        content_type: "audio/mpeg"
      )

      pronunciation.save!
      status
    end

    def same_attachment?(pronunciation, file_path)
      return false unless pronunciation.audio.attached?

      pronunciation.audio.filename.to_s == File.basename(file_path) &&
        pronunciation.audio.blob.byte_size == File.size(file_path)
    end

    def audio_lookup
      @audio_lookup ||= Dir.glob(resolved_audio_dir.join("*.mp3")).each_with_object({}) do |path, lookup|
        basename = File.basename(path, ".mp3")
        next unless basename.start_with?("cmn-")

        lookup[basename.delete_prefix("cmn-")] = path
      end
    end

    def resolved_audio_dir
      @resolved_audio_dir ||= begin
        match = Dir.glob(@extract_dir.join(AUDIO_DIR_GLOB)).first
        raise "Audio directory not found in #{@extract_dir}" if match.blank?

        Pathname(match)
      end
    end

    def write_unmatched_log(unmatched_entries)
      FileUtils.mkdir_p(@log_path.dirname)
      lines = unmatched_entries.map { |entry| "#{entry.id}\t#{entry.text}" }
      File.write(@log_path, lines.join("\n"))
    end
  end
end
