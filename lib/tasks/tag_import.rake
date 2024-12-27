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
    parent_tag = find_or_create_tag("HSK 2.0", "HSK")
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

    File.open(logfile_path, "a") do |logfile|
    hsk_level_files.each.with_index do |file, file_index|
      tag_name = "HSK #{file.split("/").last.split(".").first}"
      tag = find_or_create_tag(tag_name, "HSK")
      parent_tag.add_child(tag)

      file_content = JSON.parse(File.read(file))
      entry_count = file_content.count
      error_count = 0
      puts "\nProcessing file #{file_index + 1} of #{file_count} with #{entry_count} entries\n"

      file_content.each.with_index do |entry, entry_index|
        progress = ((entry_index + 1).to_f / entry_count.to_f * 100).round(2)
        print "\rProcessing: #{progress}% | Errors: #{error_count}"
        begin
          associate_dictionary_entry_to_tag(entry["s"], tag)
        rescue => e
          error_count += 1
          logfile.puts "Error processing tag #{entry_index + 1} for #{tag.name}: #{entry["s"]}"
          logfile.puts "Error: #{e.message}"
          next
        end
      end
    end
  end
end
