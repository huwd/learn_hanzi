require "rails_helper"

RSpec.describe "DataImports", type: :request do
  let(:user) { create(:user) }

  describe "GET /data_imports/new" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        get new_data_import_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns 200" do
        get new_data_import_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /data_imports" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        post data_imports_path
        expect(response).to redirect_to("/sign_in")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      context "when no file is provided" do
        it "redirects back with an alert" do
          post data_imports_path
          expect(response).to redirect_to(new_data_import_path)
          expect(flash[:alert]).to include("select a file")
        end
      end

      context "when an invalid JSON file is uploaded" do
        it "redirects back with an alert" do
          file = fixture_file_upload(
            Rails.root.join("spec/fixtures/files/bad.json"),
            "application/json"
          )
          post data_imports_path, params: { file: file }
          expect(response).to redirect_to(new_data_import_path)
          expect(flash[:alert]).to include("Invalid")
        end
      end

      context "when a valid export file is uploaded" do
        let(:entry_ni) { create(:dictionary_entry, text: "你") }
        let(:export_json) do
          {
            version: 1,
            exported_at: "2026-04-07T12:00:00Z",
            user_learnings: [
              {
                character: "你",
                state: "mastered",
                next_due: "2026-04-10T00:00:00Z",
                last_interval: 30,
                factor: 2500,
                created_at: "2026-01-01T00:00:00Z",
                updated_at: "2026-04-01T00:00:00Z",
                review_logs: []
              }
            ]
          }.to_json
        end
        let(:export_tempfile) do
          Tempfile.new([ "export", ".json" ]).tap { |f| f.write(export_json); f.rewind }
        end
        let(:export_file) { fixture_file_upload(export_tempfile.path, "application/json") }

        before { entry_ni }
        after  { export_tempfile.close! }

        it "redirects to the new import page with a success notice" do
          post data_imports_path, params: { file: export_file }
          expect(response).to redirect_to(new_data_import_path)
          expect(flash[:notice]).to include("Import complete")
        end

        it "creates the user_learning record" do
          expect {
            post data_imports_path, params: { file: export_file }
          }.to change { user.user_learnings.count }.by(1)
        end
      end

      context "when the file has an unsupported version" do
        let(:bad_version_json) do
          { version: 99, exported_at: "2026-04-07T12:00:00Z", user_learnings: [] }.to_json
        end
        let(:bad_version_tempfile) do
          Tempfile.new([ "bad_version", ".json" ]).tap { |f| f.write(bad_version_json); f.rewind }
        end
        let(:bad_version_file) { fixture_file_upload(bad_version_tempfile.path, "application/json") }

        after { bad_version_tempfile.close! }

        it "redirects back with an alert" do
          post data_imports_path, params: { file: bad_version_file }
          expect(response).to redirect_to(new_data_import_path)
          expect(flash[:alert]).to include("Unsupported")
        end
      end
    end
  end
end
