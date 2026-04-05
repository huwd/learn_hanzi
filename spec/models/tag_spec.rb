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

  describe "#ancestors" do
    let(:root)  { create(:tag, name: "HSK 2.0") }
    let(:level) { create(:tag, name: "HSK 4", parent: root) }
    let(:leaf)  { create(:tag, name: "Lesson 1", parent: level) }

    it "returns an empty array for a root tag" do
      expect(root.ancestors).to eq([])
    end

    it "returns the parent for a one-level-deep tag" do
      expect(level.ancestors).to eq([ root ])
    end

    it "returns the full ancestry chain top-down for a deeply nested tag" do
      expect(leaf.ancestors).to eq([ root, level ])
    end
  end

  describe "#subtree_ids" do
    let(:root)       { create(:tag, name: "HSK 4") }
    let(:child)      { create(:tag, name: "Lesson 1", parent: root) }
    let(:grandchild) { create(:tag, name: "Lesson 1a", parent: child) }

    it "returns only itself when there are no children" do
      expect(root.subtree_ids).to eq([ root.id ])
    end

    it "includes direct children" do
      child
      expect(root.subtree_ids).to include(child.id)
    end

    it "includes grandchildren" do
      grandchild
      expect(root.subtree_ids).to include(grandchild.id)
    end
  end

  describe "#add_child" do
    let(:parent_tag) { create(:tag) }
    let(:child_tag) { create(:tag) }

    it "adds a child tag" do
      parent_tag.add_child(child_tag)
      expect(parent_tag.children).to include(child_tag)
    end

    it "does not add the same child tag twice" do
      parent_tag.add_child(child_tag)
      parent_tag.add_child(child_tag)
      expect(parent_tag.children.where(id: child_tag.id).count).to eq(1)
    end
  end
end
