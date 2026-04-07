require "rails_helper"

RSpec.describe DataExportService do
  let(:user) { create(:user) }
  let(:entry_ni) { create(:dictionary_entry, text: "你") }
  let(:entry_hao) { create(:dictionary_entry, text: "好") }

  describe ".call" do
    subject(:result) { described_class.call(user:) }

    context "with no learning data" do
      it "returns a hash with version 1" do
        expect(result[:version]).to eq(1)
      end

      it "includes an exported_at timestamp" do
        expect(result[:exported_at]).to be_present
      end

      it "includes an empty user_learnings array" do
        expect(result[:user_learnings]).to eq([])
      end
    end

    context "with user_learnings and review_logs" do
      let!(:ul) do
        create(:user_learning, user:, dictionary_entry: entry_ni,
               state: "mastered", last_interval: 30, factor: 2500,
               next_due: Time.zone.parse("2026-04-10 00:00:00"))
      end
      let!(:rl1) do
        create(:review_log, user_learning: ul, ease: 3, interval: 10,
               time_spent: 5000, factor: 2500, log_type: 2, time: 1_704_067_200_000)
      end
      let!(:rl2) do
        create(:review_log, user_learning: ul, ease: 4, interval: 30,
               time_spent: 3000, factor: 2500, log_type: 2, time: nil)
      end
      let!(:ul2) do
        create(:user_learning, user:, dictionary_entry: entry_hao, state: "new")
      end

      it "includes all user_learnings" do
        expect(result[:user_learnings].size).to eq(2)
      end

      it "includes the character text" do
        characters = result[:user_learnings].map { |ul| ul[:character] }
        expect(characters).to contain_exactly("你", "好")
      end

      it "orders user_learnings by character text for stable output" do
        characters = result[:user_learnings].map { |ul| ul[:character] }
        expect(characters).to eq(characters.sort)
      end

      it "orders review_logs by created_at for stable output" do
        ni_data = result[:user_learnings].find { |u| u[:character] == "你" }
        ids = ni_data[:review_logs].map { |r| r[:id] }
        expect(ids).to eq([ rl1.id, rl2.id ])
      end

      it "includes learning state fields" do
        ni_data = result[:user_learnings].find { |u| u[:character] == "你" }
        expect(ni_data[:state]).to eq("mastered")
        expect(ni_data[:last_interval]).to eq(30)
        expect(ni_data[:factor]).to eq(2500)
        expect(ni_data[:next_due]).to eq("2026-04-10T00:00:00.000Z")
      end

      it "includes created_at and updated_at" do
        ni_data = result[:user_learnings].find { |u| u[:character] == "你" }
        expect(ni_data[:created_at]).to be_present
        expect(ni_data[:updated_at]).to be_present
      end

      it "includes review_logs nested under each user_learning" do
        ni_data = result[:user_learnings].find { |u| u[:character] == "你" }
        expect(ni_data[:review_logs].size).to eq(2)
      end

      it "includes review_log fields" do
        ni_data = result[:user_learnings].find { |u| u[:character] == "你" }
        rl_data = ni_data[:review_logs].find { |r| r[:id] == rl1.id }
        expect(rl_data[:ease]).to eq(3)
        expect(rl_data[:interval]).to eq(10)
        expect(rl_data[:time_spent]).to eq(5000)
        expect(rl_data[:factor]).to eq(2500)
        expect(rl_data[:log_type]).to eq(2)
        expect(rl_data[:time]).to eq(1_704_067_200_000)
        expect(rl_data[:created_at]).to be_present
      end

      it "includes the review_log id for idempotent re-import" do
        ni_data = result[:user_learnings].find { |u| u[:character] == "你" }
        ids = ni_data[:review_logs].map { |r| r[:id] }
        expect(ids).to contain_exactly(rl1.id, rl2.id)
      end

      context "when a review_log was originally imported (has source_export_id)" do
        let!(:rl_imported) do
          create(:review_log, user_learning: ul, ease: 2, interval: 1,
                 time_spent: 1000, factor: 2500, log_type: 1, time: nil,
                 source_export_id: 999)
        end

        it "uses source_export_id as the exported id to preserve stable identifiers across re-export cycles" do
          ni_data = result[:user_learnings].find { |u| u[:character] == "你" }
          imported_rl_data = ni_data[:review_logs].find { |r| r[:id] == 999 }
          expect(imported_rl_data).not_to be_nil
        end
      end

      it "handles nil time in review_logs" do
        ni_data = result[:user_learnings].find { |u| u[:character] == "你" }
        rl_data = ni_data[:review_logs].find { |r| r[:id] == rl2.id }
        expect(rl_data[:time]).to be_nil
      end
    end
  end
end
