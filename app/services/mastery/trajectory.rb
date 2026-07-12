module Mastery
  # Classifies the shape of a word's history: Stable / Recovering / Chronic
  # / Stalled. Only meaningful once a word has enough history — the caller
  # supplies the word's Mastery::Coverage bucket, and this returns
  # NOT_APPLICABLE for anything outside Developing/Established. See
  # README.md in this directory. #391.
  class Trajectory
    STABLE         = "stable"
    RECOVERING     = "recovering"
    CHRONIC        = "chronic"
    STALLED        = "stalled"
    NOT_APPLICABLE = "not_applicable"

    ALL = [ STABLE, RECOVERING, CHRONIC, STALLED, NOT_APPLICABLE ].freeze

    ELIGIBLE_COVERAGE = [ Coverage::DEVELOPING, Coverage::ESTABLISHED ].freeze

    def self.call(user_learning:, coverage:, recent_eases:)
      new(user_learning, coverage, recent_eases).call
    end

    def initialize(user_learning, coverage, recent_eases)
      @user_learning = user_learning
      @coverage = coverage
      @recent_eases = recent_eases
    end

    def call
      return NOT_APPLICABLE unless ELIGIBLE_COVERAGE.include?(@coverage)
      return CHRONIC if @user_learning.graduation_count >= Thresholds::CHRONIC_MIN_GRADUATIONS
      return RECOVERING if @user_learning.graduation_count == 1 && @user_learning.state != "mastered"
      return STALLED if @user_learning.graduation_count.zero? && stalled?

      STABLE
    end

    private

    def stalled?
      return false if @recent_eases.empty?

      recent = @recent_eases.last(Thresholds::STALLED_LOOKBACK_REVIEWS)
      (recent.sum.to_f / recent.size) <= Thresholds::STALLED_MAX_RECENT_AVERAGE_EASE
    end
  end
end
