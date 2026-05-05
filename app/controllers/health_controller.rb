class HealthController < ActionController::Base
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")
    render plain: "OK"
  rescue ActiveRecord::ActiveRecordError
    render plain: "Service Unavailable", status: :service_unavailable
  end
end
