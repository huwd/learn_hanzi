class BackfillMasteredAtFromUpdatedAt < ActiveRecord::Migration[8.1]
  def up
    # Use updated_at as a proxy for existing mastered records that predate the mastered_at column.
    # Imperfect (updated_at shifts on every subsequent review) but the best available approximation
    # for historical data imported before the column existed.
    UserLearning.where(state: "mastered", mastered_at: nil)
                .update_all("mastered_at = updated_at")
  end

  def down
    # Irreversible: cannot distinguish backfilled values from values set by the callback.
  end
end
