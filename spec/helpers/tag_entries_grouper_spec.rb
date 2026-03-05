require 'rails_helper'
require 'pry'

RSpec.describe TagEntriesGrouper do
  let(:user) { create(:user) }
  let(:tag) { create(:tag) }
  let(:dictionary_entry1) { create(:dictionary_entry) }
  let(:dictionary_entry2) { create(:dictionary_entry) }
  let!(:user_learning1) { create(:user_learning, user: user, dictionary_entry: dictionary_entry1, state: 'learning') }
  let!(:user_learning2) { create(:user_learning, user: user, dictionary_entry: dictionary_entry2, state: 'mastered') }

  before do
    tag.dictionary_entries << dictionary_entry1
    tag.dictionary_entries << dictionary_entry2
  end

  describe "#grouped_by_learning_state" do
    it "groups dictionary entries by learning state" do
      grouper = TagEntriesGrouper.new(tag, user)
      grouped_entries = grouper.grouped_by_learning_state
      expect(grouped_entries[:learning]).to include(dictionary_entry1)
      expect(grouped_entries[:mastered]).to include(dictionary_entry2)
    end

    it "returns an empty hash if no entries are found" do
      other_user = create(:user)
      grouper = TagEntriesGrouper.new(tag, other_user)
      grouped_entries = grouper.grouped_by_learning_state

      expect(grouped_entries).to eq({
          learning: [],
          mastered: [],
        new_entries: [],
        not_learned: [],
          suspended: []
      })
    end
  end
end
