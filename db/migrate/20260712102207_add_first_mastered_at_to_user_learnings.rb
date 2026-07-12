class AddFirstMasteredAtToUserLearnings < ActiveRecord::Migration[8.1]
  def change
    # Durable "did this word ever graduate, and when" — unlike mastered_at,
    # never cleared on lapse. See #391.
    add_column :user_learnings, :first_mastered_at, :datetime
    add_index :user_learnings, :first_mastered_at
  end
end
