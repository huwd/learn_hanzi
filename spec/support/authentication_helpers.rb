module AuthenticationHelpers
  def sign_in(user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(
      provider: user.provider,
      uid: user.uid,
      info: { email: user.email_address }
    )
    post "/auth/oidc"
    follow_redirect!
  ensure
    OmniAuth.config.mock_auth.delete(:oidc)
    OmniAuth.config.test_mode = false
  end
end
