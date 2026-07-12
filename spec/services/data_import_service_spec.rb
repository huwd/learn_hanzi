require "rails_helper"

RSpec.describe DataImportService do
  let(:user) { create(:user) }
  let(:entry_ni) { create(:dictionary_entry, text: "你") }
  let(:entry_hao) { create(:dictionary_entry, text: "好") }

  let(:base_export) do
    {
      "version" => 1,
      "exported_at" => "2026-04-07T12:00:00Z",
      "user_learnings" => []
    }
  end

  describe ".call" do
    subject(:result) { described_class.call(user:, data: export_data) }

    context "with an unsupported version" do
      let(:export_data) { base_export.merge("version" => 99) }

      it "raises an error" do
        expect { result }.to raise_error(DataImportService::UnsupportedVersionError)
      end
    end

    context "with no user_learnings" do
      let(:export_data) { base_export }

      it "returns zero counts" do
        expect(result[:learnings_upserted]).to eq(0)
        expect(result[:review_logs_inserted]).to eq(0)
      end
    end

    context "when user_learnings key is missing from the export" do
      let(:export_data) { { "version" => 1, "exported_at" => "2026-04-07T12:00:00Z" } }

      it "returns zero counts without raising" do
        expect(result[:learnings_upserted]).to eq(0)
      end
    end

    context "when importing new user_learnings" do
      let(:export_data) do
        base_export.merge("user_learnings" => [
          {
            "character" => "你",
            "state" => "mastered",
            "next_due" => "2026-04-10T00:00:00Z",
            "last_interval" => 30,
            "factor" => 2500,
            "created_at" => "2026-01-01T00:00:00Z",
            "updated_at" => "2026-04-01T00:00:00Z",
            "review_logs" => []
          }
        ])
      end

      before { entry_ni }

      it "creates the user_learning" do
        expect { result }.to change { user.user_learnings.count }.by(1)
      end

      it "sets the correct state and scheduling" do
        result
        ul = user.user_learnings.find_by(dictionary_entry: entry_ni)
        expect(ul.state).to eq("mastered")
        expect(ul.last_interval).to eq(30)
        expect(ul.factor).to eq(2500)
        expect(ul.next_due).to be_within(1.second).of(Time.zone.parse("2026-04-10T00:00:00Z"))
      end

      it "preserves the export updated_at so subsequent imports compare correctly" do
        result
        ul = user.user_learnings.find_by(dictionary_entry: entry_ni)
        expect(ul.updated_at).to be_within(1.second).of(Time.zone.parse("2026-04-01T00:00:00Z"))
      end

      it "preserves the export created_at" do
        result
        ul = user.user_learnings.find_by(dictionary_entry: entry_ni)
        expect(ul.created_at).to be_within(1.second).of(Time.zone.parse("2026-01-01T00:00:00Z"))
      end

      it "returns learnings_upserted count of 1" do
        expect(result[:learnings_upserted]).to eq(1)
      end
    end

    context "when the character does not exist in the dictionary" do
      let(:export_data) do
        base_export.merge("user_learnings" => [
          {
            "character" => "不存在",
            "state" => "new",
            "next_due" => nil,
            "last_interval" => nil,
            "factor" => 2500,
            "created_at" => "2026-01-01T00:00:00Z",
            "updated_at" => "2026-01-01T00:00:00Z",
            "review_logs" => []
          }
        ])
      end

      it "skips the entry and returns zero upserted" do
        expect(result[:learnings_upserted]).to eq(0)
      end
    end

    context "when a user_learning already exists and the export is newer" do
      let(:original_created_at) { Time.zone.parse("2025-06-01T00:00:00Z") }
      let!(:existing_ul) do
        create(:user_learning, user:, dictionary_entry: entry_ni,
               state: "learning", factor: 2000,
               created_at: original_created_at,
               updated_at: Time.zone.parse("2026-03-01T00:00:00Z"))
      end

      let(:export_data) do
        base_export.merge("user_learnings" => [
          {
            "character" => "你",
            "state" => "mastered",
            "next_due" => "2026-04-10T00:00:00Z",
            "last_interval" => 30,
            "factor" => 2500,
            "created_at" => "2026-01-01T00:00:00Z",
            "updated_at" => "2026-04-01T00:00:00Z",
            "review_logs" => []
          }
        ])
      end

      it "updates the user_learning" do
        result
        expect(existing_ul.reload.state).to eq("mastered")
        expect(existing_ul.reload.factor).to eq(2500)
      end

      it "persists the export updated_at on the record" do
        result
        expect(existing_ul.reload.updated_at)
          .to be_within(1.second).of(Time.zone.parse("2026-04-01T00:00:00Z"))
      end

      it "does not overwrite the local created_at" do
        result
        expect(existing_ul.reload.created_at)
          .to be_within(1.second).of(original_created_at)
      end
    end

    context "when a user_learning already exists and the local record is newer" do
      let!(:existing_ul) do
        create(:user_learning, user:, dictionary_entry: entry_ni,
               state: "mastered", factor: 2700,
               updated_at: Time.zone.parse("2026-04-06T00:00:00Z"))
      end

      let(:export_data) do
        base_export.merge("user_learnings" => [
          {
            "character" => "你",
            "state" => "learning",
            "next_due" => nil,
            "last_interval" => 5,
            "factor" => 2000,
            "created_at" => "2026-01-01T00:00:00Z",
            "updated_at" => "2026-03-01T00:00:00Z",
            "review_logs" => []
          }
        ])
      end

      it "does not overwrite the local record" do
        result
        expect(existing_ul.reload.state).to eq("mastered")
        expect(existing_ul.reload.factor).to eq(2700)
      end
    end

    context "when imported twice with advancing export timestamps" do
      let!(:existing_ul) do
        create(:user_learning, user:, dictionary_entry: entry_ni,
               state: "new", factor: 2500,
               updated_at: Time.zone.parse("2026-01-01T00:00:00Z"))
      end

      it "applies both updates in order, even though import time > export updated_at" do
        first_export = base_export.merge("user_learnings" => [
          {
            "character" => "你", "state" => "learning", "next_due" => nil,
            "last_interval" => 5, "factor" => 2100,
            "created_at" => "2026-01-01T00:00:00Z", "updated_at" => "2026-03-01T00:00:00Z",
            "review_logs" => []
          }
        ])
        second_export = base_export.merge("user_learnings" => [
          {
            "character" => "你", "state" => "mastered", "next_due" => "2026-06-01T00:00:00Z",
            "last_interval" => 30, "factor" => 2500,
            "created_at" => "2026-01-01T00:00:00Z", "updated_at" => "2026-05-01T00:00:00Z",
            "review_logs" => []
          }
        ])

        described_class.call(user:, data: first_export)
        described_class.call(user:, data: second_export)

        expect(existing_ul.reload.state).to eq("mastered")
        expect(existing_ul.reload.factor).to eq(2500)
      end
    end

    context "when importing review_logs" do
      let!(:ul) do
        create(:user_learning, user:, dictionary_entry: entry_ni, state: "mastered")
      end

      let(:export_data) do
        base_export.merge("user_learnings" => [
          {
            "character" => "你",
            "state" => "mastered",
            "next_due" => nil,
            "last_interval" => 30,
            "factor" => 2500,
            "created_at" => ul.created_at.iso8601,
            "updated_at" => ul.updated_at.iso8601,
            "review_logs" => [
              {
                "id" => 101,
                "ease" => 3,
                "interval" => 10,
                "time_spent" => 5000,
                "factor" => 2500,
                "log_type" => 2,
                "time" => 1_704_067_200_000,
                "created_at" => "2026-01-15T10:00:00Z"
              }
            ]
          }
        ])
      end

      it "creates the review_log" do
        expect { result }.to change { ul.review_logs.count }.by(1)
      end

      it "sets the review_log fields correctly" do
        result
        rl = ul.review_logs.last
        expect(rl.ease).to eq(3)
        expect(rl.interval).to eq(10)
        expect(rl.time_spent).to eq(5000)
        expect(rl.factor).to eq(2500)
        expect(rl.log_type).to eq(2)
        expect(rl.time).to eq(1_704_067_200_000)
        expect(rl.source_export_id).to eq(101)
      end

      it "returns the accurate review_logs_inserted count" do
        expect(result[:review_logs_inserted]).to eq(1)
      end

      context "when a review_log has an invalid ease value" do
        let(:export_with_bad_ease) do
          base_export.merge("user_learnings" => [
            {
              "character" => "你",
              "state" => "mastered",
              "next_due" => nil,
              "last_interval" => 30,
              "factor" => 2500,
              "created_at" => ul.created_at.iso8601,
              "updated_at" => ul.updated_at.iso8601,
              "review_logs" => [
                {
                  "id" => 200,
                  "ease" => 99,
                  "interval" => 10,
                  "time_spent" => 5000,
                  "factor" => 2500,
                  "log_type" => 2,
                  "time" => nil,
                  "created_at" => "2026-01-15T10:00:00Z"
                }
              ]
            }
          ])
        end

        it "skips the invalid row without raising" do
          expect { described_class.call(user:, data: export_with_bad_ease) }
            .not_to change { ul.review_logs.count }
        end
      end

      context "when run twice with the same data (idempotency)" do
        it "does not create duplicate review_logs" do
          described_class.call(user:, data: export_data)
          expect { described_class.call(user:, data: export_data) }
            .not_to change { ul.review_logs.count }
        end

        it "reports zero review_logs_inserted on the second run" do
          described_class.call(user:, data: export_data)
          second_result = described_class.call(user:, data: export_data)
          expect(second_result[:review_logs_inserted]).to eq(0)
        end
      end
    end

    context "when imported review_logs graduate the word on replay" do
      # ReviewLog.insert_all bypasses every callback, so first_mastered_at/
      # graduation_count only get set by the explicit post-import
      # Mastery::MilestoneReplay backfill. See #391.
      let!(:ul) do
        create(:user_learning, user:, dictionary_entry: entry_ni, state: "learning",
               updated_at: Time.zone.parse("2026-01-01T00:00:00Z"))
      end

      let(:export_data) do
        base_export.merge("user_learnings" => [
          {
            "character" => "你",
            "state" => "mastered",
            "next_due" => nil,
            "last_interval" => 30,
            "factor" => 2500,
            "created_at" => ul.created_at.iso8601,
            "updated_at" => "2026-04-01T00:00:00Z",
            "review_logs" => [
              {
                "id" => 301, "ease" => 3, "interval" => 1, "time_spent" => 1000,
                "factor" => 2500, "log_type" => 0, "time" => nil,
                "created_at" => "2026-01-10T09:00:00Z"
              },
              {
                "id" => 302, "ease" => 3, "interval" => 5, "time_spent" => 1000,
                "factor" => 2500, "log_type" => 1, "time" => nil,
                "created_at" => "2026-01-12T09:00:00Z"
              }
            ]
          }
        ])
      end

      it "sets first_mastered_at from the replayed graduating review, not import time" do
        result
        expect(ul.reload.first_mastered_at)
          .to be_within(1.second).of(Time.zone.parse("2026-01-12T09:00:00Z"))
      end

      it "sets graduation_count to 1" do
        result
        expect(ul.reload.graduation_count).to eq(1)
      end
    end

    context "when imported review_logs never graduate the word" do
      let!(:ul) do
        create(:user_learning, user:, dictionary_entry: entry_ni, state: "learning",
               updated_at: Time.zone.parse("2026-01-01T00:00:00Z"))
      end

      let(:export_data) do
        base_export.merge("user_learnings" => [
          {
            "character" => "你",
            "state" => "learning",
            "next_due" => nil,
            "last_interval" => 1,
            "factor" => 2300,
            "created_at" => ul.created_at.iso8601,
            "updated_at" => "2026-04-01T00:00:00Z",
            "review_logs" => [
              {
                "id" => 401, "ease" => 1, "interval" => 1, "time_spent" => 1000,
                "factor" => 2300, "log_type" => 0, "time" => nil,
                "created_at" => "2026-01-10T09:00:00Z"
              }
            ]
          }
        ])
      end

      it "leaves first_mastered_at nil" do
        result
        expect(ul.reload.first_mastered_at).to be_nil
        expect(ul.reload.graduation_count).to eq(0)
      end
    end

    context "the milestone backfill's review_logs fetch" do
      # Used to run once per imported word (O(words) SELECTs, dominating
      # import time on large exports); Mastery::MilestoneReplay.backfill!
      # batches it instead. See #391.
      # Scoped to review_logs SELECTs specifically, not overall query
      # count -- upsert_user_learning already does its own per-word
      # lookups (a separate, pre-existing pattern unrelated to this fix),
      # which would otherwise mask whether the review_logs fetch itself
      # is bounded.
      def review_log_select_count
        count = 0
        sub = lambda do |_name, _start, _finish, _id, payload|
          sql = payload[:sql].to_s
          count += 1 if sql.lstrip.upcase.start_with?("SELECT") && sql.include?("review_logs")
        end
        ActiveSupport::Notifications.subscribed(sub, "sql.active_record") { yield }
        count
      end

      def word_payload(character, id)
        {
          "character" => character, "state" => "learning", "next_due" => nil,
          "last_interval" => 1, "factor" => 2300,
          "created_at" => "2026-01-01T00:00:00Z", "updated_at" => "2026-04-01T00:00:00Z",
          "review_logs" => [
            { "id" => id, "ease" => 1, "interval" => 1, "time_spent" => 1000,
              "factor" => 2300, "log_type" => 0, "time" => nil,
              "created_at" => "2026-01-10T09:00:00Z" }
          ]
        }
      end

      it "stays bounded regardless of how many words are imported" do
        entry_ni
        one_word = base_export.merge("user_learnings" => [ word_payload("你", 501) ])
        count_with_one = review_log_select_count { described_class.call(user:, data: one_word) }

        other_user = create(:user)
        many_entries = 15.times.map { |i| create(:dictionary_entry, text: "字#{i}") }
        many_words = base_export.merge(
          "user_learnings" => many_entries.each_with_index.map { |e, i| word_payload(e.text, 600 + i) }
        )
        count_with_many = review_log_select_count { described_class.call(user: other_user, data: many_words) }

        expect(count_with_many).to eq(count_with_one)
      end
    end
  end
end
