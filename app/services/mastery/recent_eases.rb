module Mastery
  # Bounded to (at most) STALLED_LOOKBACK_REVIEWS rows per UserLearning via a
  # window function, rather than loading every review_log a word has ever
  # had. Shared by TrajectorySnapshot and TrajectoryEntries -- both need
  # "last N eases per word" for the same Stalled check. See #391, #400.
  class RecentEases
    def self.call(user_learning_ids:)
      return {} if user_learning_ids.empty?

      sql = ReviewLog.sanitize_sql_array([ <<~SQL, user_learning_ids ])
        SELECT user_learning_id, ease FROM (
          SELECT user_learning_id, ease,
                 ROW_NUMBER() OVER (
                   PARTITION BY user_learning_id
                   ORDER BY created_at DESC, time DESC, id DESC
                 ) AS rn
          FROM review_logs
          WHERE user_learning_id IN (?)
        ) ranked WHERE rn <= #{Thresholds::STALLED_LOOKBACK_REVIEWS}
        ORDER BY user_learning_id, rn
      SQL

      ReviewLog.connection.select_all(sql).each_with_object(Hash.new { |h, k| h[k] = [] }) do |row, memo|
        memo[row["user_learning_id"]] << row["ease"]
      end
    end
  end
end
