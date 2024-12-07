require 'rails_helper'

RSpec.describe DictionaryEntryTag, type: :model do
  describe "associations" do
    it { should belong_to(:dictionary_entry) }
    it { should belong_to(:tag) }
  end
end
