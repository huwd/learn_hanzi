require 'rails_helper'

RSpec.describe Meaning, type: :model do
  describe "associations" do
    it { should belong_to(:dictionary_entry) }
  end

  describe "validations" do
    it { should validate_presence_of(:language) }
    it { should validate_presence_of(:text) }
  end
end
