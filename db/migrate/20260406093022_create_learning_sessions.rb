class CreateLearningSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :learning_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :state, null: false, default: "in_progress"
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :card_count, null: false, default: 0

      t.timestamps
    end
  end
end
