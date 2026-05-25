require "rails_helper"

RSpec.describe RelatedAnchorBuilder do
  describe ".call" do
    let(:user) { create(:user) }
    let(:target_entry) { create(:dictionary_entry, text: "学习") }
    let(:target_learning) do
      create(:user_learning, user: user, dictionary_entry: target_entry, state: "new")
    end

    # -------------------------------------------------------------------
    # Query count: proves one pluck replaces two LIKE scans.
    #
    # Before this fix, the builder fired two LIKE-scan queries per call
    # (one for full-token matches, one for per-character matches), both
    # doing full-table scans since leading-wildcard LIKE can't use an index.
    #
    # After: one pluck of (id, text) in frequency order; Ruby does the
    # filtering. Only 1 query fires when there are no results to load.
    # -------------------------------------------------------------------
    describe "query count" do
      before { user; target_learning }

      it "fires 1 query (mastered-entries pluck) when no mastered entries match" do
        queries = count_queries { described_class.call(user: user, target_learning: target_learning) }
        expect(queries).to eq(1),
          "expected only the mastered-entries pluck, got #{queries}"
      end
    end

    it "deduplicates entries that match both full token and characters" do
      overlapping_entry = create(:dictionary_entry, text: "学习班")
      overlapping_learning = create(:user_learning, user: user, dictionary_entry: overlapping_entry, state: "mastered")

      results = described_class.call(user: user, target_learning: target_learning, limit: 5)

      expect(results.count { |result| result.user_learning == overlapping_learning }).to eq(1)
    end

    it "orders full-token matches before per-character matches" do
      per_char_entry = create(:dictionary_entry, text: "学校", frequency_rank: 1)
      full_token_entry = create(:dictionary_entry, text: "学习者", frequency_rank: 300)

      per_char_learning = create(:user_learning, user: user, dictionary_entry: per_char_entry, state: "mastered")
      full_token_learning = create(:user_learning, user: user, dictionary_entry: full_token_entry, state: "mastered")

      results = described_class.call(user: user, target_learning: target_learning, limit: 5)

      expect(results.first.user_learning).to eq(full_token_learning)
      expect(results.second.user_learning).to eq(per_char_learning)
    end

    it "applies frequency rank and then text ordering within each bucket" do
      full_ranked_high = create(:dictionary_entry, text: "学习班", frequency_rank: 20)
      full_ranked_low = create(:dictionary_entry, text: "学习者", frequency_rank: 100)
      full_no_rank = create(:dictionary_entry, text: "学习力", frequency_rank: nil)

      per_ranked = create(:dictionary_entry, text: "学校", frequency_rank: 5)
      per_no_rank_b = create(:dictionary_entry, text: "习惯", frequency_rank: nil)
      per_no_rank_a = create(:dictionary_entry, text: "学子", frequency_rank: nil)

      create(:user_learning, user: user, dictionary_entry: full_ranked_low, state: "mastered")
      create(:user_learning, user: user, dictionary_entry: per_no_rank_b, state: "mastered")
      create(:user_learning, user: user, dictionary_entry: per_ranked, state: "mastered")
      create(:user_learning, user: user, dictionary_entry: full_ranked_high, state: "mastered")
      create(:user_learning, user: user, dictionary_entry: full_no_rank, state: "mastered")
      create(:user_learning, user: user, dictionary_entry: per_no_rank_a, state: "mastered")

      results = described_class.call(user: user, target_learning: target_learning, limit: 10)

      expect(results.map { |result| result.user_learning.dictionary_entry.text }).to eq(
        [ "学习班", "学习者", "学习力", "学校", "习惯", "学子" ]
      )
    end

    it "includes matched character metadata" do
      both_chars_entry = create(:dictionary_entry, text: "习学")
      create(:user_learning, user: user, dictionary_entry: both_chars_entry, state: "mastered")

      result = described_class.call(user: user, target_learning: target_learning, limit: 5).first

      expect(result.full_token_match).to be(false)
      expect(result.matched_characters).to eq([ "学", "习" ])
    end
  end
end
