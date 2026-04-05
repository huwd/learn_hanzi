class AnkiImportJob < ApplicationJob
  queue_as :default

  def perform(import_id, file_path)
    import = AnkiImport.find(import_id)
    import.update!(state: "running", started_at: Time.current)

    result = AnkiImportService.call(user: import.user, file_path: file_path)

    import.update!(
      state:                "complete",
      completed_at:         Time.current,
      cards_imported:       result[:cards_imported],
      review_logs_imported: result[:review_logs_imported]
    )
  rescue => e
    import&.update!(state: "failed", error_message: e.message)
    raise
  ensure
    FileUtils.rm_f(file_path)
  end
end
