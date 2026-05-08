require "rails_helper"

RSpec.describe Radical, type: :model do
  describe "associations" do
    it { should have_many(:dictionary_entry_radicals).dependent(:destroy) }
    it { should have_many(:dictionary_entries).through(:dictionary_entry_radicals) }
  end

  describe "validations" do
    subject(:radical) { build(:radical, character: "A") }

    it { should validate_presence_of(:character) }
    it { should validate_uniqueness_of(:character) }
    it { should validate_numericality_of(:stroke_count).only_integer.is_greater_than(0).allow_nil }
  end

  describe "database indexes" do
    it { should have_db_index(:character).unique(true) }
  end
end
