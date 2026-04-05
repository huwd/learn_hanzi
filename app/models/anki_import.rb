class AnkiImport < ApplicationRecord
  belongs_to :user

  VALID_STATES = %w[pending running complete failed].freeze

  validates :state, inclusion: { in: VALID_STATES }

  scope :recent,      -> { order(created_at: :desc) }
  scope :in_progress, -> { where(state: %w[pending running]) }

  VALID_STATES.each do |s|
    define_method(:"#{s}?") { state == s }
  end
end
