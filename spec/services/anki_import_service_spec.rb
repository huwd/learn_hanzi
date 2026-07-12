require 'rails_helper'

RSpec.describe AnkiImportService do
  # Uses the same Anki test DB seeded by AnkiHelper (recreated before the suite).
  # The seed data mirrors anki_spec.rb: cards for 好, 很, 学, 习, 中, 文, 国, 爱
  # with 不 having no DictionaryEntry (tests the skip path).

  let(:user) { create(:user) }

  let!(:entry_hao)  { create(:dictionary_entry, text: "好") }
  let!(:entry_hen)  { create(:dictionary_entry, text: "很") }
  let!(:entry_xue)  { create(:dictionary_entry, text: "学") }
  let!(:entry_xi)   { create(:dictionary_entry, text: "习") }
  let!(:entry_zhong) { create(:dictionary_entry, text: "中") }
  let!(:entry_wen)  { create(:dictionary_entry, text: "文") }
  let!(:entry_guo)  { create(:dictionary_entry, text: "国") }
  let!(:entry_ai)   { create(:dictionary_entry, text: "爱") }
  let!(:entry_xiexie) { create(:dictionary_entry, text: "谢谢") }
  # 不 has no entry — tests skip behaviour

  describe ".call" do
    subject(:result) { described_class.call(user: user, file_path: AnkiHelper.test_db_path) }

    it "returns a result with cards_imported count" do
      expect(result[:cards_imported]).to be > 0
    end

    it "returns a result with review_logs_imported count" do
      expect(result[:review_logs_imported]).to be > 0
    end

    it "returns a skipped list" do
      expect(result[:skipped]).to be_an(Array)
    end

    it "creates UserLearning records for matched cards" do
      expect { result }.to change { UserLearning.count }.by_at_least(1)
    end

    it "creates ReviewLog records for revlog entries" do
      expect { result }.to change { ReviewLog.count }.by_at_least(1)
    end

    it "sets correct states from Anki queue values" do
      result
      hao_learning = UserLearning.find_by(user: user, dictionary_entry: entry_hao)
      expect(hao_learning&.state).to eq("mastered") # queue 2 in seed data
    end

    it "skips characters with no matching DictionaryEntry" do
      result
      expect(result[:skipped]).to include("不")
    end

    it "backfills first_mastered_at and graduation_count from replayed review history" do
      # UserLearning.insert_all/ReviewLog.insert_all bypass every
      # ActiveRecord callback, so these milestones only get set by the
      # explicit post-import Mastery::MilestoneReplay backfill. 谢谢's two
      # revlogs (ease 3, 3) graduate it when replayed. See #391.
      result
      xiexie_learning = UserLearning.find_by(user: user, dictionary_entry: entry_xiexie)
      expect(xiexie_learning.first_mastered_at).to be_present
      expect(xiexie_learning.graduation_count).to eq(1)
    end

    it "leaves first_mastered_at nil for a card whose single revlog never reaches mastered" do
      # 好 has one revlog (ease 2): new -> learning only, never graduates --
      # even though its imported `state` column says "mastered" from
      # Anki's queue value. This mismatch is inherent and already accepted
      # for first_mastered_at/graduation_count (#394/#395): they describe
      # this app's own SM2 semantics applied to observed history, not
      # whatever Anki's queue said.
      result
      hao_learning = UserLearning.find_by(user: user, dictionary_entry: entry_hao)
      expect(hao_learning.first_mastered_at).to be_nil
      expect(hao_learning.graduation_count).to eq(0)
    end

    it "is idempotent — running twice does not duplicate UserLearning records" do
      described_class.call(user: user, file_path: AnkiHelper.test_db_path)
      expect { described_class.call(user: user, file_path: AnkiHelper.test_db_path) }.not_to change { UserLearning.count }
    end

    it "is idempotent — running twice does not duplicate ReviewLog records" do
      described_class.call(user: user, file_path: AnkiHelper.test_db_path)
      expect { described_class.call(user: user, file_path: AnkiHelper.test_db_path) }.not_to change { ReviewLog.count }
    end
  end
end
