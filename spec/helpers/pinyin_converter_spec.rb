require 'rails_helper'

RSpec.describe PinyinConverter, type: :helper do
  describe ".convert" do
    it "converts numeric tone pinyin to tone-marked pinyin" do
      expect(PinyinConverter.convert("hao3")).to eq("hǎo")
      expect(PinyinConverter.convert("ma5")).to eq("ma")
      expect(PinyinConverter.convert("zhong1")).to eq("zhōng")
      expect(PinyinConverter.convert("yu2")).to eq("yú")
    end

    it "returns the original string if no tone is found" do
      expect(PinyinConverter.convert("hello")).to eq("hello")
      expect(PinyinConverter.convert("zhong")).to eq("zhong")
    end

    it "handles special cases like 'iu' and 'ui'" do
      expect(PinyinConverter.convert("dui4")).to eq("duì")
      expect(PinyinConverter.convert("diu1")).to eq("diū")
    end

    it "maintains capitalisation on the first letter" do
      expect(PinyinConverter.convert("Zhong1")).to eq("Zhōng")
      expect(PinyinConverter.convert("Yu2")).to eq("Yú")
    end
  end


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
