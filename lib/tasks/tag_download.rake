require_relative "../../app/helpers/import_files_helper"

include ImportFilesHelper

namespace :tag_download do
  HSK_2_REPO_ROOT = "https://raw.githubusercontent.com/drkameleon/complete-hsk-vocabulary/main/wordlists/exclusive/"
  HSK_2_FILES = (1..6).to_a.map { |lvl| HSK_2_REPO_ROOT + "old/#{lvl}.min.json" }

  HSK_3_TXT_ROOT = "https://raw.githubusercontent.com/krmanik/HSK-3.0/main/New%20HSK%20(2021)/HSK%20List/"
  HSK_3_TSV_ROOT = "https://raw.githubusercontent.com/krmanik/HSK-3.0/main/Scripts%20and%20data/tsv/"
  HSK_3_LEVELS   = [ "HSK 1", "HSK 2", "HSK 3", "HSK 4", "HSK 5", "HSK 6", "HSK 7-9" ].freeze

  desc "Download HSK 2 files"
  task hsk_2: :environment do
    file_dir = Rails.root.join("tmp", "hsk_2")

    HSK_2_FILES.each do |file_url|
      file_name = file_url.split("old/")[-1]
      file_path = Rails.root.join(file_dir, file_name)
      ImportFilesHelper.download_file_to_tmp(file_url, file_path)
      ImportFilesHelper.confirm_file_presence(file_name, file_dir)
    end
  end

  desc "Download HSK 3 files (word lists + TSV fallback for CC-CEDICT stubs)"
  task hsk_3: :environment do
    file_dir = Rails.root.join("tmp", "hsk_3")

    HSK_3_LEVELS.each do |level|
      txt_name = "#{level}.txt"
      ImportFilesHelper.download_file_to_tmp(
        HSK_3_TXT_ROOT + txt_name.gsub(" ", "%20"),
        Rails.root.join(file_dir, txt_name)
      )
      ImportFilesHelper.confirm_file_presence(txt_name, file_dir)

      tsv_name = "#{level}.tsv"
      ImportFilesHelper.download_file_to_tmp(
        HSK_3_TSV_ROOT + tsv_name.gsub(" ", "%20"),
        Rails.root.join(file_dir, tsv_name)
      )
      ImportFilesHelper.confirm_file_presence(tsv_name, file_dir)
    end
  end
end
