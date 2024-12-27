require 'rails_helper'

RSpec.describe Meaning, type: :model do
  describe "associations" do
    it { should belong_to(:dictionary_entry) }
    it { should belong_to(:source) }
  end

  describe "validations" do
    it { should validate_presence_of(:language) }
    it { should validate_presence_of(:text) }
    it { should validate_presence_of(:pinyin) }
  end

  describe "database indexes" do
    it {
      should have_db_index([ :text, :language, :source_id, :pinyin ])
        .unique(true)
    }
  end
end
