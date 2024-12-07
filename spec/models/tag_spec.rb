require 'rails_helper'

RSpec.describe Tag, type: :model do
  let(:tag) { build(:tag) }
  let(:parent_tag) { create(:tag, name: "Super Group") }
  let(:child_tag) { create(:tag, name: "Sub Group", parent: parent_tag) }


  describe "validations" do
    it "is valid with valid attributes" do
      expect(tag).to be_valid
    end

    it "is not valid without a name" do
      tag.name = nil
      expect(tag).to_not be_valid
    end
  end

  describe "associations" do
    it "can have children" do
      expect(child_tag.parent).to eq(parent_tag)
      expect(parent_tag.children).to include(child_tag)
    end
  end
end
