class AddFactorToUserLearnings < ActiveRecord::Migration[8.0]
  def change
    add_column :user_learnings, :factor, :integer, default: 2500, null: false
  end
end
