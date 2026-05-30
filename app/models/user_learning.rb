class UserLearning < ApplicationRecord
  belongs_to :user
  belongs_to :dictionary_entry

  has_many :review_logs, dependent: :destroy

  validates :state, presence: true, inclusion: { in: [ "new", "learning", "mastered", "suspended" ] }
  validates :user, uniqueness: { scope: :dictionary_entry, message: "already has a learning record for this entry" }

  # Scopes for filtering by state
  scope :new_learnings, -> { where(state: "new") }
  scope :in_progress, -> { where(state: "learning") }
  scope :mastered, -> { where(state: "mastered") }
  scope :suspended, -> { where(state: "suspended") }

  # Scopes for session composition
  scope :due, -> { where("next_due <= ?", Time.current) }
  scope :overdue_learning, -> { in_progress.due }
  scope :due_mastered, -> { mastered.due }

  before_save :set_mastered_at

  private

  def set_mastered_at
    if state_changed? && state == "mastered" && mastered_at.nil?
      self.mastered_at = Time.current
    elsif state_changed? && state_was == "mastered"
      self.mastered_at = nil
    end
  end
end
