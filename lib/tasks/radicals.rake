namespace :radicals do
  desc "Import radical decomposition from makemeahanzi dictionary.txt"
  task :import, [ :dictionary_path, :graphics_path ] => :environment do |_task, args|
    dictionary_path = args[:dictionary_path] || Rails.root.join("tmp", "makemeahanzi", "dictionary.txt").to_s
    graphics_path = args[:graphics_path] || Rails.root.join("tmp", "makemeahanzi", "graphics.txt").to_s

    unless File.exist?(dictionary_path)
      raise "Dictionary file not found at #{dictionary_path}"
    end

    unless File.exist?(graphics_path)
      raise "Graphics file not found at #{graphics_path}. Run `bin/rails makemeahanzi:download` to download the required source files."
    end

    puts "Importing radicals from #{dictionary_path}..."
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = Admin::RadicalsProvisioningService.call(
      dictionary_path: dictionary_path,
      graphics_path: graphics_path
    )

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    puts "Done! Completed in #{elapsed.round(2)}s"
    puts "Entries processed: #{result[:entries_processed]}"
    puts "Radicals created: #{result[:radicals_created]}"
    puts "Associations created: #{result[:associations_created]}"
  end
end
