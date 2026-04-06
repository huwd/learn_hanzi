class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access

  def create
    auth = request.env["omniauth.auth"]
    return redirect_to auth_failure_path if auth.blank?

    user = User.find_or_create_by_omniauth(auth)
    start_new_session_for(user)
    redirect_to after_authentication_url
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    Rails.logger.warn("OmniAuth callback error: #{e.class}: #{e.message}")
    redirect_to auth_failure_path
  end

  def failure
    render :failure, status: :unauthorized
  end
end
