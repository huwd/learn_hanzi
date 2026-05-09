require "rails_helper"

RSpec.describe Admin::ProvisioningJob, type: :job do
  let(:task) { create(:admin_task, task_type: task_type, state: "pending") }

  shared_examples "a provisioning job" do |service_class|
    context "when the service succeeds" do
      before do
        allow(service_class).to receive(:call).and_return(summary_result)
      end

      it "transitions the task to complete" do
        described_class.perform_now(task.id)
        expect(task.reload.state).to eq("complete")
      end

      it "sets started_at" do
        described_class.perform_now(task.id)
        expect(task.reload.started_at).to be_present
      end

      it "sets completed_at" do
        described_class.perform_now(task.id)
        expect(task.reload.completed_at).to be_present
      end

      it "persists the summary as JSON" do
        described_class.perform_now(task.id)
        expect(JSON.parse(task.reload.summary)).to be_a(Hash)
      end
    end

    context "when the service raises an error" do
      before do
        allow(service_class).to receive(:call).and_raise(StandardError, "network timeout")
      end

      it "transitions the task to failed" do
        expect { described_class.perform_now(task.id) }.to raise_error(StandardError)
        expect(task.reload.state).to eq("failed")
      end

      it "stores the error message on the task" do
        expect { described_class.perform_now(task.id) }.to raise_error(StandardError)
        expect(task.reload.error_message).to include("network timeout")
      end

      it "sets completed_at on failure" do
        expect { described_class.perform_now(task.id) }.to raise_error(StandardError)
        expect(task.reload.completed_at).to be_present
      end

      it "logs the full exception" do
        allow(Rails.logger).to receive(:error)
        expect { described_class.perform_now(task.id) }.to raise_error(StandardError)
        expect(Rails.logger).to have_received(:error).with(/network timeout/)
      end
    end
  end

  describe "#perform for cc_cedict" do
    let(:task_type)     { "cc_cedict" }
    let(:summary_result) { { entries_before: 0, entries_after: 120_000 } }

    include_examples "a provisioning job", Admin::CcCedictProvisioningService
  end

  describe "#perform for hsk_tags" do
    let(:task_type)     { "hsk_tags" }
    let(:summary_result) { { tags_created: 15, entries_tagged: 5000, skipped: 3 } }

    include_examples "a provisioning job", Admin::HskTagsProvisioningService
  end

  describe "#perform for custom_dictionary" do
    let(:task_type)     { "custom_dictionary" }
    let(:summary_result) { { created: 210, updated: 0 } }

    include_examples "a provisioning job", Admin::CustomDictionaryProvisioningService
  end

  describe "#perform for frequency_data" do
    let(:task_type)      { "frequency_data" }
    let(:summary_result) { { words_parsed: 120_000, entries_updated: 95_000, missing_from_dictionary: 25_000 } }

    include_examples "a provisioning job", Admin::FrequencyProvisioningService
  end

  describe "#perform for makemeahanzi_source" do
    let(:task_type)      { "makemeahanzi_source" }
    let(:summary_result) { { dictionary_bytes: 123, graphics_bytes: 456 } }

    include_examples "a provisioning job", Admin::MakemeahanziSourceProvisioningService
  end

  describe "#perform for unihan" do
    let(:task_type) { "unihan" }
    let(:summary_result) do
      {
        definitions_parsed: 2,
        meanings_before: 0,
        meanings_after: 2,
        meanings_created: 2,
        skipped_higher_priority: 0
      }
    end

    include_examples "a provisioning job", Admin::UnihanProvisioningService
  end

  describe "#perform for radicals" do
    let(:task_type) { "radicals" }
    let(:summary_result) do
      {
        entries_processed: 120_000,
        radicals_created: 380,
        associations_created: 240_000
      }
    end

    include_examples "a provisioning job", Admin::RadicalsProvisioningService
  end

  describe "#perform for stroke_order" do
    let(:task_type) { "stroke_order" }
    let(:summary_result) do
      {
        entries_processed: 10_000,
        unmatched_entries: 500,
        malformed_rows_skipped: 3
      }
    end

    include_examples "a provisioning job", Admin::StrokeOrderProvisioningService
  end
end
