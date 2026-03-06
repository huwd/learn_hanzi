require "open-uri"
require "zip"

module ImportFilesHelper
  def download_file_to_tmp(url, destination)
    FileUtils.mkdir_p(File.dirname(destination))
    File.open(destination, "wb") do |file|
      file.write(URI.open(url).read)
    end
  end

  def unzip_file(temp_zip_path, unzip_dir)
    FileUtils.mkdir_p(unzip_dir)
    puts "Unzipping files to #{unzip_dir}..."

    Zip::File.open(temp_zip_path) do |zip_file|
      zip_file.each do |entry|
        puts "Extracting #{entry.name} to #{unzip_dir}..."
        entry.extract(destination_directory: unzip_dir) { true }
      end
    end
  end

  def confirm_file_presence(file_name_search_string, unzip_dir)
    puts "Looking for files matching #{file_name_search_string} in #{unzip_dir}..."
    matched_files = Dir[unzip_dir.join(file_name_search_string)]
    puts "Found files: #{matched_files.join(', ')}"

    raise "Something is wrong: file not found in tmp!" if matched_files.empty?
  end
end
