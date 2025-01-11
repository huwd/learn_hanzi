class ReviewLog < ApplicationRecord
  belongs_to :user_learning

  validates :ease, presence: true, inclusion: { in: 1..4 }
  validates :reviewed_at, presence: true
end
