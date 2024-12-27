require_relative "../../app/helpers/dictionary_import_helper"

include DictionaryImportHelper

namespace :dictionary_import do
  desc "A Downloaded copy of the CC-CEDICT dictionary"
  task :cc_cedict, [ :file_path ] => :environment do |_task, args|
    file_path = if args[:file_path].nil?
      puts "No file path provided, defaulting to tmp/cedict_ts.u8"
      Rails.root.join("tmp", "cedict_ts.u8").to_s
    else
      args[:file_path]
    end

    unless File.exist?(file_path)
      raise "File not found at #{file_path}"
    end

    puts "Processing CC-CEDICT file at #{file_path}..."

    File.foreach(file_path) do |line|
      # Skip comments and blank lines
      next if line.start_with?("#") || line.strip.empty?

      DictionaryImportHelper.find_or_create_dictionary_entry(line, { name: "CC-CEDICT", url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip" })
    end
  end
end
