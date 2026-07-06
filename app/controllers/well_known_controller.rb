# OAuth discovery metadata for MCP clients (RFC 9728 / RFC 8414), advertising
# this app as its own MCP clients' authorization server. No registration_endpoint
# is advertised — clients self-identify via CIMD instead (see
# Oauth::CimdClientResolver), which its absence signals per spec.
class WellKnownController < ActionController::API
  def oauth_protected_resource
    render json: {
      resource: mcp_url,
      authorization_servers: [ root_url.chomp("/") ],
      bearer_methods_supported: [ "header" ],
      scopes_supported: [ "mcp" ]
    }
  end

  def oauth_authorization_server
    render json: {
      issuer: root_url.chomp("/"),
      authorization_endpoint: oauth_authorization_url,
      token_endpoint: oauth_token_url,
      revocation_endpoint: oauth_revoke_url,
      response_types_supported: [ "code" ],
      grant_types_supported: [ "authorization_code", "refresh_token" ],
      code_challenge_methods_supported: [ "S256" ],
      token_endpoint_auth_methods_supported: [ "none" ],
      client_id_metadata_document_supported: true,
      scopes_supported: [ "mcp" ]
    }
  end
end
