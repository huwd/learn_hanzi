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
  # 不 has no entry — tests skip behaviour

  describe ".call" do
    subject(:result) { described_class.call(user: user, file_path: AnkiHelper.test_db_path) }

    it "returns a result with cards_imported count" do
      expect(result[:cards_imported]).to be > 0
    end

    it "returns a result with review_logs_imported count" do
      expect(result[:review_logs_imported]).to be >= 0
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
