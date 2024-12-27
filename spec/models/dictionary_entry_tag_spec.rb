require 'rails_helper'

RSpec.describe DictionaryEntryTag, type: :model do
  describe "associations" do
    it { should belong_to(:dictionary_entry) }
    it { should belong_to(:tag) }
  end

  describe "database indexes" do
    it {
      should have_db_index([ :dictionary_entry_id, :tag_id ])
        .unique(true)
    }
  end
end
