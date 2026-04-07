module Admin
  class TasksController < BaseController
    def create
      task_type = params[:task_type]

      unless AdminTask::VALID_TASK_TYPES.include?(task_type)
        return redirect_to admin_root_path, alert: "Unknown task type."
      end

      task = AdminTask.create!(task_type: task_type, state: "pending")
      Admin::ProvisioningJob.perform_later(task.id)
      redirect_to admin_root_path, notice: "#{task_type} task queued."
    rescue ActiveRecord::RecordNotUnique
      redirect_to admin_root_path,
                  alert: "A #{task_type} task is already running or pending."
    end

    def retry
      task = AdminTask.find(params[:id])

      unless task.failed?
        return redirect_to admin_root_path,
                           alert: "Only failed tasks can be retried."
      end

      task.update!(state: "pending", error_message: nil, summary: nil,
                   started_at: nil, completed_at: nil)
      Admin::ProvisioningJob.perform_later(task.id)
      redirect_to admin_root_path, notice: "#{task.task_type} task re-queued."
    rescue ActiveRecord::RecordNotUnique
      redirect_to admin_root_path,
                  alert: "A #{task.task_type} task is already running or pending."
    end
  end
end
