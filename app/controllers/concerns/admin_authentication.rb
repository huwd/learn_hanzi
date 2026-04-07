module AdminAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  private

  def require_admin
    redirect_to root_path, alert: "Not authorised." unless Current.user&.admin?
  end
end
