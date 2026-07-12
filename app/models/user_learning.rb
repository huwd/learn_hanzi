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
    if state_changed? && state == "mastered"
      self.mastered_at ||= Time.current
      # Durable "did this word ever graduate" fact — unlike mastered_at,
      # never cleared on lapse. See #391.
      self.first_mastered_at ||= mastered_at
      # Counts every crossing, unlike first_mastered_at which only records
      # the first. Feeds Mastery::Trajectory's Chronic classification.
      self.graduation_count += 1
    elsif state_changed? && state_was == "mastered"
      self.mastered_at = nil
    end
  end
end
