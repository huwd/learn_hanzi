module CfAccessHelpers
  ISSUER  = "https://susurrant.cloudflareaccess.com"
  AUD     = "test-aud-tag"
  JWKS_URI = "#{ISSUER}/cdn-cgi/access/certs"

  def self.private_key
    @private_key ||= OpenSSL::PKey::RSA.generate(2048)
  end

  def self.jwk
    @jwk ||= JWT::JWK.new(private_key, { kid: "test-kid-1", use: "sig" })
  end

  def self.jwks_hash
    { keys: [ jwk.export ] }
  end

  def stub_cf_jwks
    stub_request(:get, CfAccessHelpers::JWKS_URI)
      .to_return(
        body: CfAccessHelpers.jwks_hash.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def cf_access_token(email:, aud: CfAccessHelpers::AUD, iss: CfAccessHelpers::ISSUER, exp: 1.hour.from_now.to_i, omit_email: false)
    payload = { iss: iss, sub: email, aud: [ aud ], exp: exp, iat: Time.current.to_i }
    payload[:email] = email unless omit_email
    JWT.encode(payload, CfAccessHelpers.private_key, "RS256", { kid: "test-kid-1" })
  end

  def bearer(token)
    { "CF-Access-Jwt-Assertion" => token }
  end
end
