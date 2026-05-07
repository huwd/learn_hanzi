module Admin
  class FrequencyProvisioningService
    SUBTLEX_URL = "https://raw.githubusercontent.com/krmanik/HSK-3.0/main/Scripts%20and%20data/SUBTLEX_CH_131210_CE.utf8"
    SUBTLEX_PATH = Rails.root.join("tmp", "frequency", "SUBTLEX_CH_131210_CE.utf8")

    def self.call
      new.call
    end

    def call
      download_subtlex

      word_to_freq = parse_subtlex_frequencies(SUBTLEX_PATH)
      raise "No valid SUBTLEX rows found. Aborting to avoid clearing existing ranks." if word_to_freq.empty?

      ranked_words = word_to_freq.sort_by { |word, freq| [ -freq, word ] }
      texts = ranked_words.map(&:first)
      entry_id_by_text = DictionaryEntry.where(text: texts).pluck(:text, :id).to_h

      rows = []
      ranked_words.each_with_index do |(word, _freq), idx|
        entry_id = entry_id_by_text[word]
        next unless entry_id

        rows << { id: entry_id, frequency_rank: idx + 1 }
      end

      DictionaryEntry.transaction do
        DictionaryEntry.update_all(frequency_rank: nil)
        rows.each_slice(1000) do |slice|
          DictionaryEntry.upsert_all(slice, unique_by: :id, update_only: [ :frequency_rank ])
        end
      end

      {
        words_parsed: word_to_freq.size,
        entries_updated: rows.size,
        missing_from_dictionary: word_to_freq.size - rows.size
      }
    end

    private

    def download_subtlex
      path = SUBTLEX_PATH.to_s
      FileUtils.mkdir_p(File.dirname(path))

      File.open(path, "wb") do |file|
        file.write(URI(SUBTLEX_URL).open.read)
      end
    end

    def parse_subtlex_frequencies(file_path)
      word_index = nil
      freq_index = nil
      word_to_freq = {}

      File.foreach(file_path, chomp: true, encoding: "bom|utf-8").with_index do |line, idx|
        fields = line.split("\t")

        if idx.zero?
          word_index = fields.index("Word")
          freq_index = fields.index("W.million")
          next
        end

        next if word_index.nil? || freq_index.nil?

        word = fields[word_index]&.strip
        next if word.blank?

        freq = fields[freq_index].to_s.strip.tr(",", "").to_f
        next if freq <= 0

        word_to_freq[word] = [ word_to_freq[word].to_f, freq ].max
      end

      if word_index.nil? || freq_index.nil?
        raise "Invalid SUBTLEX header in #{file_path}: expected Word and W.million columns"
      end

      word_to_freq
    end
  end
end
