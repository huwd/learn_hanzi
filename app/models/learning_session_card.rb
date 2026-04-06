class LearningSessionCard < ApplicationRecord
  belongs_to :learning_session
  belongs_to :user_learning

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, uniqueness: { scope: :learning_session_id }
  validates :user_learning_id, uniqueness: { scope: :learning_session_id }
  validates :ease, inclusion: { in: [ 1, 2, 3, 4 ] }, allow_nil: true
end
