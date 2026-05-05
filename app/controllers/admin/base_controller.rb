module Admin
  class BaseController < ApplicationController
    include AdminAuthentication

    private

    # Mission Control mounts as a Rails engine, so engine-scoped route helpers
    # cannot resolve main-app named routes (sign_in_path picks up server_id
    # defaults and raises UrlGenerationError). Use a literal path instead.
    def request_authentication
      session[:return_to_after_authenticating] = request.url if request.get? || request.head?
      redirect_to "/sign_in"
    end
  end
end
