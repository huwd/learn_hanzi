require 'rails_helper'

RSpec.describe Meaning, type: :model do
  describe "associations" do
    it { should belong_to(:dictionary_entry) }
    it { should belong_to(:source) }
  end

  describe "validations" do
    it { should validate_presence_of(:language) }
    it { should validate_presence_of(:text) }
  end

  describe "database indexes" do
    it {
      should have_db_index([ :dictionary_entry_id, :language, :text, :source_id ])
        .unique(true)
    }
  end
end
