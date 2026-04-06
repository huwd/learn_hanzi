require 'rails_helper'

RSpec.describe UserLearning, type: :model do
  let(:user) { create(:user) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:dictionary_entry) }
  end

  describe 'validations' do
    it { should validate_presence_of(:state) }
    it { should validate_inclusion_of(:state).in_array([ 'new', 'learning', 'mastered' ]) }

    it "validates uniqueness of user scoped to dictionary_entry" do
      entry = create(:dictionary_entry)
      create(:user_learning, user: user, dictionary_entry: entry, state: 'learning')

      duplicate = build(:user_learning, user: user, dictionary_entry: entry)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user]).to include("already has a learning record for this entry")
    end
  end

  describe 'scopes' do
    before do
      create(:user_learning, state: 'new', user_id: user.id)
      create(:user_learning, state: 'learning', user_id: user.id)
      create(:user_learning, state: 'mastered', user_id: user.id)
      create(:user_learning, state: 'suspended', user_id: user.id)
    end

    it "filters new learnings" do
      expect(UserLearning.new_learnings.count).to eq(1)
    end

    it "filters in-progress learnings" do
      expect(UserLearning.in_progress.count).to eq(1)
    end

    it "filters mastered learnings" do
      expect(UserLearning.mastered.count).to eq(1)
    end

    it "filters suspended learnings" do
      expect(UserLearning.suspended.count).to eq(1)
    end
  end

  describe 'due-card scopes' do
    let!(:overdue_learning) do
      create(:user_learning, user: user, state: 'learning', next_due: 2.days.ago)
    end
    let!(:future_learning) do
      create(:user_learning, user: user, state: 'learning', next_due: 3.days.from_now)
    end
    let!(:overdue_mastered) do
      create(:user_learning, user: user, state: 'mastered', next_due: 1.day.ago)
    end
    let!(:future_mastered) do
      create(:user_learning, user: user, state: 'mastered', next_due: 7.days.from_now)
    end

    describe '.due' do
      it "returns records with next_due in the past" do
        expect(UserLearning.due).to include(overdue_learning, overdue_mastered)
      end

      it "excludes records not yet due" do
        expect(UserLearning.due).not_to include(future_learning, future_mastered)
      end
    end

    describe '.overdue_learning' do
      it "returns only learning cards that are overdue" do
        expect(UserLearning.overdue_learning).to contain_exactly(overdue_learning)
      end
    end

    describe '.due_mastered' do
      it "returns only mastered cards that are due" do
        expect(UserLearning.due_mastered).to contain_exactly(overdue_mastered)
      end
    end
  end
end
