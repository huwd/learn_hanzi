module AuthenticationHelpers
  def sign_in(user)
    OmniAuth.config.test_mode = true
    Rails.application.env_config["omniauth.auth"] = OmniAuth::AuthHash.new(
      provider: user.provider,
      uid: user.uid,
      info: { email: user.email_address }
    )
    get "/auth/pocket_id/callback"
    Rails.application.env_config.delete("omniauth.auth")
  end
end
