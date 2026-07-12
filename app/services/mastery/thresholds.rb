module Mastery
  # Configurable constants behind the Coverage/Trajectory classification
  # (#391). See README.md in this directory for how each value was derived
  # and how to re-derive it if the underlying learning data changes shape.
  module Thresholds
    # A word with fewer reviews than this and no graduation yet is
    # "Emerging" (normal early-stage noise); at or above it, "Developing".
    EMERGING_TO_DEVELOPING_REVIEW_COUNT = 5

    # Number of distinct learning -> mastered crossings (UserLearning#graduation_count)
    # at or above which a word is classified "Chronic".
    CHRONIC_MIN_GRADUATIONS = 2

    # A word can only be considered "Stalled" once it has at least this many
    # reviews without ever graduating. Deliberately the same value as
    # EMERGING_TO_DEVELOPING_REVIEW_COUNT: Stalled is a subset of Developing.
    STALLED_MIN_REVIEW_COUNT = EMERGING_TO_DEVELOPING_REVIEW_COUNT

    # How many of the most recent reviews to look at when checking whether
    # a never-graduated word's ease has gone flat/declining.
    STALLED_LOOKBACK_REVIEWS = 3

    # A never-graduated word is "Stalled" when the average ease over its
    # last STALLED_LOOKBACK_REVIEWS reviews is at or below this value.
    STALLED_MAX_RECENT_AVERAGE_EASE = 1.5
  end
end
