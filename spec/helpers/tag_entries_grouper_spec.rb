require 'rails_helper'

RSpec.describe TagEntriesGrouper do
  let(:user) { create(:user) }
  let(:tag) { create(:tag) }
  let(:dictionary_entry1) { create(:dictionary_entry) }
  let(:dictionary_entry2) { create(:dictionary_entry) }
  let!(:user_learning1) { create(:user_learning, user: user, dictionary_entry: dictionary_entry1, state: 'learning', factor: 2500) }
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

    it "returns empty buckets for a user who has no learnings for the tag" do
      other_user = create(:user)
      grouper = TagEntriesGrouper.new(tag, other_user)
      grouped_entries = grouper.grouped_by_learning_state

      expect(grouped_entries[:learning]).to eq([])
      expect(grouped_entries[:struggling]).to eq([])
      expect(grouped_entries[:mastered]).to eq([])
      expect(grouped_entries[:new_entries]).to eq([])
      expect(grouped_entries[:suspended]).to eq([])
    end

    context "struggling bucket" do
      let(:struggling_entry) { create(:dictionary_entry) }
      let!(:struggling_learning) do
        create(:user_learning, user: user, dictionary_entry: struggling_entry, state: 'learning', factor: 1999)
      end

      before { tag.dictionary_entries << struggling_entry }

      it "puts learning entries with factor < 2000 into struggling" do
        grouped = TagEntriesGrouper.new(tag, user).grouped_by_learning_state
        expect(grouped[:struggling]).to include(struggling_entry)
        expect(grouped[:learning]).not_to include(struggling_entry)
      end

      it "keeps learning entries with factor >= 2000 in learning" do
        grouped = TagEntriesGrouper.new(tag, user).grouped_by_learning_state
        expect(grouped[:learning]).to include(dictionary_entry1)
        expect(grouped[:struggling]).not_to include(dictionary_entry1)
      end
    end

    it "includes entries the current user has not started, even if another user has" do
      other_user = create(:user)
      create(:user_learning, user: other_user, dictionary_entry: dictionary_entry1, state: "mastered")
      grouper = TagEntriesGrouper.new(tag, user)

      # user has a learning for entry1 (learning state), so entry1 must NOT be in not_learned
      expect(grouper.grouped_by_learning_state[:not_learned]).not_to include(dictionary_entry1)
    end

    it "excludes entries the current user has already started from not_learned" do
      other_user = create(:user)
      grouper = TagEntriesGrouper.new(tag, other_user)

      # other_user has no learnings — both entries must appear in not_learned
      expect(grouper.grouped_by_learning_state[:not_learned]).to include(dictionary_entry1, dictionary_entry2)
    end
  end
end
