require 'rails_helper'

# Tests for the CorrectAnkiNextDueDates data migration.
#
# The Anki test DB seeds card 1 (好, queue=2, due=300) and card 3 (学, queue=0,
# due=3), which provide the Anki-side data the migration reads.
# We create matching UserLearning rows with wrong epoch dates and assert the
# migration corrects them.
RSpec.describe "CorrectAnkiNextDueDates migration" do
  let(:migration) { CorrectAnkiNextDueDates.new }
  let(:user)      { create(:user) }
  let(:crt)       { AnkiSeedData::COL_CRT }

  let!(:entry_hao) { create(:dictionary_entry, text: "好") }  # card 1, queue=2, due=300
  let!(:entry_xue) { create(:dictionary_entry, text: "学") }  # card 3, queue=0,  due=3

  describe "#up" do
    context "mastered card with an epoch next_due (bad import)" do
      let!(:ul) do
        create(:user_learning,
          user:             user,
          dictionary_entry: entry_hao,
          state:            "mastered",
          next_due:         Time.at(300))  # wrong: treated 300 days as 300 seconds
      end

      it "corrects next_due to Time.at(crt + due_days * 86_400)" do
        migration.up
        expect(ul.reload.next_due).to be_within(1.second).of(Time.at(crt + 300 * 86_400))
      end
    end

    context "mastered card with a future next_due (recently reviewed)" do
      let(:future_due) { 7.days.from_now }
      let!(:ul) do
        create(:user_learning,
          user:             user,
          dictionary_entry: entry_hao,
          state:            "mastered",
          next_due:         future_due)
      end

      it "leaves next_due unchanged" do
        migration.up
        expect(ul.reload.next_due).to be_within(1.second).of(future_due)
      end
    end

    context "new card with an ordinal next_due (bad import)" do
      let!(:ul) do
        create(:user_learning,
          user:             user,
          dictionary_entry: entry_xue,
          state:            "new",
          next_due:         Time.at(3))  # wrong: treated ordinal 3 as 3 seconds
      end

      it "sets next_due to nil" do
        migration.up
        expect(ul.reload.next_due).to be_nil
      end
    end
  end
end
