include DictionaryImportHelper

require "pry"

namespace :dictionary_import do
  desc "A Downloaded copy of the CC-CEDICT dictionary"
  task :cc_cedict, [:file_path] => :environment do |_task, args|
    file_path = if args[:file_path].nil?
      puts "No file path provided, defaulting to tmp/cedict_ts.u8"
      default_path = Rails.root.join("tmp", "cedict_ts.u8").to_s
      unless File.exist?(default_path)
        puts "Default file not found. Downloading..."
        Rake::Task["dictionary_download:cc_cedict"].invoke
      end
      default_path
    else
      args[:file_path]
    end

    puts "Processing CC-CEDICT file at #{file_path}..."

    find_or_create_cc_cedict_source(
      "CC-CEDICT",
      "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
    )

    source_header = []
    source_data = {}

    File.foreach(file_path) do |line|
      # Skip comments and blank lines
      next if line.start_with?("#") || line.strip.empty?

    end
  end
end
