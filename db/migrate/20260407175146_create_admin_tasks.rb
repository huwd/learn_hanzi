class CreateAdminTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_tasks do |t|
      t.string :task_type, null: false
      t.string :state, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.text :summary
      t.text :error_message

      t.timestamps
    end
  end
end
