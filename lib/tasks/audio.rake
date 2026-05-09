namespace :audio do
  desc "Download and extract pronunciation audio archive"
  task download: :environment do
    result = Admin::AudioPronunciationsProvisioningService.download
    puts "Audio archive ready at #{result[:archive_path]}"
    puts "Extracted audio directory: #{result[:audio_dir]}"
    puts "#{result[:downloaded_files]} audio files available"
  end

  desc "Import pronunciation audio for HSK 1-4 entries"
  task import: :environment do
    result = Admin::AudioPronunciationsProvisioningService.import
    puts "Imported: #{result[:imported]}"
    puts "Updated: #{result[:updated]}"
    puts "Unchanged: #{result[:unchanged]}"
    puts "Unmatched: #{result[:unmatched]}"
    puts "Logged unmatched entries to log/audio_import_errors.log"
  end
end
