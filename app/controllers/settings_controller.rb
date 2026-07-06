class SettingsController < ApplicationController
  def show
    @user   = Current.user
    @advice = LearningAdvisor.classify(user: Current.user)
    @connected_apps = connected_apps
  end

  def update
    @user = Current.user
    if @user.update(settings_params)
      redirect_to settings_path, notice: "Settings saved."
    else
      @advice = LearningAdvisor.classify(user: Current.user)
      @connected_apps = connected_apps
      render :show, status: :unprocessable_content
    end
  end

  def revoke_connected_app
    Doorkeeper::AccessToken.revoke_all_for(params[:id], Current.user)
    redirect_to settings_path, notice: "Access revoked."
  end

  private

  def settings_params
    params.require(:user).permit(:session_size, :new_cards_per_session, :telemetry_enabled, :mcp_service_token_id)
  end

  def connected_apps
    Doorkeeper::AccessToken
      .by_resource_owner(Current.user)
      .where(revoked_at: nil)
      .includes(:application)
      .group_by(&:application)
  end
end
