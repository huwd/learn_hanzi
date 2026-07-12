require "rails_helper"

RSpec.describe Mastery::RecentEases do
  include QueryCounter

  let(:user) { create(:user) }

  describe ".call" do
    it "returns an empty hash for an empty id list without querying" do
      expect(count_queries { described_class.call(user_learning_ids: []) }).to eq(0)
      expect(described_class.call(user_learning_ids: [])).to eq({})
    end

    it "returns the most recent eases per user_learning, newest first" do
      ul = create(:user_learning, user: user, state: "learning")
      create(:review_log, user_learning: ul, ease: 4, created_at: 3.days.ago)
      create(:review_log, user_learning: ul, ease: 3, created_at: 2.days.ago)
      create(:review_log, user_learning: ul, ease: 2, created_at: 1.day.ago)

      result = described_class.call(user_learning_ids: [ ul.id ])
      expect(result[ul.id]).to eq([ 2, 3, 4 ])
    end

    it "bounds the result to STALLED_LOOKBACK_REVIEWS per word" do
      ul = create(:user_learning, user: user, state: "learning")
      5.times { |n| create(:review_log, user_learning: ul, ease: n + 1, created_at: (5 - n).days.ago) }

      result = described_class.call(user_learning_ids: [ ul.id ])
      expect(result[ul.id].size).to eq(Mastery::Thresholds::STALLED_LOOKBACK_REVIEWS)
    end

    it "keys results by user_learning_id across multiple words" do
      ul_a = create(:user_learning, user: user, state: "learning", dictionary_entry: create(:dictionary_entry))
      ul_b = create(:user_learning, user: user, state: "learning", dictionary_entry: create(:dictionary_entry))
      create(:review_log, user_learning: ul_a, ease: 1)
      create(:review_log, user_learning: ul_b, ease: 4)

      result = described_class.call(user_learning_ids: [ ul_a.id, ul_b.id ])
      expect(result[ul_a.id]).to eq([ 1 ])
      expect(result[ul_b.id]).to eq([ 4 ])
    end
  end
end
