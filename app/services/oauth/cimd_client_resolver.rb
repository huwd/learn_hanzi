module Oauth
  # Resolves an OAuth Client ID Metadata Document (CIMD) — client_id is an
  # https:// URL pointing at a JSON document describing the client, fetched
  # and validated on demand rather than a stateful registration call. This is
  # the MCP authorization spec's recommended self-registration mechanism
  # (SHOULD, as of the November 2025 revision), chosen over classic RFC 7591
  # Dynamic Client Registration specifically because there's no public,
  # unauthenticated "create a row" endpoint to spam — the tradeoff is that
  # this resolver performs a server-side fetch of an attacker-reachable URL,
  # so the SSRF hardening below is the security-critical part of this class.
  class CimdClientResolver
    class InvalidMetadata < StandardError; end
    class FetchError < StandardError; end

    CACHE_TTL = 1.hour
    MAX_BODY_BYTES = 10.kilobytes
    OPEN_TIMEOUT = 3
    READ_TIMEOUT = 3

    def initialize(client_id_url)
      @client_id_url = client_id_url
    end

    def resolve!
      validate_url_shape!
      # A failed fetch/validation raises out of this block, so nothing is
      # ever cached for a bad client_id — only a successfully validated
      # document is memoized.
      metadata = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_and_validate_metadata }
      upsert_application(metadata)
    end

    private

    attr_reader :client_id_url

    def cache_key
      "cimd_client_metadata:#{client_id_url}"
    end

    def validate_url_shape!
      uri = URI.parse(client_id_url)
      raise InvalidMetadata, "client_id must be an https:// URL" unless uri.is_a?(URI::HTTPS)
      raise InvalidMetadata, "client_id must have a path" if uri.path.blank?
      raise InvalidMetadata, "client_id must not include a fragment" if uri.fragment.present?
      raise InvalidMetadata, "client_id must not include userinfo" if uri.userinfo.present?
      # uri.port is normalized to 443 whether or not it was written explicitly,
      # so check the literal string — an explicit `:443` is a second, spurious
      # representation of the same origin the spec asks us to reject.
      if client_id_url.match?(%r{\Ahttps://[^/]*:443(/|\z)})
        raise InvalidMetadata, "client_id must not specify the default port explicitly"
      end
    rescue URI::InvalidURIError
      raise InvalidMetadata, "client_id is not a valid URL"
    end

    def fetch_and_validate_metadata
      metadata = JSON.parse(fetch_body)
      raise InvalidMetadata, "metadata document must be a JSON object" unless metadata.is_a?(Hash)

      unless metadata["client_id"] == client_id_url
        raise InvalidMetadata, "metadata client_id does not match the fetched URL"
      end

      redirect_uris = metadata["redirect_uris"]
      unless redirect_uris.is_a?(Array) && redirect_uris.any?
        raise InvalidMetadata, "redirect_uris is required"
      end

      auth_method = metadata["token_endpoint_auth_method"]
      unless auth_method.nil? || auth_method == "none"
        raise InvalidMetadata, "CIMD clients must be public (token_endpoint_auth_method must be absent or 'none')"
      end

      if metadata.key?("client_secret")
        raise InvalidMetadata, "client_secret is not permitted in a CIMD document"
      end

      metadata
    rescue JSON::ParserError
      raise InvalidMetadata, "metadata document is not valid JSON"
    end

    def fetch_body
      body = +""

      response = SsrfFilter.get(
        client_id_url,
        max_redirects: 0, # fail closed rather than follow a client_id to somewhere else
        http_options: { open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT }
      ) do |res|
        res.read_body do |chunk|
          body << chunk
          raise FetchError, "metadata document exceeded #{MAX_BODY_BYTES} bytes" if body.bytesize > MAX_BODY_BYTES
        end
      end

      raise FetchError, "metadata fetch failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      body
    rescue FetchError
      raise
    rescue SsrfFilter::Error => e
      raise FetchError, "metadata fetch blocked: #{e.message}"
    rescue StandardError => e
      raise FetchError, "metadata fetch failed: #{e.class}: #{e.message}"
    end

    def upsert_application(metadata)
      application = Doorkeeper::Application.find_or_initialize_by(metadata_url: client_id_url)
      application.assign_attributes(
        uid: client_id_url,
        name: metadata["client_name"].presence || "Unnamed MCP client",
        redirect_uri: Array(metadata["redirect_uris"]).join("\n"),
        confidential: false,
        scopes: "mcp",
        metadata_fetched_at: Time.current
      )
      application.save!
      application
    rescue ActiveRecord::RecordInvalid => e
      raise InvalidMetadata, e.message
    end
  end
end
