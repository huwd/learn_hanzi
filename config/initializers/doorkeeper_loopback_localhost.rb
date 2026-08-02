# frozen_string_literal: true

# Doorkeeper's RFC 8252 §7.3 support — ignore the port when matching a
# redirect_uri against a loopback address, so native clients that pick a
# random local port each run still match whatever they registered — only
# recognizes numeric loopback IPs (127.0.0.1, ::1) via IPAddr#loopback?.
# The literal hostname "localhost" makes IPAddr.new raise, so it's treated
# as an ordinary non-loopback host and the port is never ignored. This is
# unfixed as of the gem's current master (checked 2026-08-02,
# lib/doorkeeper/oauth/helpers/uri_checker.rb) and no open issue covers it.
#
# CIMD-resolved native clients (e.g. Claude Code — see
# Oauth::CimdClientResolver) commonly register and request
# "http://localhost:<ephemeral-port>/callback", so without this override
# every authorization attempt fails redirect_uri matching as soon as the
# client's port differs from whatever got registered.
module DoorkeeperLocalhostLoopback
  def loopback_uri?(uri)
    uri.host == "localhost" || super
  end
end

Doorkeeper::OAuth::Helpers::URIChecker.singleton_class.prepend(DoorkeeperLocalhostLoopback)
