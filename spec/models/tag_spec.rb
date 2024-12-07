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
end
