class AnkiImportsController < ApplicationController
  ALLOWED_CONTENT_TYPES = %w[application/octet-stream application/zip].freeze
  MAX_FILE_SIZE = 50 * 1024 * 1024 # 50 MB
  SQLITE_MAGIC = "SQLite format 3\x00"

  def new
    @recent_imports = Current.user.anki_imports.recent.limit(10)
  end

  def create
    file = params[:file]

    unless file.present?
      redirect_to new_anki_import_path, alert: "Please select a file to upload."
      return
    end

    unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
      redirect_to new_anki_import_path, alert: "Unsupported file type. Please upload an Anki collection file."
      return
    end

    if file.size > MAX_FILE_SIZE
      redirect_to new_anki_import_path, alert: "File is too large. Maximum size is 50 MB."
      return
    end

    if Current.user.anki_imports.in_progress.exists?
      redirect_to new_anki_import_path, alert: "An import is already in progress. Please wait for it to finish."
      return
    end

    unless sqlite_file?(file.tempfile)
      redirect_to new_anki_import_path, alert: "File does not appear to be a valid Anki collection."
      return
    end

    dest = import_storage_path
    FileUtils.mkdir_p(File.dirname(dest))
    FileUtils.cp(file.tempfile.path, dest)

    import = Current.user.anki_imports.create!(state: "pending")
    AnkiImportJob.perform_later(import.id, dest)

    redirect_to anki_import_path(import)
  end

  def show
    @import = Current.user.anki_imports.find(params[:id])
  end

  private

  def import_storage_path
    Rails.root.join("tmp", "anki_imports", "#{SecureRandom.uuid}.anki21").to_s
  end

  def sqlite_file?(tempfile)
    tempfile.rewind
    tempfile.read(16) == SQLITE_MAGIC
  ensure
    tempfile.rewind
  end
end
