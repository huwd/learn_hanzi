require 'rails_helper'

RSpec.describe Meaning, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      meaning = build(:meaning)
      expect(meaning).to be_valid
    end

    it "is invalid without a dictionary entry" do
      meaning = build(:meaning, dictionary_entry: nil)
      expect(meaning).to_not be_valid
      expect(meaning.errors[:dictionary_entry]).to include("must exist")
    end

    it "is invalid without a language" do
      meaning = build(:meaning, language: nil)
      expect(meaning).to_not be_valid
      expect(meaning.errors[:language]).to include("can't be blank")
    end

    it "is invalid without text" do
      meaning = build(:meaning, text: nil)
      expect(meaning).to_not be_valid
      expect(meaning.errors[:text]).to include("can't be blank")
    end
  end
end
