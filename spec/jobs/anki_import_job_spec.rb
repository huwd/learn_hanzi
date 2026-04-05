require 'rails_helper'

RSpec.describe AnkiImportJob, type: :job do
  let(:user)   { create(:user) }
  let(:import) { create(:anki_import, user: user, state: "pending") }
  let(:file_path) { Rails.root.join("tmp/test_anki_upload.anki21").to_s }

  before do
    FileUtils.touch(file_path)
  end

  after do
    FileUtils.rm_f(file_path)
  end

  describe "#perform" do
    context "when the import succeeds" do
      before do
        allow(AnkiImportService).to receive(:call).with(user: user, file_path: file_path).and_return(
          { cards_imported: 8, review_logs_imported: 42, skipped: [] }
        )
      end

      it "transitions state to running then complete" do
        described_class.perform_now(import.id, file_path)
        import.reload
        expect(import.state).to eq("complete")
      end

      it "records cards_imported count" do
        described_class.perform_now(import.id, file_path)
        expect(import.reload.cards_imported).to eq(8)
      end

      it "records review_logs_imported count" do
        described_class.perform_now(import.id, file_path)
        expect(import.reload.review_logs_imported).to eq(42)
      end

      it "sets completed_at" do
        described_class.perform_now(import.id, file_path)
        expect(import.reload.completed_at).to be_present
      end

      it "deletes the uploaded file" do
        described_class.perform_now(import.id, file_path)
        expect(File.exist?(file_path)).to be false
      end
    end

    context "when the import raises an error" do
      before do
        allow(AnkiImportService).to receive(:call).and_raise(StandardError, "connection failed")
      end

      it "transitions state to failed" do
        expect { described_class.perform_now(import.id, file_path) }.to raise_error(StandardError)
        expect(import.reload.state).to eq("failed")
      end

      it "stores a generic user-safe error message" do
        expect { described_class.perform_now(import.id, file_path) }.to raise_error(StandardError)
        expect(import.reload.error_message).to eq(
          "Import failed. Please verify the file is a valid Anki collection and try again."
        )
      end

      it "logs the full exception details" do
        allow(Rails.logger).to receive(:error)
        expect { described_class.perform_now(import.id, file_path) }.to raise_error(StandardError)
        expect(Rails.logger).to have_received(:error).with(/connection failed/)
      end

      it "still deletes the uploaded file on failure" do
        expect { described_class.perform_now(import.id, file_path) }.to raise_error(StandardError)
        expect(File.exist?(file_path)).to be false
      end
    end
  end
end
