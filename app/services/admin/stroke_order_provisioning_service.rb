require "json"

module Admin
  class StrokeOrderProvisioningService
    BATCH_SIZE = 500
    SOURCE_NAME = "makemeahanzi".freeze
    ERROR_LOG_PATH = Rails.root.join("log", "stroke_order_import_errors.log")

    def self.call(graphics_path: Admin::MakemeahanziSourceProvisioningService.graphics_path.to_s)
      new(graphics_path: graphics_path).call
    end

    def initialize(graphics_path:)
      @graphics_path = graphics_path
      @unmatched_characters = []
      @malformed_rows_skipped = 0
    end

    def call
      ensure_source_file!

      rows = parsed_rows
      entry_ids_by_text = dictionary_entry_ids_by_text(rows.map { |row| row[:character] })
      upsert_rows = build_upsert_rows(rows, entry_ids_by_text)

      StrokeOrderDatum.upsert_all(upsert_rows, unique_by: :index_stroke_order_data_on_dictionary_entry_id) if upsert_rows.any?
      log_unmatched_characters

      {
        entries_processed: upsert_rows.size,
        unmatched_entries: @unmatched_characters.size,
        malformed_rows_skipped: @malformed_rows_skipped
      }
    end

    private

    def ensure_source_file!
      return if File.exist?(@graphics_path)

      raise "Graphics file not found at #{@graphics_path}. Run `bin/rails makemeahanzi:download` first."
    end

    def parsed_rows
      rows = []

      File.foreach(@graphics_path, chomp: true) do |line|
        payload = JSON.parse(line)
        character = payload["character"].to_s
        strokes = payload["strokes"]
        medians = payload["medians"]

        next unless character.match?(/\A\p{Han}\z/u)
        unless strokes.is_a?(Array) && strokes.any? && medians.is_a?(Array) && medians.any?
          @malformed_rows_skipped += 1
          next
        end

        rows << {
          character: character,
          strokes: strokes,
          medians: medians
        }
      rescue JSON::ParserError
        @malformed_rows_skipped += 1
        next
      end

      rows
    end

    def dictionary_entry_ids_by_text(texts)
      texts.uniq.each_slice(BATCH_SIZE).each_with_object({}) do |batch, lookup|
        lookup.merge!(DictionaryEntry.where(text: batch).pluck(:text, :id).to_h)
      end
    end

    def build_upsert_rows(rows, entry_ids_by_text)
      timestamp = Time.current

      rows.filter_map do |row|
        dictionary_entry_id = entry_ids_by_text[row[:character]]

        unless dictionary_entry_id
          @unmatched_characters << row[:character]
          next
        end

        {
          dictionary_entry_id: dictionary_entry_id,
          strokes: row[:strokes],
          medians: row[:medians],
          source: SOURCE_NAME,
          created_at: timestamp,
          updated_at: timestamp
        }
      end
    end

    def log_unmatched_characters
      return if @unmatched_characters.empty?

      FileUtils.mkdir_p(ERROR_LOG_PATH.dirname)

      File.open(ERROR_LOG_PATH, "a") do |file|
        @unmatched_characters.uniq.each do |character|
          file.puts(character)
        end
      end
    end
  end
end
