require "capybara/rspec"
require "json"

# Selenium Manager's default resolution prefers a chromedriver already on
# PATH over downloading one that matches the installed Chrome version. Dev
# machines can have a stale one there (e.g. from an old nvm-installed npm
# package), so ask Selenium Manager to ignore PATH and fetch/cache a driver
# that actually matches the local Chrome build.
def system_matched_chromedriver_path
  selenium_manager = Dir.glob(
    File.join(Gem.loaded_specs["selenium-webdriver"].full_gem_path, "bin/*/selenium-manager")
  ).first
  Selenium::WebDriver::Platform.assert_executable(selenium_manager)

  output = `#{selenium_manager} --browser chrome --skip-driver-in-path --output json`
  JSON.parse(output).dig("result", "driver_path")
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

RSpec.configure do |config|
  config.before(:each, type: :system) do
    WebMock.disable_net_connect!(allow_localhost: true)
    driven_by :selenium_chrome_headless
  end
end
