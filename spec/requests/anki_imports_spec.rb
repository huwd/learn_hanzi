require "rails_helper"

RSpec.describe "AnkiImports", type: :request do
  let(:user) { create(:user) }

  describe "GET /anki_imports/new" do
    context "when unauthenticated" do
      it "redirects to login" do
        get new_anki_import_path
        expect(response).to redirect_to("/auth/#{OIDC_PROVIDER_NAME}")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns 200" do
        get new_anki_import_path
        expect(response).to have_http_status(:ok)
      end

      it "shows recent imports for this user" do
        create(:anki_import, user: user, state: "complete")
        get new_anki_import_path
        expect(response.body).to include("complete")
      end
    end
  end

  describe "POST /anki_imports" do
    context "when unauthenticated" do
      it "redirects to login" do
        post anki_imports_path
        expect(response).to redirect_to("/auth/#{OIDC_PROVIDER_NAME}")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      context "with no file" do
        it "redirects back with an alert" do
          post anki_imports_path, params: { file: nil }
          expect(response).to redirect_to(new_anki_import_path)
        end
      end

      context "with a file that exceeds the size limit" do
        it "redirects back with an alert" do
          stub_const("AnkiImportsController::MAX_FILE_SIZE", 1)
          anki_file = fixture_file_upload(AnkiHelper.test_db_path, "application/octet-stream")
          post anki_imports_path, params: { file: anki_file }
          expect(response).to redirect_to(new_anki_import_path)
        end
      end

      context "with an unsupported file type" do
        let(:bad_file_tempfile) do
          Tempfile.new([ "not_an_anki_file", ".txt" ]).tap { |t| t.write("hello"); t.rewind }
        end
        let(:bad_file) { fixture_file_upload(bad_file_tempfile.path, "text/plain") }

        after { bad_file_tempfile.close! }

        it "redirects back with an alert" do
          post anki_imports_path, params: { file: bad_file }
          expect(response).to redirect_to(new_anki_import_path)
        end
      end

      context "with a file that has the right content-type but wrong magic bytes" do
        let(:fake_anki_file_tempfile) do
          Tempfile.new([ "fake", ".anki21" ]).tap { |t| t.write("not a sqlite file"); t.rewind }
        end
        let(:fake_anki_file) { fixture_file_upload(fake_anki_file_tempfile.path, "application/octet-stream") }

        after { fake_anki_file_tempfile.close! }

        it "redirects back with an alert" do
          post anki_imports_path, params: { file: fake_anki_file }
          expect(response).to redirect_to(new_anki_import_path)
        end
      end

      context "when an import is already in progress" do
        let(:anki_file) do
          fixture_file_upload(AnkiHelper.test_db_path, "application/octet-stream")
        end

        it "redirects back with an alert for a pending import" do
          create(:anki_import, user: user, state: "pending")
          post anki_imports_path, params: { file: anki_file }
          expect(response).to redirect_to(new_anki_import_path)
        end

        it "redirects back with an alert for a running import" do
          create(:anki_import, user: user, state: "running")
          post anki_imports_path, params: { file: anki_file }
          expect(response).to redirect_to(new_anki_import_path)
        end
      end

      context "with a valid .anki21 file" do
        let(:anki_file) do
          fixture_file_upload(
            AnkiHelper.test_db_path,
            "application/octet-stream"
          )
        end

        before do
          allow(AnkiImportJob).to receive(:perform_later)
        end

        it "creates an AnkiImport record" do
          expect {
            post anki_imports_path, params: { file: anki_file }
          }.to change { AnkiImport.count }.by(1)
        end

        it "enqueues an AnkiImportJob" do
          post anki_imports_path, params: { file: anki_file }
          expect(AnkiImportJob).to have_received(:perform_later)
        end

        it "redirects to the import status page" do
          post anki_imports_path, params: { file: anki_file }
          expect(response).to redirect_to(anki_import_path(AnkiImport.last))
        end
      end
    end
  end

  describe "GET /anki_imports/:id" do
    context "when unauthenticated" do
      it "redirects to login" do
        import = create(:anki_import, user: create(:user))
        get anki_import_path(import)
        expect(response).to redirect_to("/auth/#{OIDC_PROVIDER_NAME}")
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "shows the import status" do
        import = create(:anki_import, user: user, state: "running")
        get anki_import_path(import)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Running")
      end
    end
  end
end
