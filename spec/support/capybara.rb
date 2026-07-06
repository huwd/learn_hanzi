require "capybara/rspec"
require "json"
require "open3"

# Selenium Manager's default resolution prefers a chromedriver already on
# PATH over downloading one that matches the installed Chrome version. Dev
# machines can have a stale one there (e.g. from an old nvm-installed npm
# package), so ask Selenium Manager to ignore PATH and fetch/cache a driver
# that actually matches the local Chrome build.
def system_matched_chromedriver_path
  @system_matched_chromedriver_path ||= begin
    selenium_manager = Dir.glob(
      File.join(Gem.loaded_specs["selenium-webdriver"].full_gem_path, "bin/*/selenium-manager")
    ).first
    Selenium::WebDriver::Platform.assert_executable(selenium_manager)

    stdout, stderr, status = Open3.capture3(
      selenium_manager, "--browser", "chrome", "--skip-driver-in-path", "--output", "json"
    )
    raise "Selenium Manager failed to resolve a chromedriver: #{stderr}" unless status.success?

    driver_path = JSON.parse(stdout).dig("result", "driver_path")
    raise "Selenium Manager did not return a chromedriver path: #{stdout}" if driver_path.blank?

    driver_path
  end
end

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--disable-gpu")
  options.add_argument("--no-sandbox")
  options.add_argument("--window-size=1400,1400")

  service = Selenium::WebDriver::Service.chrome(path: system_matched_chromedriver_path)

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
end

# Fixed rather than random so the real-OIDC spec tier's client redirect_uri
# (registered with the stub OIDC server ahead of time) is deterministic.
# See spec/support/real_oidc_helpers.rb and docs/testing/real_oidc_stub.md.
Capybara.server_host = "localhost"
Capybara.server_port = 31337

RSpec.configure do |config|
  config.before(:each, type: :system) do
    WebMock.disable_net_connect!(allow_localhost: true)
    driven_by :selenium_chrome_headless
  end
end
