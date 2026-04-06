class LearningSession < ApplicationRecord
  STATES = %w[in_progress completed abandoned].freeze

  belongs_to :user
  has_many :learning_session_cards, dependent: :destroy

  validates :state, presence: true, inclusion: { in: STATES }
  validates :started_at, presence: true

  scope :completed, -> { where(state: "completed") }
  scope :in_progress, -> { where(state: "in_progress") }

  def complete!
    update!(state: "completed", completed_at: Time.current)
  end

  def current_card(position)
    learning_session_cards.find_by!(position: position)
  end

  def reviewed_count
    learning_session_cards.where.not(reviewed_at: nil).count
  end
end
