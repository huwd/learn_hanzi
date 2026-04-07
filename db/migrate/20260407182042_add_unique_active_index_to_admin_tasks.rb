class AddUniqueActiveIndexToAdminTasks < ActiveRecord::Migration[8.1]
  def change
    # Prevents concurrent requests from enqueuing duplicate tasks at the DB
    # level. The partial condition means only one pending/running task can
    # exist per task_type at any time; completed/failed records are excluded
    # so history is preserved.
    add_index :admin_tasks, :task_type,
              unique: true,
              where: "state IN ('pending', 'running')",
              name: "index_admin_tasks_one_active_per_type"
  end
end
