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
      @malformed_rows_skipped = 0
      @entries_processed = 0
      @unmatched_entries = 0
    end

    def call
      ensure_source_file!

      process_rows_in_batches

      {
        entries_processed: @entries_processed,
        unmatched_entries: @unmatched_entries,
        malformed_rows_skipped: @malformed_rows_skipped
      }
    end

    private

    def ensure_source_file!
      return if File.exist?(@graphics_path)

      if using_default_graphics_path?
        Admin::MakemeahanziSourceProvisioningService.call(force: false)
        return if File.exist?(@graphics_path)
      end

      raise "Graphics file not found at #{@graphics_path}. Run `bin/rails makemeahanzi:download` first."
    end

    def using_default_graphics_path?
      @graphics_path.to_s == Admin::MakemeahanziSourceProvisioningService.graphics_path.to_s
    end

    def process_rows_in_batches
      rows = []

      File.foreach(@graphics_path, chomp: true) do |line|
        row = parse_row(line)
        next unless row

        rows << row
        persist_batch(rows) if rows.size >= BATCH_SIZE
      end

      persist_batch(rows)
    end

    def parse_row(line)
      payload = JSON.parse(line)
      character = payload["character"].to_s
      strokes = payload["strokes"]
      medians = payload["medians"]

      return unless character.match?(/\A\p{Han}\z/u)

      unless strokes.is_a?(Array) && strokes.any? && medians.is_a?(Array) && medians.any?
        @malformed_rows_skipped += 1
        return
      end

      {
        character: character,
        strokes: strokes,
        medians: medians
      }
    rescue JSON::ParserError
      @malformed_rows_skipped += 1
      nil
    end

    def persist_batch(rows)
      return if rows.empty?

      entry_ids_by_text = dictionary_entry_ids_by_text(rows.map { |row| row[:character] })
      upsert_rows, unmatched_characters = build_upsert_rows(rows, entry_ids_by_text)

      if upsert_rows.any?
        StrokeOrderDatum.upsert_all(
          upsert_rows,
          unique_by: :index_stroke_order_data_on_dictionary_entry_id,
          update_only: %i[strokes medians source updated_at]
        )
        @entries_processed += upsert_rows.size
      end

      @unmatched_entries += unmatched_characters.size
      log_unmatched_characters(unmatched_characters)
      rows.clear
    end

    def dictionary_entry_ids_by_text(texts)
      DictionaryEntry.where(text: texts.uniq).pluck(:text, :id).to_h
    end

    def build_upsert_rows(rows, entry_ids_by_text)
      timestamp = Time.current
      unmatched_characters = []

      upsert_rows = rows.filter_map do |row|
        dictionary_entry_id = entry_ids_by_text[row[:character]]

        unless dictionary_entry_id
          unmatched_characters << row[:character]
          next
        end

        {
          dictionary_entry_id: dictionary_entry_id,
          strokes: JSON.generate(row[:strokes]),
          medians: JSON.generate(row[:medians]),
          source: SOURCE_NAME,
          created_at: timestamp,
          updated_at: timestamp
        }
      end

      [ upsert_rows, unmatched_characters ]
    end

    def log_unmatched_characters(unmatched_characters)
      return if unmatched_characters.empty?

      FileUtils.mkdir_p(ERROR_LOG_PATH.dirname)

      File.open(ERROR_LOG_PATH, "a") do |file|
        unmatched_characters.uniq.each do |character|
          file.puts(character)
        end
      end
    end
  end
end
