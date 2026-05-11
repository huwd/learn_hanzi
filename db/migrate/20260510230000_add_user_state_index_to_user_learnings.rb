class AddUserStateIndexToUserLearnings < ActiveRecord::Migration[8.1]
  def change
    add_index :user_learnings, [ :user_id, :state ],
      name: "index_user_learnings_on_user_and_state",
      if_not_exists: true
  end
end
