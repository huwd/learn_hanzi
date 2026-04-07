require "rails_helper"

RSpec.describe "DataExports", type: :request do
  let(:user) { create(:user) }

  describe "GET /data_export" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        get data_export_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns 200" do
        get data_export_path
        expect(response).to have_http_status(:ok)
      end

      it "returns JSON content type" do
        get data_export_path
        expect(response.content_type).to include("application/json")
      end

      it "sends the file as an attachment" do
        get data_export_path
        expect(response.headers["Content-Disposition"]).to include("attachment")
      end

      it "names the file with today's date" do
        get data_export_path
        expect(response.headers["Content-Disposition"])
          .to include("learn_hanzi_export_#{Date.today.iso8601}.json")
      end

      it "returns valid JSON with the correct version" do
        get data_export_path
        data = JSON.parse(response.body)
        expect(data["version"]).to eq(1)
      end

      it "includes the exported_at timestamp" do
        get data_export_path
        data = JSON.parse(response.body)
        expect(data["exported_at"]).to be_present
      end

      it "includes user_learnings array" do
        get data_export_path
        data = JSON.parse(response.body)
        expect(data["user_learnings"]).to be_an(Array)
      end
    end
  end
end
