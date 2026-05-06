require "rails_helper"

RSpec.describe "Sentry user context", type: :request do
  let(:user) { create(:user) }

  describe "authenticated requests" do
    context "when telemetry_enabled is true" do
      before { user.update!(telemetry_enabled: true) }

      it "sets Sentry user context on each request" do
        sign_in user
        expect(Sentry).to receive(:set_user).with(id: user.id, email: user.email_address)
        get settings_path
      end
    end

    context "when telemetry_enabled is false" do
      it "does not set Sentry user context" do
        sign_in user
        expect(Sentry).not_to receive(:set_user)
        get settings_path
      end
    end
  end
end
