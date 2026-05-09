require "json"
require "set"

module Admin
  class RadicalsProvisioningService
    include ImportFilesHelper

    BATCH_SIZE = 900
    INSERT_BATCH_SIZE = 150

    DICTIONARY_PATH = Admin::MakemeahanziSourceProvisioningService.dictionary_path
    GRAPHICS_PATH = Admin::MakemeahanziSourceProvisioningService.graphics_path

    def self.call(dictionary_path: DICTIONARY_PATH.to_s, graphics_path: GRAPHICS_PATH.to_s)
      new(dictionary_path:, graphics_path:).call
    end

    def initialize(dictionary_path:, graphics_path:)
      @dictionary_path = dictionary_path
      @graphics_path = graphics_path
    end

    def call
      ensure_source_files!

      records = parsed_records
      return empty_result if records.empty?

      entry_id_by_text = dictionary_entry_ids_by_text(records.map { |row| row[:character] })
      records.select! { |row| entry_id_by_text.key?(row[:character]) }
      return empty_result if records.empty?

      component_characters = records.flat_map { |row| row[:components] }.uniq
      stroke_count_by_char = stroke_count_lookup(component_characters)
      meaning_by_char = meaning_lookup(component_characters)

      radical_id_by_char, radicals_created = upsert_radicals(
        component_characters,
        meaning_by_char,
        stroke_count_by_char
      )

      entry_ids = records.map { |row| entry_id_by_text[row[:character]] }
      rows = build_join_rows(records, entry_id_by_text, radical_id_by_char)
      sync_dictionary_entry_radicals(entry_ids, rows)

      {
        entries_processed: entry_ids.size,
        radicals_created: radicals_created,
        associations_created: rows.size
      }
    end

    private

    def ensure_source_files!
      ensure_source_file!(Admin::MakemeahanziSourceProvisioningService::DICTIONARY_URL, @dictionary_path)
      ensure_source_file!(Admin::MakemeahanziSourceProvisioningService::GRAPHICS_URL, @graphics_path)
    end

    def ensure_source_file!(url, path)
      return if File.exist?(path)

      if using_default_path?(path)
        Admin::MakemeahanziSourceProvisioningService.call(force: false)
      else
        download_file_to_tmp(url, path)
        confirm_file_presence(Pathname(path).basename.to_s, Pathname(path).dirname)
      end
    end

    def using_default_path?(path)
      [ DICTIONARY_PATH.to_s, GRAPHICS_PATH.to_s ].include?(path.to_s)
    end

    def parsed_records
      return [] unless File.exist?(@dictionary_path)

      rows = []

      File.foreach(@dictionary_path, chomp: true) do |line|
        parsed = parse_dictionary_line(line)
        rows << parsed if parsed
      end

      rows
    end

    def parse_dictionary_line(line)
      payload = JSON.parse(line)
      character = payload["character"].to_s
      return nil unless character.match?(/\A\p{Han}\z/u)

      components = extract_components(payload["decomposition"])
      return nil if components.empty?

      { character: character, components: components }
    rescue JSON::ParserError
      nil
    end

    def extract_components(decomposition)
      return [] if decomposition.blank?

      decomposition.each_char.with_object([]) do |char, components|
        next unless char.match?(/\p{Han}/u)
        components << char
      end
    end

    def stroke_count_lookup(component_characters)
      return {} unless File.exist?(@graphics_path)

      lookup = {}
      component_set = component_characters.to_set

      File.foreach(@graphics_path, chomp: true) do |line|
        payload = JSON.parse(line)
        character = payload["character"].to_s
        next unless component_set.include?(character)

        strokes = payload["strokes"]
        next unless strokes.is_a?(Array) && strokes.any?

        lookup[character] = strokes.size
      rescue JSON::ParserError
        next
      end

      lookup
    end

    def meaning_lookup(component_characters)
      in_batches(component_characters).each_with_object({}) do |batch, lookup|
        DictionaryEntry
          .where(text: batch)
          .includes(meanings: :source)
          .each do |entry|
            lookup[entry.text] = entry.flashcard_primary_meaning&.text
          end
      end
    end

    def upsert_radicals(component_characters, meaning_by_char, stroke_count_by_char)
      existing = in_batches(component_characters).each_with_object({}) do |batch, lookup|
        lookup.merge!(Radical.where(character: batch).index_by(&:character))
      end
      radicals_created = 0

      component_characters.each do |character|
        radical = existing[character]

        if radical.nil?
          radical = Radical.create!(
            character: character,
            meaning: meaning_by_char[character],
            stroke_count: stroke_count_by_char[character]
          )
          existing[character] = radical
          radicals_created += 1
          next
        end

        attrs = {}
        attrs[:meaning] = meaning_by_char[character] if radical.meaning.blank? && meaning_by_char[character].present?
        attrs[:stroke_count] = stroke_count_by_char[character] if radical.stroke_count.nil? && stroke_count_by_char[character].present?
        radical.update!(attrs) if attrs.any?
      end

      [ existing.transform_values(&:id), radicals_created ]
    end

    def build_join_rows(records, entry_id_by_text, radical_id_by_char)
      timestamp = Time.current

      records.flat_map do |record|
        entry_id = entry_id_by_text[record[:character]]

        record[:components].each_with_index.map do |component, index|
          {
            dictionary_entry_id: entry_id,
            radical_id: radical_id_by_char.fetch(component),
            position: index + 1,
            created_at: timestamp,
            updated_at: timestamp
          }
        end
      end
    end

    def sync_dictionary_entry_radicals(entry_ids, rows)
      DictionaryEntryRadical.transaction do
        in_batches(entry_ids) do |batch|
          DictionaryEntryRadical.where(dictionary_entry_id: batch).delete_all
        end
        rows.each_slice(INSERT_BATCH_SIZE) do |slice|
          DictionaryEntryRadical.insert_all(slice)
        end
      end
    end

    def dictionary_entry_ids_by_text(texts)
      in_batches(texts.uniq).each_with_object({}) do |batch, lookup|
        lookup.merge!(DictionaryEntry.where(text: batch).pluck(:text, :id).to_h)
      end
    end

    def in_batches(values)
      values.each_slice(BATCH_SIZE)
    end

    def empty_result
      {
        entries_processed: 0,
        radicals_created: 0,
        associations_created: 0
      }
    end
  end
end
