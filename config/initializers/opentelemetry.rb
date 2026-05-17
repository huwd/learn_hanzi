require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/rails"
require "opentelemetry/instrumentation/active_record"

# Only instrument when an OTel endpoint is explicitly configured.
# In test/development without the collector running, skip to avoid noise.
if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present?
  OpenTelemetry::SDK.configure do |c|
    c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "learn-hanzi")

    c.use "OpenTelemetry::Instrumentation::Rails"
    c.use "OpenTelemetry::Instrumentation::ActiveRecord"
  end
end
