class CreateLearningSessionCards < ActiveRecord::Migration[8.1]
  def change
    create_table :learning_session_cards do |t|
      t.references :learning_session, null: false, foreign_key: true
      t.references :user_learning, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :ease
      t.datetime :reviewed_at

      t.timestamps
    end
  end
end
