module Admin
  class ProvisioningJob < ApplicationJob
    queue_as :default

    SERVICE_MAP = {
      "cc_cedict"          => Admin::CcCedictProvisioningService,
      "hsk_tags"           => Admin::HskTagsProvisioningService,
      "custom_dictionary"  => Admin::CustomDictionaryProvisioningService
    }.freeze

    def perform(task_id)
      task = AdminTask.find(task_id)
      task.update!(state: "running", started_at: Time.current)

      service = SERVICE_MAP.fetch(task.task_type)
      result  = service.call

      task.update!(
        state:        "complete",
        completed_at: Time.current,
        summary:      result.to_json
      )
    rescue => e
      Rails.logger.error(
        [
          "Admin::ProvisioningJob failed for task_id=#{task_id}",
          "#{e.class}: #{e.message}",
          *Array(e.backtrace)
        ].join("\n")
      )
      task&.update!(
        state:         "failed",
        completed_at:  Time.current,
        error_message: "#{e.class}: #{e.message}"
      )
      raise
    end
  end
end
