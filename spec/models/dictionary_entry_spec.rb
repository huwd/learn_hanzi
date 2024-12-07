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

    it "is invalid without at least one meaning" do
      dictionary_entry.meanings = []
      expect(dictionary_entry).to_not be_valid
      expect(dictionary_entry.errors[:meanings]).to include("must have at least one associated meaning")
    end
  end
end
