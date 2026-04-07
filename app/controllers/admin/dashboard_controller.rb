module Admin
  class DashboardController < BaseController
    TASK_TYPES_IN_ORDER = %w[cc_cedict custom_dictionary hsk_tags].freeze

    def index
      @tasks_by_type = AdminTask::VALID_TASK_TYPES.index_with do |type|
        AdminTask.latest_for(type)
      end
      @history        = AdminTask.recent.limit(50)
      @any_in_progress = AdminTask.in_progress.exists?
      @db_stats       = current_db_stats
    end

    def provision_all
      enqueued = 0
      TASK_TYPES_IN_ORDER.each do |type|
        next if AdminTask.locked_for?(type)

        task = AdminTask.create!(task_type: type, state: "pending")
        Admin::ProvisioningJob.perform_later(task.id)
        enqueued += 1
      end

      if enqueued > 0
        redirect_to admin_root_path, notice: "#{enqueued} task(s) queued."
      else
        redirect_to admin_root_path, alert: "All tasks are already running or pending."
      end
    end

    private

    def current_db_stats
      {
        dictionary_entries: DictionaryEntry.count,
        hsk_tags:           Tag.where(category: "HSK").count,
        custom_sources:     Source.where(name: "learn_hanzi").exists?
      }
    end
  end
end
