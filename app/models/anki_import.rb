class AnkiImport < ApplicationRecord
  belongs_to :user

  VALID_STATES = %w[pending running complete failed].freeze

  validates :state, inclusion: { in: VALID_STATES }

  scope :recent, -> { order(created_at: :desc) }

  VALID_STATES.each do |s|
    define_method(:"#{s}?") { state == s }
  end
end
