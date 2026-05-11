class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_sentry_user

  def append_info_to_payload(payload)
    super

    performance_timings.each do |name, duration_ms|
      payload[:"perf_#{name}_ms"] = duration_ms.round(1)
    end
  end

  private

   def measure_performance(name)
     started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
     result = yield
     elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0
     performance_timings[name] = elapsed_ms
     result
   end

   def measure_action_performance
     measure_performance("#{controller_name}_#{action_name}_total") { yield }
   end

   def performance_timings
     request.env["learn_hanzi.performance_timings"] ||= {}
   end

  def set_sentry_user
    return unless Current.user&.telemetry_enabled?

    Sentry.set_user(id: Current.user.id, email: Current.user.email_address)
  end
end
