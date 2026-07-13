# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
require 'webmock/rspec'

# Add additional requires below this line. Rails is not loaded until this point!
require_relative 'support/authentication_helpers'
require_relative 'support/anki_helper'
require_relative 'support/query_counter'
require_relative 'support/capybara'
require_relative 'support/doorkeeper_helpers'
require_relative 'support/real_oidc_helpers'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
  config.include DoorkeeperHelpers, type: :request
  config.include RealOidcHelpers, type: :system
  config.include QueryCounter

  # Exercises the real omniauth_openid_connect strategy against a stub OIDC
  # server (see docs/testing/real_oidc_stub.md) — opt-in since it needs that
  # stub running locally/in CI, unlike every other spec here.
  config.filter_run_excluding real_oidc: true unless ENV["REAL_OIDC"] == "1"

  # The openid_connect gem's discovery step always builds an https:// URL
  # (OpenIDConnect::Discovery::Provider::Config::Resource#endpoint discards
  # the issuer's actual scheme entirely) — a real production safeguard we
  # want everywhere else, scoped here to real_oidc specs only since the stub
  # is plain HTTP. The companion relaxation this tier used to need for the
  # stub's discovery-issuer mismatch (see docs/testing/real_oidc_stub.md) is
  # gone now that the upstream fix has shipped (imposter-project/imposter-go
  # v5.19.2), so validate_discovery_issuer stays at its real default.
  config.before(:each, real_oidc: true) do
    require "swd"
    @original_swd_url_builder = SWD.url_builder
    SWD.url_builder = URI::HTTP

    # Every other system spec authenticates in-process via OmniAuth test_mode,
    # so Capybara's 2-second default is plenty. This tier's sign-in redirects
    # through a second, real HTTP server (the Imposter stub) rendering its
    # own login page — an extra process hop with no shared warmth, more prone
    # to occasionally outrunning that default under CI's less predictable
    # scheduling than a same-process mock ever would be.
    @original_capybara_wait_time = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 5
  end

  config.after(:each, real_oidc: true) do
    SWD.url_builder = @original_swd_url_builder
    Capybara.default_max_wait_time = @original_capybara_wait_time
  end

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :active_record
      with.library :active_model
      with.library :action_controller # Add this if you want to test controllers
    end
  end

  config.before(:suite) do
    AnkiHelper.recreate_test_db!
  end

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/7-0/rspec-rails
  #
  # You can also this infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  # config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
