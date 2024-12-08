require 'rails_helper'

RSpec.describe PinyinConverter, type: :helper do
  describe ".normalize_vowels" do
    it "replaces 'u:' with 'ü'" do
      expect(PinyinConverter.normalize_vowels("Nu:3")).to eq("Nü3")
    end

    it "replaces 'v' with 'ü'" do
      expect(PinyinConverter.normalize_vowels("lv4")).to eq("lü4")
    end

    it "handles mixed cases" do
      expect(PinyinConverter.normalize_vowels("Nu:3 lv4 yu:2")).to eq("Nü3 lü4 yü2")
    end

    it "does not alter text without 'u:' or 'v'" do
      expect(PinyinConverter.normalize_vowels("Ni3 hao3")).to eq("Ni3 hao3")
    end
  end
end
