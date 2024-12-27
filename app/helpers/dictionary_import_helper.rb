module DictionaryImportHelper
  CC_CEDICT_REGEX = /^(?<traditional>\S+)\s+(?<simplified>\S+)\s+\[(?<pinyin>[^\]]+)\]\s+(?<meanings>\/.*\/)\s*$/

  def find_or_create_cc_cedict_source(source_name, source_url)
    source = Source.find_or_create_by(name: source_name, url: source_url).tap do |source|
      source.update(date_accessed: Date.today) if source.date_accessed != Date.today
    end
    source.save!
    source
  end

  def find_or_create_dictionary_entry(line, source)
    parsed_entry = parse_cc_cedict_line(line, source)
    raise "Error parsing line: #{line}" if parsed_entry.nil?

    DictionaryEntry.transaction do
      source = find_or_create_cc_cedict_source(source[:name], source[:url])
      dictionary_entry = DictionaryEntry.find_or_initialize_by(
        text: parsed_entry[:simplified]
      )

      parsed_entry[:meaning_attributes].each do |meaning|
        payload = {
          text: meaning[:text],
          language: "en",
          source: source,
          pinyin: meaning[:pinyin]
        }
        unless dictionary_entry.meanings.exists?(**payload)
          dictionary_entry.meanings.build(**payload)
        end
      end

      dictionary_entry.save!
      dictionary_entry
    end
  end

  def parse_cc_cedict_line(line, source_hash)
    match = line.match(CC_CEDICT_REGEX)
    if match
      {
        simplified: match[:simplified],
        traditional: match[:traditional],
        meaning_attributes: parse_meanings(match[:meanings], source_hash, match[:pinyin])
      }
    else
      nil # Return nil if the line doesn't match the expected format
    end
  end

  def parse_meanings(meanings, source_hash, pinyin)
    meanings[1..-2].split("/").map do |meaning|
      {
        text: meaning.strip,
        language: "en",
        source_attributes: source_hash,
        pinyin: PinyinConverter.convert_sentence(pinyin)
      }
    end
  end
end
