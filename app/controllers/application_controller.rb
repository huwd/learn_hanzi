class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_sentry_user

  private

  def set_sentry_user
    return unless Current.user&.telemetry_enabled?

    Sentry.set_user(id: Current.user.id, email: Current.user.email_address)
  end
end
