namespace :stroke_order do
  desc "Import stroke order data from makemeahanzi graphics.txt"
  task :import, [ :graphics_path ] => :environment do |_task, args|
    graphics_path = args[:graphics_path] || Admin::MakemeahanziSourceProvisioningService.graphics_path.to_s

    result = Admin::StrokeOrderProvisioningService.call(graphics_path: graphics_path)

    puts "Entries processed: #{result[:entries_processed]}"
    puts "Unmatched entries: #{result[:unmatched_entries]}"
    puts "Malformed rows skipped: #{result[:malformed_rows_skipped]}"
  end
end
