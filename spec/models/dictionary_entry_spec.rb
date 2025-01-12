require 'rails_helper'

RSpec.describe DictionaryEntry, type: :model do
  describe "associations" do
    it { should have_many(:dictionary_entry_tags).dependent(:destroy) }
    it { should have_many(:tags).through(:dictionary_entry_tags) }
    it { should have_many(:meanings).dependent(:destroy) }
    it { should have_many(:user_learnings).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:text) }

    it "requires at least one associated meaning" do
      dictionary_entry = build(:dictionary_entry)
      dictionary_entry.meanings.clear # Ensure no meanings
      expect(dictionary_entry).to_not be_valid
      expect(dictionary_entry.errors[:dictionary_entry]).to include("must have at least one associated meaning")
    end
  end

  describe "nested attributes" do
    it { should accept_nested_attributes_for(:meanings).allow_destroy(true) }
  end

  describe "#add_tag" do
    let(:dictionary_entry) { create(:dictionary_entry) }
    let(:tag) { create(:tag) }

    it "adds a tag to the dictionary entry" do
      dictionary_entry.add_tag(tag)
      expect(dictionary_entry.tags).to include(tag)
    end

    it "does not add the same tag twice" do
      dictionary_entry.add_tag(tag)
      dictionary_entry.add_tag(tag)
      expect(dictionary_entry.tags.where(id: tag.id).count).to eq(1)
    end
  end

  describe "#user_learning_for" do
    let(:dictionary_entry) { create(:dictionary_entry) }
    let(:user) { create(:user) }
    let!(:user_learning) { create(:user_learning, user: user, dictionary_entry: dictionary_entry) }

    it "returns the user learning for the given user" do
      expect(dictionary_entry.user_learning_for(user)).to eq(user_learning)
    end

    it "returns nil if no user learning exists for the given user" do
      other_user = create(:user)
      expect(dictionary_entry.user_learning_for(other_user)).to be_nil
    end
  end

  describe ".find_with_associations" do
    let(:dictionary_entry) { create(:dictionary_entry) }
    let(:user) { create(:user) }
    let!(:user_learning) { create(:user_learning, user: user, dictionary_entry: dictionary_entry) }
    let!(:meaning) { create(:meaning, dictionary_entry: dictionary_entry) }

    it "returns the dictionary entry with associated tags, meanings, and user learning" do
      result = DictionaryEntry.find_with_associations(dictionary_entry.id, user)
      expect(result[:entry]).to eq(dictionary_entry)
      expect(result[:meanings]).to include(meaning)
      expect(result[:user_learning]).to eq(user_learning)
    end
  end
end
