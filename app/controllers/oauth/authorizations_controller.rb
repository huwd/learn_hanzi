module Oauth
  # Resolves CIMD clients (client_id as an https:// metadata URL) before
  # Doorkeeper's own pre_auth/client lookup runs. If resolution fails, no
  # Doorkeeper::Application row exists for that client_id, so Doorkeeper's
  # normal pre_auth.authorizable? check fails on its own and renders its
  # standard invalid_client error — no separate error path needed here.
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    # Reuses the app's shared layout (Tailwind, nav, dark mode) rather than
    # Doorkeeper's own bare layout. This controller doesn't inherit from
    # ApplicationController (Doorkeeper's own hierarchy doesn't either, by
    # design — TokensController etc. must stay session-agnostic for
    # machine-to-machine calls), so the layout's `authenticated?` check needs
    # a matching helper method defined here instead.
    layout "application"
    helper_method :authenticated?

    # Deliberately a plain before_action (runs after the inherited
    # authenticate_resource_owner!), not prepend_before_action — an
    # unauthenticated visitor is redirected to sign in before this ever
    # triggers an outbound fetch, not after.
    before_action :resolve_cimd_client!

    private

    def authenticated?
      Current.user.present?
    end

    def resolve_cimd_client!
      client_id = params[:client_id].to_s
      return unless client_id.start_with?("https://")

      Oauth::CimdClientResolver.new(client_id).resolve!
    rescue Oauth::CimdClientResolver::InvalidMetadata, Oauth::CimdClientResolver::FetchError => e
      Rails.logger.warn("CIMD resolution failed for #{client_id.truncate(200).inspect}: #{e.message}")
    end
  end
end
