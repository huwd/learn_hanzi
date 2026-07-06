module DoorkeeperHelpers
  def doorkeeper_access_token_for(user, scopes: "mcp", expires_in: 2.hours)
    application = Doorkeeper::Application.create!(
      name: "Test MCP Client",
      redirect_uri: "https://example.com/callback",
      confidential: false
    )
    Doorkeeper::AccessToken.create!(
      resource_owner_id: user.id,
      application: application,
      scopes: scopes,
      expires_in: expires_in
    )
  end

  def bearer_header(access_token)
    { "Authorization" => "Bearer #{access_token.plaintext_token}" }
  end
end
