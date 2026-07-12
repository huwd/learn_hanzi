class ReviewLog < ApplicationRecord
  belongs_to :user_learning

  validates :ease, presence: true, inclusion: { in: 1..4 }

  after_create :set_developing_at_on_user_learning

  private

  # Durable milestone for Mastery::Coverage's Developing tier. Relies on
  # ReviewController#submit updating user_learning's state (and
  # first_mastered_at, if this review graduates it) before creating this
  # log, so first_mastered_at already reflects the current review's
  # outcome by the time this callback runs.
  def set_developing_at_on_user_learning
    return if user_learning.developing_at.present? || user_learning.first_mastered_at.present?
    return unless user_learning.review_logs.count == Mastery::Thresholds::EMERGING_TO_DEVELOPING_REVIEW_COUNT

    user_learning.update_column(:developing_at, Time.current)
  end
end
