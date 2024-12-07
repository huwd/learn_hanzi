require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe "associations" do
    it { should have_many(:dictionary_entry_tags).dependent(:destroy) }
    it { should have_many(:dictionary_entries).through(:dictionary_entry_tags) }
    it { should belong_to(:parent).class_name("Tag").optional }
    it { should have_many(:children).class_name("Tag").with_foreign_key("parent_id").dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
  end

  describe "factory" do
    it "is valid" do
      expect(build(:tag)).to be_valid
    end
  end

  describe "Tag Hierarchy" do
    describe "Top Level Tags" do
      it "has no parent" do
        expect(build(:tag).parent).to be_nil
      end

      it "may not have any children" do
        expect(build(:tag).parent).to be_nil
      end
    end

    describe "Child Level Tags" do
      let(:tag) { create(:tag) }
      let(:child_tag) { create(:tag, parent: tag) }

      it "has a parent" do
        expect(child_tag.parent).to be(tag)
      end

      it "is accessible among the parent's children" do
        expect(tag.children).to include(child_tag)
      end
    end
  end
end
