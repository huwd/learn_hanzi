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
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    puts "#{file_lines} lines found in file"
    puts "#{DictionaryEntry.count} entries found in database"
    source = {
      name: "CC-CEDICT",
      url: "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
    }

    failed_lines = []
    error_count = 0
    logfile_path = Rails.root.join("log", "dictionary_import_errors.log")

    File.open(logfile_path, "a") do |logfile|
      File.foreach(file_path).with_index do |line, index|
        # Skip comments and blank lines
        next if line.start_with?("#") || line.strip.empty?
        progress = (index + 1).to_f / file_lines.to_f * 100
        print format("\rProcessing: %6.2f%% | Errors: %d", progress, error_count)
        $stdout.flush

        begin
          DictionaryImportHelper.find_or_create_dictionary_entry(line, source)
        rescue => e
          error_count += 1
          logfile.puts "Error processing line #{index + 1}: #{line.strip}"
          logfile.puts "Error: #{e.message}"
          next
        end
      end
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    puts "\nDone! Completed in #{elapsed.round(2)}s"
    puts "#{DictionaryEntry.count} entries found in database after import"
    puts "#{failed_lines.count} lines failed to import, listing lines:"
    failed_lines.each do |failed_line|
      puts failed_line[:line]
      puts failed_line[:error]
    end
  end

  desc "Import custom dictionary entries from db/custom_dictionary_entries.yml"
  task :custom_entries, [ :file_path ] => :environment do |_task, args|
    require "yaml"

    file_path = args[:file_path] || Rails.root.join("db", "custom_dictionary_entries.yml").to_s

    unless File.exist?(file_path)
      puts "[ERROR] File not found: #{file_path}"
      exit 1
    end

    source = Source.find_or_create_by!(name: "learn_hanzi")

    data    = YAML.load_file(file_path)
    entries = data["entries"]
    created = 0
    updated = 0

    entries.each do |entry_data|
      de     = DictionaryEntry.find_or_initialize_by(text: entry_data["text"])
      is_new = de.new_record?

      entry_data["meanings"].each do |m|
        next if de.meanings.exists?(text: m["text"], language: "en", source: source)
        de.meanings.build(text: m["text"], pinyin: m["pinyin"], language: "en", source: source)
      end

      de.save!
      is_new ? (created += 1) : (updated += 1)
    end

    puts "Done! #{created} entries created, #{updated} already existed."
  end
end
