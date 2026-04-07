module Admin
  class TasksController < BaseController
    def create
      task_type = params[:task_type]

      if AdminTask.locked_for?(task_type)
        return redirect_to admin_root_path,
                           alert: "A #{task_type} task is already running or pending."
      end

      task = AdminTask.create!(task_type: task_type, state: "pending")
      Admin::ProvisioningJob.perform_later(task.id)
      redirect_to admin_root_path, notice: "#{task_type} task queued."
    end

    def retry
      task = AdminTask.find(params[:id])

      unless task.failed?
        return redirect_to admin_root_path,
                           alert: "Only failed tasks can be retried."
      end

      task.update!(state: "pending", error_message: nil, started_at: nil, completed_at: nil)
      Admin::ProvisioningJob.perform_later(task.id)
      redirect_to admin_root_path, notice: "#{task.task_type} task re-queued."
    end
  end
end
