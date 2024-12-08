class PinyinConverter
  def self.normalize_vowels(text)
    text.gsub("u:", "ü").gsub("v", "ü")
  end
end
