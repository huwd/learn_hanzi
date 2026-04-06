module AuthenticationHelpers
  def sign_in(user)
    provider = OIDC_PROVIDER_NAME.to_sym
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(
      provider: user.provider,
      uid: user.uid,
      info: { email: user.email_address }
    )
    get "/auth/#{OIDC_PROVIDER_NAME}"
    follow_redirect!
    OmniAuth.config.mock_auth.delete(provider)
  end
end
