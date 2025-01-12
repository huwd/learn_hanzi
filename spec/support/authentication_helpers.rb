module AuthenticationHelpers
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: user.password }
  end
end
