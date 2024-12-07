require 'rails_helper'

RSpec.describe Tag, type: :model do
  let(:tag) { build(:tag) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(tag).to be_valid
    end

    it "is not valid without a name" do
      tag.name = nil
      expect(tag).to_not be_valid
    end
  end
end
