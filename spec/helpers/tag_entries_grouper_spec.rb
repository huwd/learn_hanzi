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

    it "places all tag entries in new_entries for a user who has no learnings" do
      other_user = create(:user)
      grouped = TagEntriesGrouper.new(tag, other_user).grouped_by_learning_state

      expect(grouped[:new_entries]).to include(dictionary_entry1, dictionary_entry2)
      expect(grouped[:learning]).to eq([])
      expect(grouped[:struggling]).to eq([])
      expect(grouped[:mastered]).to eq([])
      expect(grouped[:suspended]).to eq([])
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

    it "does not return a not_learned key" do
      grouped = TagEntriesGrouper.new(tag, user).grouped_by_learning_state
      expect(grouped).not_to have_key(:not_learned)
    end

    context "new_entries bucket" do
      let(:unstarted_entry) { create(:dictionary_entry) }
      let(:new_state_entry) { create(:dictionary_entry) }
      let!(:new_ul) { create(:user_learning, user: user, dictionary_entry: new_state_entry, state: "new") }

      before { tag.dictionary_entries << unstarted_entry << new_state_entry }

      it "includes entries with no UserLearning record" do
        grouped = TagEntriesGrouper.new(tag, user).grouped_by_learning_state
        expect(grouped[:new_entries]).to include(unstarted_entry)
      end

      it "includes entries with state=new" do
        grouped = TagEntriesGrouper.new(tag, user).grouped_by_learning_state
        expect(grouped[:new_entries]).to include(new_state_entry)
      end

      it "excludes entries already in a non-new state" do
        grouped = TagEntriesGrouper.new(tag, user).grouped_by_learning_state
        expect(grouped[:new_entries]).not_to include(dictionary_entry1, dictionary_entry2)
      end
    end
  end
end
