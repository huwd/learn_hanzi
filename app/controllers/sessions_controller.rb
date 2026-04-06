class SessionsController < ApplicationController
  allow_unauthenticated_access only: :new

  def new
  end

  def destroy
    terminate_session
    redirect_to root_path
  end
end
