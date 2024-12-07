require 'rails_helper'

RSpec.describe DictionaryEntry, type: :model do
  let(:dictionary_entry) { build(:dictionary_entry) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(dictionary_entry).to be_valid
    end

    it "is not valid without text" do
      dictionary_entry.text = nil
      expect(dictionary_entry).to_not be_valid
    end

    it "is not valid without pinyin" do
      dictionary_entry.pinyin = nil
      expect(dictionary_entry).to_not be_valid
    end

    it "is not valid without meanings" do
      dictionary_entry.meanings = nil
      expect(dictionary_entry).to_not be_valid
    end
  end
end
