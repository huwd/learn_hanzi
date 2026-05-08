require "set"

module Admin
  class UnihanProvisioningService
    include ImportFilesHelper

    UNIHAN_URL = "https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip"
    UNIHAN_ZIP = Rails.root.join("tmp", "unihan", "Unihan.zip")
    UNIHAN_DIR = Rails.root.join("tmp", "unihan")
    UNIHAN_READINGS_FILE = Rails.root.join("tmp", "unihan", "Unihan_Readings.txt")
    BATCH_SIZE = 1000

    def self.call
      new.call
    end

    def call
      meanings_before = Meaning.joins(:source).where(sources: { name: "Unihan" }).count

      download_file_to_tmp(UNIHAN_URL, UNIHAN_ZIP)
      unzip_file(UNIHAN_ZIP, UNIHAN_DIR)
      confirm_file_presence("Unihan_Readings.txt", UNIHAN_DIR)

      source = find_or_sync_source

      parsed_rows = 0
      created_meanings = 0
      skipped_higher_priority = 0
      batch = []

      File.foreach(UNIHAN_READINGS_FILE, chomp: true) do |line|
        parsed = parse_kdefinition_line(line)
        next unless parsed

        parsed_rows += 1
        batch << parsed

        next unless batch.size >= BATCH_SIZE

        result = process_batch(batch, source)
        created_meanings += result[:created_meanings]
        skipped_higher_priority += result[:skipped_higher_priority]
        batch.clear
      end

      if batch.any?
        result = process_batch(batch, source)
        created_meanings += result[:created_meanings]
        skipped_higher_priority += result[:skipped_higher_priority]
        batch.clear
      end

      meanings_after = Meaning.joins(:source).where(sources: { name: "Unihan" }).count

      {
        definitions_parsed: parsed_rows,
        meanings_before: meanings_before,
        meanings_after: meanings_after,
        meanings_created: created_meanings,
        skipped_higher_priority: skipped_higher_priority
      }
    end

    private

    def find_or_sync_source
      source = Source.find_or_create_by!(name: "Unihan") do |s|
        s.url = UNIHAN_URL
        s.date_accessed = Time.zone.today
        s.priority = 50
      end

      attrs = {
        url: UNIHAN_URL,
        date_accessed: Time.zone.today,
        priority: 50
      }
      source.update!(attrs) if source.slice(*attrs.keys.map(&:to_s)) != attrs.stringify_keys
      source
    end

    def parse_kdefinition_line(line)
      return if line.start_with?("#")

      codepoint, property, value = line.split("\t", 3)
      return unless property == "kDefinition"
      return if codepoint.blank? || value.blank?

      match = codepoint.match(/\AU\+([0-9A-F]{4,6})\z/)
      return unless match

      char = [ match[1].to_i(16) ].pack("U")
      return unless char.match?(/\p{Han}/)

      definition = value.strip
      return if definition.blank?

      { word: char, definition: definition }
    end

    def process_batch(batch, source)
      words = batch.map { |row| row[:word] }.uniq

      DictionaryEntry.insert_all(
        words.map { |word| { text: word } },
        unique_by: :text
      )

      entry_id_map = DictionaryEntry.where(text: words).pluck(:text, :id).to_h
      blocked_entry_ids = entry_ids_with_higher_priority_meanings(entry_id_map.values, source.priority)

      meaning_rows = batch.filter_map do |row|
        entry_id = entry_id_map[row[:word]]
        next unless entry_id
        next if blocked_entry_ids.include?(entry_id)

        {
          dictionary_entry_id: entry_id,
          text: row[:definition],
          language: "en",
          pinyin: "Unknown",
          source_id: source.id
        }
      end

      meaning_rows.uniq! { |row| [ row[:dictionary_entry_id], row[:language], row[:text], row[:pinyin], row[:source_id] ] }

      if meaning_rows.any?
        result = Meaning.insert_all(
          meaning_rows,
          unique_by: [ :dictionary_entry_id, :language, :text, :pinyin, :source_id ]
        )
        created = result.count
      else
        created = 0
      end

      {
        created_meanings: created,
        skipped_higher_priority: batch.size - meaning_rows.size
      }
    end

    def entry_ids_with_higher_priority_meanings(entry_ids, source_priority)
      return Set.new if entry_ids.empty?

      Meaning
        .joins(:source)
        .where(dictionary_entry_id: entry_ids)
        .where(language: "en")
        .where("sources.priority < ?", source_priority)
        .distinct
        .pluck(:dictionary_entry_id)
        .to_set
    end
  end
end
