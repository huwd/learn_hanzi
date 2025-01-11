class CreateUserLearnings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_learnings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :dictionary_entry, null: false, foreign_key: true
      t.string :state, null: false
      t.datetime :next_due
      t.integer :last_interval

      t.timestamps
    end

    add_index :user_learnings, [ :user_id, :dictionary_entry_id ], unique: true, name: 'index_user_learnings_on_user_and_entry'
  end
end
