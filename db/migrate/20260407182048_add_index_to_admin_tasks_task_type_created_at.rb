class AddIndexToAdminTasksTaskTypeCreatedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :admin_tasks, [ :task_type, :created_at ]
  end
end
