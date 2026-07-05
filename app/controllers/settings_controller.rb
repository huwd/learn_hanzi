class SettingsController < ApplicationController
  def show
    @user   = Current.user
    @advice = LearningAdvisor.classify(user: Current.user)
  end

  def update
    @user = Current.user
    if @user.update(settings_params)
      redirect_to settings_path, notice: "Settings saved."
    else
      @advice = LearningAdvisor.classify(user: Current.user)
      render :show, status: :unprocessable_content
    end
  end

  private

  def settings_params
    params.require(:user).permit(:session_size, :new_cards_per_session, :telemetry_enabled, :mcp_service_token_id)
  end
end
