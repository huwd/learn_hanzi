namespace :makemeahanzi do
  desc "Download makemeahanzi dictionary and graphics data"
  task download: :environment do
    result = Admin::MakemeahanziSourceProvisioningService.call
    puts "Downloaded dictionary to #{result[:dictionary_path]} (#{result[:dictionary_bytes]} bytes)"
    puts "Downloaded graphics to #{result[:graphics_path]} (#{result[:graphics_bytes]} bytes)"
  end
end
