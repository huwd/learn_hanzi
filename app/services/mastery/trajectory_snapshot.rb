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

    # Bounded to (at most) STALLED_LOOKBACK_REVIEWS rows per Developing
    # word via a window function, rather than loading every review_log a
    # word has ever had (some in the real data have 40+) just to keep the
    # last few.
    def recent_eases
      return @recent_eases ||= {} if developing_ids.empty?

      sql = ReviewLog.sanitize_sql_array([ <<~SQL, developing_ids ])
        SELECT user_learning_id, ease FROM (
          SELECT user_learning_id, ease,
                 ROW_NUMBER() OVER (
                   PARTITION BY user_learning_id
                   ORDER BY created_at DESC, time DESC, id DESC
                 ) AS rn
          FROM review_logs
          WHERE user_learning_id IN (?)
        ) ranked WHERE rn <= #{Thresholds::STALLED_LOOKBACK_REVIEWS}
      SQL

      @recent_eases ||= ReviewLog.connection.select_all(sql).each_with_object(Hash.new { |h, k| h[k] = [] }) do |row, memo|
        memo[row["user_learning_id"]] << row["ease"]
      end
    end
  end
end
