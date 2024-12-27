require_relative "../../app/helpers/import_files_helper"

include ImportFilesHelper

namespace :dictionary_download do
  CEDICT_URL = "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"

  desc "Download and unzip the CC-CEDICT dictionary"
  task cc_cedict: :environment do
    temp_zip_path = Rails.root.join("tmp", "cedict.zip")
    unzip_dir = Rails.root.join("tmp", "cedict")

    ImportFilesHelper.download_file_to_tmp(CEDICT_URL, temp_zip_path)
    ImportFilesHelper.unzip_file(temp_zip_path, unzip_dir)
    ImportFilesHelper.confirm_file_presence("*cedict*", unzip_dir)
  end
end
