require 'rails_helper'

RSpec.describe TagImportHelper, type: :helper do
  describe "#find_or_create_tag" do
    it "creates a new tag if it doesn't exist" do
      expect {
        helper.find_or_create_tag("HSK 1", "HSK")
      }.to change(Tag, :count).by(1)

      tag = Tag.find_by(name: "HSK 1")
      expect(tag).to be_present
      expect(tag.category).to eq("HSK")
    end

    it "finds an existing tag if it exists" do
      existing_tag = create(:tag, name: "HSK 1", category: "HSK")
      expect {
        helper.find_or_create_tag("HSK 1", "HSK")
      }.not_to change(Tag, :count)

      tag = Tag.find_by(name: "HSK 1")
      expect(tag).to eq(existing_tag)
    end
  end

  describe "#associate_dictionary_entry_to_tag" do
    let(:tag) { create(:tag) }
    let(:dictionary_entry) { create(:dictionary_entry, text: "学习") }

    it "associates a dictionary entry with a tag" do
      expect {
        helper.associate_dictionary_entry_to_tag("学习", tag)
      }.to change(dictionary_entry.tags, :count).by(1)

      expect(dictionary_entry.tags).to include(tag)
    end

    it "raises an error if no tag is provided" do
      expect {
        helper.associate_dictionary_entry_to_tag("学习", nil)
      }.to raise_error("No tag provided")
    end

    it "raises an error if no dictionary entry is found" do
      expect {
        helper.associate_dictionary_entry_to_tag("不存在", tag)
      }.to raise_error("No entry found for 不存在")
    end
  end
end
