class AddMasteredAtToUserLearnings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_learnings, :mastered_at, :datetime
  end
end
