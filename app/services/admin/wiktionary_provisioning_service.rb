require "zlib"
require "json"

module Admin
  class WiktionaryProvisioningService
    include ImportFilesHelper

    WIKTIONARY_URL = "https://kaikki.org/dictionary/Chinese/kaikki.org-dictionary-Chinese.jsonl.gz"
    WIKTIONARY_FILE = Rails.root.join("tmp", "kaikki_chinese.jsonl.gz")

    def self.call
      new.call
    end

    def call
      entries_before = Meaning.joins(:source).where(sources: { name: "Wiktionary" }).count

      download_file_to_tmp(WIKTIONARY_URL, WIKTIONARY_FILE)

      source = Source.find_or_create_by!(name: "Wiktionary") do |s|
        s.url = WIKTIONARY_URL
        s.date_accessed = Time.current
        s.priority = 10
      end
      source.update!(priority: 10) if source.priority != 10

      created_meanings = 0
      batch = []

      Zlib::GzipReader.open(WIKTIONARY_FILE) do |gz|
        gz.each_line do |line|
          begin
            parsed = JSON.parse(line)
            next unless parsed["lang"] == "Chinese"

            word = parsed["word"]
            next if word.blank?

            # Extract glosses (meanings)
            senses = parsed["senses"]&.flat_map { |s| s["glosses"] }&.compact
            next if senses.blank?

            # Extract pinyin
            pinyin = "Unknown"
            if parsed["sounds"]
              pinyin_sound = parsed["sounds"].find do |sound|
                tags = sound["tags"] || []
                tags.include?("Mandarin") && tags.include?("Pinyin") && sound["zh_pron"]
              end
              if pinyin_sound
                # Clean up "jū (ju¹)" -> "jū"
                pinyin = pinyin_sound["zh_pron"].sub(/\s*\(.*\)$/, "").strip
              end
            end

            # Skip entries with no hanzi characters
            next unless word.match?(/\p{Han}/)

            meaning_text = senses.join("; ")

            batch << {
              word: word,
              meaning_text: meaning_text,
              pinyin: pinyin
            }

            if batch.size >= 1000
              created_meanings += process_batch(batch, source)
              batch.clear
            end

          rescue JSON::ParserError
            # skip malformed lines
            next
          end
        end
      end

      # Process remaining items in the last batch
      if batch.any?
        created_meanings += process_batch(batch, source)
        batch.clear
      end

      entries_after = Meaning.joins(:source).where(sources: { name: "Wiktionary" }).count

      { entries_before: entries_before, entries_after: entries_after, created_meanings: created_meanings }
    end

    private

    def process_batch(batch, source)
      words = batch.map { |item| item[:word] }.uniq

      DictionaryEntry.insert_all(
        words.map { |w| { text: w } },
        unique_by: :text
      )

      entry_id_map = DictionaryEntry.where(text: words).pluck(:text, :id).to_h

      meaning_rows = batch.filter_map do |item|
        entry_id = entry_id_map[item[:word]]
        next unless entry_id

        {
          dictionary_entry_id: entry_id,
          text: item[:meaning_text],
          language: "en",
          pinyin: item[:pinyin],
          source_id: source.id
        }
      end

      # Ensure no duplicate meaning rows within the batch itself
      meaning_rows.uniq! { |m| [ m[:dictionary_entry_id], m[:language], m[:text], m[:pinyin], m[:source_id] ] }

      if meaning_rows.any?
        result = Meaning.insert_all(
          meaning_rows,
          unique_by: [ :dictionary_entry_id, :language, :text, :pinyin, :source_id ]
        )
        result.count
      else
        0
      end
    end
  end
end
