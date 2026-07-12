module Mastery
  # Replays a UserLearning's review_logs through the same new/learning/
  # mastered transition table SpacedRepetition::SM2#calculated_state uses,
  # deriving the durable milestone columns (first_mastered_at,
  # graduation_count, developing_at) that ActiveRecord callbacks alone
  # can't set for bulk-inserted data. AnkiImportService and
  # DataImportService both use ReviewLog.insert_all for performance, which
  # bypasses every callback entirely -- this is the shared replay those
  # call afterward to backfill the same milestones the live review flow
  # sets incrementally. See #391.
  class MilestoneReplay
    TRANSITIONS = {
      "new"      => { 1 => "learning", 2 => "learning", 3 => "learning", 4 => "learning" },
      "learning" => { 1 => "learning", 2 => "learning", 3 => "mastered", 4 => "mastered" },
      "mastered" => { 1 => "learning", 2 => "mastered", 3 => "mastered", 4 => "mastered" }
    }.freeze

    Result = Data.define(:first_mastered_at, :graduation_count, :developing_at)

    def self.call(review_logs)
      new(review_logs).call
    end

    def initialize(review_logs)
      @review_logs = review_logs.sort_by { |log| [ log.created_at, log.time || -1, log.id ] }
    end

    def call
      state = "new"
      first_mastered_at = nil
      graduation_count = 0
      developing_at = nil
      threshold = Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT

      @review_logs.each.with_index(1) do |log, review_count|
        new_state = TRANSITIONS.dig(state, log.ease)
        next if new_state.nil?

        if new_state == "mastered" && state != "mastered"
          graduation_count += 1
          first_mastered_at ||= log.created_at
        end

        developing_at = log.created_at if developing_at.nil? && review_count == threshold && first_mastered_at.nil?

        state = new_state
      end

      Result.new(first_mastered_at: first_mastered_at, graduation_count: graduation_count, developing_at: developing_at)
    end
  end
end
