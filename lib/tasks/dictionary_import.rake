require_relative "../../app/helpers/dictionary_import_helper"

include DictionaryImportHelper

namespace :dictionary_import do
  desc "A Downloaded copy of the CC-CEDICT dictionary"
  task :cc_cedict, [ :file_path ] => :environment do |_task, args|
    file_path = if args[:file_path].nil?
      puts "No file path provided, defaulting to tmp/cedict_ts.u8"
      Rails.root.join("tmp", "cedict", "cedict_ts.u8").to_s
    else
      args[:file_path]
    end

    unless File.exist?(file_path)
      raise "File not found at #{file_path}"
    end

    puts "Processing CC-CEDICT file at #{file_path}..."
    file_lines = File.foreach(file_path).count

    puts "#{file_lines} lines found in file"
    puts "#{DictionaryEntry.count} entries found in database"
    source = {
      name: "CC-CEDICT",
      url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
    }

    failed_lines = []

    File.foreach(file_path).with_index do |line, index|
      # Skip comments and blank lines
      next if line.start_with?("#") || line.strip.empty?
      progress = ((index + 1).to_f / file_lines.to_f * 100).round(2)
      print "\rProcessing: #{progress}%"
      $stdout.flush

      begin
        DictionaryImportHelper.find_or_create_dictionary_entry(line, source)
      rescue => e
        failed_lines << { line: line, error: e }
      end

      DictionaryImportHelper.find_or_create_dictionary_entry(line, source)
    end
    puts "\nDone!"
    puts "#{DictionaryEntry.count} entries found in database after import"
    puts "#{failed_lines.count} lines failed to import, listing lines:"
    failed_lines.each do |failed_line|
      puts failed_line[:line]
      puts failed_line[:error]
    end
  end
end
