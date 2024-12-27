module DictionaryImportHelper
  def find_or_create_cc_cedict_source(source_name, source_url)
    source = Source.find_or_create_by(name: source_name, url: source_url).tap do |source|
      source.update(date_accessed: Date.today) if source.date_accessed != Date.today
    end
    source.save!
    source
  end
  def parse_cc_cedict_line(line, source_hash)
    match = line.match(/^(?<traditional>\S+)\s+(?<simplified>\S+)\s+\[(?<pinyin>[^\]]+)\]\s+(?<meanings>\/.+\/)$/)

    if match
      {
        simplified: match[:simplified],
        traditional: match[:traditional],
        pinyin: PinyinConverter.convert_sentence(match[:pinyin]),
        meaning_attributes: parse_meanings(match[:meanings], source_hash)
      }
    else
      nil # Return nil if the line doesn't match the expected format
    end
  end

  def parse_meanings(meanings, source_hash)
    meanings[1..-2].split("/").map do |meaning|
      {
        text: meaning.strip,
        language: "en",
        source_attributes: source_hash
      }
    end
  end
end
