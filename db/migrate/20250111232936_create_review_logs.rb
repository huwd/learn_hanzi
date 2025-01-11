class CreateReviewLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :review_logs do |t|
      t.references :user_learning, null: false, foreign_key: true
      t.integer :ease, null: false
      t.integer :interval
      t.integer :time_spent
      t.datetime :reviewed_at, null: false

      t.timestamps
    end

    add_index :review_logs, :reviewed_at
  end
end
