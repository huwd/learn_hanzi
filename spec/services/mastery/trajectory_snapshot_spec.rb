require 'rails_helper'

RSpec.describe Mastery::TrajectorySnapshot do
  include QueryCounter

  let(:user) { create(:user) }
  let(:threshold) { Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT }

  def bucket_for(result, key)
    result[:buckets].find { |b| b.key == key }
  end

  describe ".call" do
    it "returns zeroed buckets and total when there is nothing to classify" do
      result = described_class.call(user: user)

      expect(result[:total]).to eq(0)
      expect(result[:buckets].map(&:count)).to all(eq(0))
      expect(result[:buckets].map(&:percent)).to all(eq(0.0))
    end

    it "returns buckets in Stable, Recovering, Chronic, Stalled order" do
      result = described_class.call(user: user)
      expect(result[:buckets].map(&:key)).to eq([
        Mastery::Trajectory::STABLE,
        Mastery::Trajectory::RECOVERING,
        Mastery::Trajectory::CHRONIC,
        Mastery::Trajectory::STALLED
      ])
    end

    it "classifies a word that graduated once and is still mastered as Stable" do
      ul = create(:user_learning, user: user, state: "learning")
      create(:review_log, user_learning: ul, ease: 3)
      ul.update!(state: "mastered")

      result = described_class.call(user: user)
      expect(bucket_for(result, Mastery::Trajectory::STABLE).count).to eq(1)
    end

    it "classifies a word that graduated twice as Chronic" do
      ul = create(:user_learning, user: user, state: "learning")
      create(:review_log, user_learning: ul, ease: 3)
      ul.update!(state: "mastered")
      ul.update!(state: "learning")
      create(:review_log, user_learning: ul, ease: 3)
      ul.update!(state: "mastered")

      result = described_class.call(user: user)
      expect(bucket_for(result, Mastery::Trajectory::CHRONIC).count).to eq(1)
    end

    it "classifies a word that graduated once and has since lapsed as Recovering" do
      ul = create(:user_learning, user: user, state: "learning")
      create(:review_log, user_learning: ul, ease: 3)
      ul.update!(state: "mastered")
      ul.update!(state: "learning")

      result = described_class.call(user: user)
      expect(bucket_for(result, Mastery::Trajectory::RECOVERING).count).to eq(1)
    end

    it "classifies a never-graduated word past the threshold with flat ease as Stalled" do
      ul = create(:user_learning, user: user, state: "learning")
      threshold.times { create(:review_log, user_learning: ul, ease: 1) }

      result = described_class.call(user: user)
      expect(bucket_for(result, Mastery::Trajectory::STALLED).count).to eq(1)
    end

    it "classifies a never-graduated word past the threshold with improving ease as Stable" do
      ul = create(:user_learning, user: user, state: "learning")
      (threshold - 3).times { create(:review_log, user_learning: ul, ease: 1) }
      create(:review_log, user_learning: ul, ease: 3)
      create(:review_log, user_learning: ul, ease: 3)
      create(:review_log, user_learning: ul, ease: 4)

      result = described_class.call(user: user)
      expect(bucket_for(result, Mastery::Trajectory::STABLE).count).to eq(1)
    end

    it "excludes words below the Developing threshold entirely" do
      ul = create(:user_learning, user: user, state: "learning")
      create(:review_log, user_learning: ul, ease: 1)

      result = described_class.call(user: user)
      expect(result[:total]).to eq(0)
    end

    it "only classifies the given user's words" do
      other_user = create(:user)
      ul = create(:user_learning, user: other_user, state: "learning")
      create(:review_log, user_learning: ul, ease: 3)
      ul.update!(state: "mastered")

      result = described_class.call(user: user)
      expect(result[:total]).to eq(0)
    end

    it "computes percent share of the total population" do
      3.times do
        ul = create(:user_learning, user: user, state: "learning", dictionary_entry: create(:dictionary_entry))
        create(:review_log, user_learning: ul, ease: 3)
        ul.update!(state: "mastered")
      end
      chronic = create(:user_learning, user: user, state: "learning", dictionary_entry: create(:dictionary_entry))
      create(:review_log, user_learning: chronic, ease: 3)
      chronic.update!(state: "mastered")
      chronic.update!(state: "learning")
      create(:review_log, user_learning: chronic, ease: 3)
      chronic.update!(state: "mastered")

      result = described_class.call(user: user)
      expect(result[:total]).to eq(4)
      expect(bucket_for(result, Mastery::Trajectory::STABLE).percent).to eq(75.0)
      expect(bucket_for(result, Mastery::Trajectory::CHRONIC).percent).to eq(25.0)
    end

    it "keeps the query count bounded regardless of word count" do
      # Rails short-circuits `where(id: [])` without a query, so an empty
      # Developing population legitimately uses fewer queries than a
      # non-empty one -- compare two non-empty populations instead, where
      # the same fixed set of queries should fire regardless of size.
      seed_developing_word = lambda do
        ul = create(:user_learning, user: user, state: "learning", dictionary_entry: create(:dictionary_entry))
        threshold.times { create(:review_log, user_learning: ul, ease: 1) }
      end
      seed_developing_word.call

      count_with_few = count_queries { described_class.call(user: user) }

      15.times { seed_developing_word.call }

      count_with_many = count_queries { described_class.call(user: user) }
      expect(count_with_many).to eq(count_with_few)
    end
  end
end
