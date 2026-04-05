module Admin
  class AnkiImportsController < ApplicationController
    ALLOWED_CONTENT_TYPES = %w[application/octet-stream application/zip].freeze

    def new
      @recent_imports = Current.user.anki_imports.recent.limit(10)
    end

    def create
      file = params[:file]

      unless file.present?
        redirect_to new_admin_anki_import_path, alert: "Please select a file to upload."
        return
      end

      unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
        redirect_to new_admin_anki_import_path, alert: "Unsupported file type. Please upload an Anki collection file."
        return
      end

      dest = import_storage_path
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(file.tempfile.path, dest)

      import = Current.user.anki_imports.create!(state: "pending")
      AnkiImportJob.perform_later(import.id, dest)

      redirect_to admin_anki_import_path(import)
    end

    def show
      @import = Current.user.anki_imports.find(params[:id])
    end

    private

    def import_storage_path
      Rails.root.join("tmp", "anki_imports", "#{SecureRandom.uuid}.anki21").to_s
    end
  end
end
