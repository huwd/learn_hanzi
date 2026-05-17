require "net/http"
require "uri"

# Push deploy metrics to the Pushgateway when the web container boots in production.
# Only fires on the web container (CONTAINER_ROLE=web) to avoid double-counting
# when the jobs container also starts. PUSHGATEWAY_URL is provisioned to the
# Portainer stack via rake provision:learn_hanzi and points to the observability
# stack's pushgateway over monitoring_net.
if Rails.env.production? &&
    ENV["CONTAINER_ROLE"] == "web" &&
    ENV["PUSHGATEWAY_URL"].present?

  deploy_time   = Time.now.to_i
  commit_time   = ENV.fetch("COMMIT_TIMESTAMP", deploy_time.to_s)
  sha           = ENV.fetch("DEPLOY_SHA", "unknown")[0, 7]

  payload = <<~METRICS
    # HELP learn_hanzi_deploy_total Number of successful deploys to production.
    # TYPE learn_hanzi_deploy_total counter
    learn_hanzi_deploy_total{sha="#{sha}",branch="main",outcome="success"} 1
    # HELP learn_hanzi_deploy_timestamp_seconds Unix timestamp of this deploy.
    # TYPE learn_hanzi_deploy_timestamp_seconds gauge
    learn_hanzi_deploy_timestamp_seconds{sha="#{sha}",branch="main"} #{deploy_time}
    # HELP learn_hanzi_commit_timestamp_seconds Unix timestamp of the deployed commit.
    # TYPE learn_hanzi_commit_timestamp_seconds gauge
    learn_hanzi_commit_timestamp_seconds{sha="#{sha}",branch="main"} #{commit_time}
  METRICS

  Thread.new do
    uri = URI("#{ENV['PUSHGATEWAY_URL']}/metrics/job/learn_hanzi/instance/production")
    Net::HTTP.post(uri, payload, "Content-Type" => "text/plain")
  rescue => e
    Rails.logger.warn("[deploy_metric] Pushgateway push failed: #{e.message}")
  end
end
