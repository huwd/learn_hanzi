require 'rails_helper'
require Rails.root.join('db/migrate/20260404215231_correct_anki_next_due_dates')

# Tests for the CorrectAnkiNextDueDates data migration.
#
# The Anki test DB seeds card 1 (好, queue=2, due=300) which provides the
# Anki-side data the mastered-card pass reads. New-card clearing no longer
# requires an Anki lookup so any entry works for that case.
RSpec.describe "CorrectAnkiNextDueDates migration" do
  let(:migration) { CorrectAnkiNextDueDates.new }
  let(:user)      { create(:user) }
  let(:crt)       { AnkiSeedData::COL_CRT }

  let!(:entry_hao) { create(:dictionary_entry, text: "好") }  # card 1, queue=2, due=300

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

    context "mastered card with epoch next_due and no Anki card in target deck" do
      # Simulate a card that moved decks: no DictionaryEntry text matches any
      # Anki note, so the first pass skips it. The fallback must reconstruct
      # next_due from the review log.
      let!(:orphan_entry) { create(:dictionary_entry, text: "孤") }
      let(:review_time_ms) { 1_700_000_000_000 } # 2023-11-14 in ms
      let!(:ul) do
        create(:user_learning,
          user:             user,
          dictionary_entry: orphan_entry,
          state:            "mastered",
          next_due:         Time.at(300),
          last_interval:    30)
      end
      let!(:log) { create(:review_log, user_learning: ul, time: review_time_ms) }

      it "reconstructs next_due from the most recent review log" do
        migration.up
        expected = Time.at(review_time_ms / 1000.0) + 30.days
        expect(ul.reload.next_due).to be_within(1.second).of(expected)
      end
    end

    context "new card with an ordinal next_due (bad import)" do
      let!(:ul) do
        create(:user_learning,
          user:             user,
          dictionary_entry: entry_hao,
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
