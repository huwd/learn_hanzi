class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access

  def create
    auth = request.env["omniauth.auth"]
    return redirect_to failure_path if auth.blank?

    user = User.find_or_create_by_omniauth(auth)
    start_new_session_for(user)
    redirect_to after_authentication_url
  end

  def failure
    redirect_to root_path, alert: "Authentication failed. Please try again."
  end
end
