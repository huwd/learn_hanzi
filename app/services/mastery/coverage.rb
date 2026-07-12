module Mastery
  # Classifies where a word sits right now: Unseen -> Emerging -> Developing
  # -> Established, with Suspended as a manual override outside that
  # sequence. See README.md in this directory. #391.
  class Coverage
    UNSEEN      = "unseen"
    EMERGING    = "emerging"
    DEVELOPING  = "developing"
    ESTABLISHED = "established"
    SUSPENDED   = "suspended"

    ALL = [ UNSEEN, EMERGING, DEVELOPING, ESTABLISHED, SUSPENDED ].freeze

    def self.call(user_learning:, review_count:)
      new(user_learning, review_count).call
    end

    def initialize(user_learning, review_count)
      @user_learning = user_learning
      @review_count = review_count
    end

    def call
      return SUSPENDED if @user_learning.state == "suspended"
      # first_mastered_at is the durable signal for Established and takes
      # precedence over review_count, which the caller could pass scoped
      # or stale.
      return ESTABLISHED if @user_learning.first_mastered_at.present?
      return UNSEEN if @review_count.zero?

      @review_count < Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT ? EMERGING : DEVELOPING
    end
  end
end
