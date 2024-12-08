class PinyinConverter
  TONE_MARKS = {
    "a" => %w[ā á ǎ à a],
    "e" => %w[ē é ě è e],
    "o" => %w[ō ó ǒ ò o],
    "i" => %w[ī í ǐ ì i],
    "u" => %w[ū ú ǔ ù u],
    "ü" => %w[ǖ ǘ ǚ ǜ ü]
  }

  def self.convert(pinyin)
    return pinyin if pinyin.nil? || pinyin.empty?

    normalized_text = normalize_vowels(pinyin)
    match = normalized_text.match(/^([A-Za-zü]+)([1-5]?)$/)
    return pinyin unless match

    text, tone = match[1], match[2].to_i
    tone_index = tone.zero? ? 4 : tone - 1 # Neutral tone if no number

    # Handle 'iu' and 'ui' special cases
    if text.include?("iu") || text.include?("ui")
      text = text.sub(/(iu|ui)/) do |vowel_pair|
        # Apply tone to the second vowel
        marked = TONE_MARKS[vowel_pair[-1]][tone_index]
        "#{vowel_pair[0]}#{marked}"
      end
    else
      # Normal tone placement rules
      vowels = text.scan(/[aeiouü]/)
      vowel_to_mark = vowels.find { |vowel| %w[a e o].include?(vowel) } || vowels.first
      return pinyin unless vowel_to_mark

      tone_marked = TONE_MARKS[vowel_to_mark][tone_index]
      text.sub!(vowel_to_mark, tone_marked)
    end

    return text.capitalize if pinyin[0].upcase == pinyin[0]

    text
  end

  def self.normalize_vowels(text)
    text.gsub("u:", "ü").gsub("v", "ü")
  end
end
