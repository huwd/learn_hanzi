module Mastery
  # Current tallies of Stable/Recovering/Chronic/Stalled among a user's
  # Developing+Established UserLearnings -- a live snapshot, not a trend
  # (see CoverageTimeline for the trend version). Query count is fixed
  # regardless of word count: recent_eases is only fetched for the small
  # Developing population, never for Established. See #391, README.md.
  class TrajectorySnapshot
    Bucket = Data.define(:key, :count, :percent)

    def self.call(user:)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      tallies = Hash.new(0)
      established_records.each { |ul| tallies[classify(ul, Coverage::ESTABLISHED, [])] += 1 }
      developing_records.each { |ul| tallies[classify(ul, Coverage::DEVELOPING, recent_eases[ul.id] || [])] += 1 }

      total = established_records.size + developing_records.size
      buckets = display_order.map do |key|
        count = tallies[key]
        Bucket.new(key: key, count: count, percent: total.zero? ? 0.0 : (count.to_f / total * 100).round(1))
      end

      { total: total, buckets: buckets }
    end

    private

    def classify(user_learning, coverage, recent_eases)
      Trajectory.call(user_learning: user_learning, coverage: coverage, recent_eases: recent_eases)
    end

    def display_order
      Trajectory::ALL - [ Trajectory::NOT_APPLICABLE ]
    end

    def established_records
      @established_records ||= @user.user_learnings
        .where.not(first_mastered_at: nil)
        .select(:id, :state, :graduation_count)
        .to_a
    end

    def developing_ids
      @developing_ids ||= @user.user_learnings
        .where(first_mastered_at: nil)
        .joins(:review_logs)
        .group(:id)
        .having("COUNT(review_logs.id) >= ?", Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT)
        .pluck(:id)
    end

    def developing_records
      @developing_records ||= @user.user_learnings
        .where(id: developing_ids)
        .select(:id, :state, :graduation_count)
        .to_a
    end

    def recent_eases
      @recent_eases ||= ReviewLog.where(user_learning_id: developing_ids)
        .order(:user_learning_id, created_at: :desc, time: :desc, id: :desc)
        .group_by(&:user_learning_id)
        .transform_values { |logs| logs.first(3).map(&:ease) }
    end
  end
end
