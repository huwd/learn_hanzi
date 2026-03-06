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

    pre_loaded_source = DictionaryImportHelper.find_or_create_cc_cedict_source(
      "CC-CEDICT",
      "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"
    )

    puts "Reading file..."
    lines = File.readlines(file_path)
    print "Importing..."
    $stdout.flush

    DictionaryImportHelper.batch_import_cc_cedict_lines(lines, pre_loaded_source)

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    puts "\nDone! Completed in #{elapsed.round(2)}s"
    puts "#{DictionaryEntry.count} entries found in database after import"
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
