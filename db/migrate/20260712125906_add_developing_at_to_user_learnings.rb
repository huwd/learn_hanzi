class AddDevelopingAtToUserLearnings < ActiveRecord::Migration[8.1]
  def change
    # Durable milestone: the moment review_count first reached
    # Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT while the
    # word had not yet graduated. Never cleared once set -- feeds the
    # Coverage-over-time chart the same way first_mastered_at feeds
    # Established, avoiding a review_logs replay per word per request.
    # See #391, app/services/mastery/README.md.
    add_column :user_learnings, :developing_at, :datetime
    add_index :user_learnings, :developing_at
  end
end
