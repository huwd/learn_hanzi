require_relative "../../app/helpers/import_files_helper"

include ImportFilesHelper

namespace :makemeahanzi do
  DICTIONARY_URL = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/dictionary.txt"
  GRAPHICS_URL = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt"

  desc "Download makemeahanzi dictionary and graphics data"
  task download: :environment do
    output_dir = Rails.root.join("tmp", "makemeahanzi")

    dictionary_path = output_dir.join("dictionary.txt")
    graphics_path = output_dir.join("graphics.txt")

    download_file_to_tmp(DICTIONARY_URL, dictionary_path)
    download_file_to_tmp(GRAPHICS_URL, graphics_path)
    confirm_file_presence("dictionary.txt", output_dir)
    confirm_file_presence("graphics.txt", output_dir)
  end
end
