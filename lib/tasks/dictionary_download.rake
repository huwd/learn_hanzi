namespace :dictionary_download do
  CEDICT_URL = "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.zip"

  desc "Download and unzip the CC-CEDICT dictionary"
  task cc_cedict: :environment do
    require "open-uri"
    require "zip"

    temp_zip_path = Rails.root.join("tmp", "cedict.zip")
    unzip_dir = Rails.root.join("tmp", "cedict")

    download_file_to_tmp(CEDICT_URL, temp_zip_path)
    unzip_file(temp_zip_path, unzip_dir)
    confirm_file_presence("*cedict*", unzip_dir)
  end
end

def download_file_to_tmp(url, destination)
  File.open(destination, "wb") do |file|
    file.write(URI.open(url).read)
  end
end

def unzip_file(temp_zip_path, unzip_dir)
  FileUtils.mkdir_p(unzip_dir)
  puts "Unzipping files to #{unzip_dir}..."

  Zip::File.open(temp_zip_path) do |zip_file|
    zip_file.each do |entry|
      destination_path = File.join(unzip_dir, entry.name)
      puts "Extracting #{entry.name} to #{destination_path}..."
      entry.extract(destination_path) { true }
    end
  end
end

def confirm_file_presence(file_name_search_string, unzip_dir)
  puts "Looking for files matching #{file_name_search_string} in #{unzip_dir}..."
  matched_files = Dir[unzip_dir.join(file_name_search_string)]
  puts "Found files: #{matched_files.join(', ')}"

  raise "Something is wrong: file not found in tmp!" if matched_files.empty?
end
