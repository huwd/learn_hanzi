class DataImportsController < ApplicationController
  MAX_FILE_SIZE = 10 * 1024 * 1024 # 10 MB

  def new; end

  def create
    file = params[:file]

    unless file.present?
      redirect_to new_data_import_path, alert: "Please select a file to upload."
      return
    end

    if file.size > MAX_FILE_SIZE
      redirect_to new_data_import_path, alert: "File is too large. Maximum size is 10 MB."
      return
    end

    data = JSON.parse(file.read)
    result = DataImportService.call(user: Current.user, data:)

    redirect_to new_data_import_path,
                notice: "Import complete: #{result[:learnings_upserted]} learnings updated, " \
                        "#{result[:review_logs_inserted]} review logs processed."
  rescue JSON::ParserError
    redirect_to new_data_import_path, alert: "Invalid JSON file. Please upload a valid export."
  rescue DataImportService::UnsupportedVersionError => e
    redirect_to new_data_import_path, alert: "Unsupported export format. #{e.message}"
  end
end
