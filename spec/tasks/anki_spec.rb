require 'rails_helper'
require 'rake'

RSpec.describe "anki:migrate_to_models", type: :task do
  before do
    Rake.application.rake_require("tasks/anki")
    Rake::Task.define_task(:environment)
  end

  after do
    Rake::Task["anki:migrate_to_models"].reenable
  end

  # Captures stdout and rescues SystemExit so error-path tests can
  # assert on the message without the suite itself exiting.
  def run_task(*args)
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    begin
      Rake::Task["anki:migrate_to_models"].invoke(*args)
    rescue SystemExit
      # allow task error exits without propagating
    ensure
      $stdout = original_stdout
    end
    output.string
  end

  context "when email is not provided" do
    it "prints a helpful error message" do
      output = run_task
      expect(output).to include("Please provide an email parameter")
    end
  end

  context "when the user is not found" do
    it "prints a helpful error message" do
      output = run_task("nobody@example.com")
      expect(output).to include("No user found with email: nobody@example.com")
    end
  end

  context "when the deck is not found" do
    it "prints a helpful error message" do
      user = create(:user)
      stub_const("Anki::ANKI_DESK_TARGET", "NoSuchDeck")
      output = run_task(user.email_address)
      expect(output).to include("No deck found with the name: NoSuchDeck")
    end
  end

  context "with a valid user and the target deck present" do
    # DictionaryEntries matching each seeded Anki note (by Simplified field).
    # Note 8 ("不") intentionally has no entry to test the skip behaviour.
    # Note 9 ("爱") is in a filtered deck (did=FILTERED_DECK_ID, odid=DECK_ID).
    let(:user)        { create(:user) }
    let!(:entry_hao)  { create(:dictionary_entry, text: "好") }  # card 1, queue 2  → mastered
    let!(:entry_hen)  { create(:dictionary_entry, text: "很") }  # card 2, queue 2  → mastered
    let!(:entry_xue)  { create(:dictionary_entry, text: "学") }  # card 3, queue 0  → new
    let!(:entry_tian) { create(:dictionary_entry, text: "天") }  # card 4, queue 1  → learning
    let!(:entry_ren)  { create(:dictionary_entry, text: "人") }  # card 5, queue 3  → learning
    let!(:entry_da)   { create(:dictionary_entry, text: "大") }  # card 6, queue -1 → suspended
    let!(:entry_xiao) { create(:dictionary_entry, text: "小") }  # card 7, queue -2 → suspended
    let!(:entry_ai)   { create(:dictionary_entry, text: "爱") }  # card 9, in filtered deck via odid

    before { run_task(user.email_address) }

    describe "queue → state mapping" do
      it "maps queue 0 to 'new'" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_xue)
        expect(ul.state).to eq("new")
      end

      it "maps queue 1 to 'learning'" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_tian)
        expect(ul.state).to eq("learning")
      end

      it "maps queue 2 to 'mastered'" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_hao)
        expect(ul.state).to eq("mastered")
      end

      it "maps queue 3 (day-learning) to 'learning'" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_ren)
        expect(ul.state).to eq("learning")
      end

      it "maps queue -1 to 'suspended'" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_da)
        expect(ul.state).to eq("suspended")
      end

      it "maps queue -2 (buried) to 'suspended'" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_xiao)
        expect(ul.state).to eq("suspended")
      end
    end

    describe "next_due calculation" do
      # crt is the collection creation timestamp seeded into col.crt.
      # queue=2 due values are days since crt, not Unix seconds.
      let(:crt) { AnkiSeedData::COL_CRT }

      it "converts queue=2 (mastered) due days to a real datetime via crt" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_hao)
        expect(ul.next_due).to be_within(1.second).of(Time.at(crt + 300 * 86_400))
      end

      it "stores a unix-timestamp due for queue=1 (learning) unchanged" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_tian)
        expect(ul.next_due).to be_within(1.second).of(Time.at(1_234_567_890))
      end

      it "stores nil for queue=0 (new) cards whose due is an ordinal, not a date" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_xue)
        expect(ul.next_due).to be_nil
      end

      it "stores nil for suspended/buried cards whose due encoding is ambiguous" do
        [ entry_da, entry_xiao ].each do |entry|
          ul = UserLearning.find_by!(user: user, dictionary_entry: entry)
          expect(ul.next_due).to be_nil
        end
      end
    end

    it "creates ReviewLog records linked to the UserLearning" do
      ul = UserLearning.find_by!(user: user, dictionary_entry: entry_hao)
      expect(ul.review_logs).not_to be_empty
    end

    it "skips cards whose Simplified field has no matching DictionaryEntry" do
      # 8 entries have matches; card 8 ("不") has none and must be skipped
      expect(UserLearning.where(user: user).count).to eq(8)
    end

    describe "filtered deck (odid) support" do
      # Regression anchor for issue #31: cards temporarily housed in a Custom Study
      # Session have did=filtered_deck and odid=target_deck. The migration must match
      # on odid so these cards are not silently dropped.
      it "imports a card whose odid matches the target deck" do
        expect(UserLearning.find_by(user: user, dictionary_entry: entry_ai)).not_to be_nil
      end

      it "maps a filtered-deck card with queue 2 to 'mastered'" do
        ul = UserLearning.find_by!(user: user, dictionary_entry: entry_ai)
        expect(ul.state).to eq("mastered")
      end
    end

    it "reports elapsed time on completion" do
      Rake::Task["anki:migrate_to_models"].reenable
      output = run_task(user.email_address)
      expect(output).to match(/Completed in [\d.]+s/)
    end

    it "loads Anki notes in a single batch query, not one per card" do
      # Pre-optimisation: Anki::Note.find_by_id was called once per card
      # inside the loop. Post-optimisation: a single WHERE IN query replaces all
      # of those round-trips.
      Rake::Task["anki:migrate_to_models"].reenable
      expect(Anki::Note).not_to receive(:find_by_id)
      run_task(user.email_address)
    end

    describe "idempotency" do
      it "does not create duplicate UserLearnings on re-run" do
        Rake::Task["anki:migrate_to_models"].reenable
        expect { run_task(user.email_address) }.not_to change(UserLearning, :count)
      end

      it "does not create duplicate ReviewLogs on re-run" do
        Rake::Task["anki:migrate_to_models"].reenable
        expect { run_task(user.email_address) }.not_to change(ReviewLog, :count)
      end
    end
  end
end
