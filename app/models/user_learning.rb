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
end
