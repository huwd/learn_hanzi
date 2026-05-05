require "rails_helper"

RSpec.describe "Health check", type: :request do
  describe "GET /up" do
    it "returns 200 when the database is reachable" do
      get rails_health_check_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 503 when the database is unreachable" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::StatementInvalid)
      get rails_health_check_path
      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
