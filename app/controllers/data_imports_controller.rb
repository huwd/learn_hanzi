class DataImportsController < ApplicationController
  ALLOWED_CONTENT_TYPES = %w[application/json text/json text/plain].freeze
  MAX_FILE_SIZE = 10 * 1024 * 1024 # 10 MB

  def new; end

  def create
    file = params[:file]

    unless file.present?
      redirect_to new_data_import_path, alert: "Please select a file to upload."
      return
    end

    unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
      redirect_to new_data_import_path, alert: "Unsupported file type. Please upload a JSON export file."
      return
    end

    if file.size > MAX_FILE_SIZE
      redirect_to new_data_import_path, alert: "File is too large. Maximum size is 10 MB."
      return
    end

    data   = JSON.parse(file.read)
    result = DataImportService.call(user: Current.user, data:)

    redirect_to new_data_import_path,
                notice: "Import complete: #{result[:learnings_upserted]} learnings updated, " \
                        "#{result[:review_logs_inserted]} review logs imported."
  rescue JSON::ParserError
    redirect_to new_data_import_path, alert: "Invalid JSON file. Please upload a valid export."
  rescue DataImportService::UnsupportedVersionError => e
    redirect_to new_data_import_path, alert: "Unsupported export format. #{e.message}"
  rescue StandardError
    redirect_to new_data_import_path,
                alert: "Import failed. The file may be corrupt or not a valid export."
  end
end
