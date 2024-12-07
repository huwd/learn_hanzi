require 'rails_helper'

RSpec.describe DictionaryEntry, type: :model do
  describe "associations" do
    it { should have_many(:dictionary_entry_tags).dependent(:destroy) }
    it { should have_many(:tags).through(:dictionary_entry_tags) }
    it { should have_many(:meanings).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:text) }
    it { should validate_presence_of(:pinyin) }
  end

  describe "nested attributes" do
    it { should accept_nested_attributes_for(:meanings).allow_destroy(true) }
  end

  describe "custom validations" do
    it "requires at least one associated meaning" do
      dictionary_entry = build(:dictionary_entry)
      dictionary_entry.meanings.clear # Ensure no meanings
      expect(dictionary_entry).to_not be_valid
      expect(dictionary_entry.errors[:meanings]).to include("must have at least one associated meaning")
    end
  end
end
