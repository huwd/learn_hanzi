require "rails_helper"

RSpec.describe DictionaryEntryRadical, type: :model do
  describe "associations" do
    it { should belong_to(:dictionary_entry) }
    it { should belong_to(:radical) }
  end

  describe "validations" do
    subject(:dictionary_entry_radical) { build(:dictionary_entry_radical) }

    it { should validate_presence_of(:position) }
    it { should validate_numericality_of(:position).only_integer.is_greater_than(0) }
  end

  describe "database indexes" do
    it {
      should have_db_index([ :dictionary_entry_id, :position ])
        .unique(true)
    }
  end
end
