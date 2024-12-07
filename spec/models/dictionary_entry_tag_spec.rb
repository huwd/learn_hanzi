require 'rails_helper'

RSpec.describe DictionaryEntryTag, type: :model do
  let(:entry) { create(:dictionary_entry) }
  let(:tag) { create(:tag) }
  let(:entry_tag) { create(:dictionary_entry_tag, dictionary_entry: entry, tag: tag) }

  describe "associations" do
    it "belongs to a dictionary entry" do
      expect(entry_tag.dictionary_entry).to eq(entry)
    end

    it "belongs to a tag" do
      expect(entry_tag.tag).to eq(tag)
    end
  end
end
