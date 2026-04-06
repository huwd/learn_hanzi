require_relative "../../app/helpers/tag_import_helper"

include TagImportHelper

namespace :tag_import do
  desc "A Downloaded copy of hsk 2 vocab"
  task :hsk_2, [ :file_path ] => :environment do |_task, args|
    hsk_level_files = hsk_file_paths_for_level(args, "hsk_2")
    parent_tag = find_or_create_top_level_tags("HSK 2.0")
    import_hsk_file(hsk_level_files, parent_tag)
  end

  desc "A Downloaded copy of hsk 3 vocab"
  task :hsk_3, [ :file_path ] => :environment do |_task, args|
    hsk_level_files = hsk_file_paths_for_level(args, "hsk_3")
    parent_tag = find_or_create_top_level_tags("HSK 3.0")
    import_hsk_file(hsk_level_files, parent_tag)
  end
end

def find_or_create_top_level_tags(hsk_version)
    top_tag = find_or_create_tag("HSK", "HSK")
    parent_tag = find_or_create_tag(hsk_version, "HSK", top_tag.id)
    top_tag.add_child(parent_tag)
    parent_tag
end

def hsk_file_paths_for_level(args, folder_name)
    file_path = if args[:file_path].nil?
      Rails.root.join("tmp", folder_name).to_s
    else
      args[:file_path]
    end

    hsk_level_files = Dir.glob(File.join(file_path, "*"))

    unless hsk_level_files.any?
      raise "No files found at #{file_path}"
    end

    hsk_level_files
end

def import_hsk_file(hsk_level_files, parent_tag)
    file_count = hsk_level_files.count
    logfile_path = Rails.root.join("log", "tag_import_errors.log")
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    total_skipped = 0

    File.open(logfile_path, "a") do |logfile|
      hsk_level_files.each.with_index do |file, file_index|
        tag_name = tag_name_from_file(file)
        tag = find_or_create_tag(tag_name, "HSK", parent_tag.id)
        parent_tag.add_child(tag)

        texts = texts_from_file(file)
        puts "\nProcessing file #{file_index + 1} of #{file_count} with #{texts.count} entries"

        skipped = TagImportHelper.batch_associate_entries_to_tag(texts, tag)
        total_skipped += skipped

        if skipped > 0
          logfile.puts "#{skipped} entries from #{File.basename(file)} had no matching DictionaryEntry"
        end
      end
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    puts "\nCompleted in #{elapsed.round(2)}s (#{total_skipped} #{total_skipped == 1 ? "entry" : "entries"} skipped — not in dictionary)"
end

def texts_from_file(file)
  if File.extname(file) == ".txt"
    File.readlines(file, chomp: true)
        .map { |line| line.sub(/\A\uFEFF/, "").strip }
        .reject(&:empty?)
  else
    JSON.parse(File.read(file)).map { |entry| entry["s"] }
  end
end

def tag_name_from_file(file)
  if File.extname(file) == ".txt"
    File.basename(file, ".txt")
  else
    "HSK #{File.basename(file).split(".").first}"
  end
end
