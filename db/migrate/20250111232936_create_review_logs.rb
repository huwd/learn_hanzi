class CreateReviewLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :review_logs do |t|
      t.references :user_learning, null: false, foreign_key: true
      t.integer :anki_id
      t.integer :ease, null: false
      t.integer :interval
      t.integer :time_spent
      t.integer :factor
      t.integer :time
      t.integer :log_type

      t.timestamps
    end
  end
end
