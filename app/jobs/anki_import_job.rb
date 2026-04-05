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
    Rails.logger.error(
      [
        "AnkiImportJob failed for import_id=#{import_id}",
        "#{e.class}: #{e.message}",
        *Array(e.backtrace)
      ].join("\n")
    )
    import&.update!(
      state:         "failed",
      completed_at:  Time.current,
      error_message: "Import failed. Please verify the file is a valid Anki collection and try again."
    )
    raise
  ensure
    FileUtils.rm_f(file_path)
  end
end
