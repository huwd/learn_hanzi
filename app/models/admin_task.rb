class AdminTask < ApplicationRecord
  VALID_TASK_TYPES = %w[cc_cedict hsk_tags custom_dictionary].freeze
  VALID_STATES     = %w[pending running complete failed].freeze

  validates :task_type, presence: true, inclusion: { in: VALID_TASK_TYPES }
  validates :state,     presence: true, inclusion: { in: VALID_STATES }

  scope :in_progress, -> { where(state: %w[pending running]) }
  scope :recent,      -> { order(created_at: :desc) }

  VALID_STATES.each do |s|
    define_method(:"#{s}?") { state == s }
  end

  def summary_hash
    return {} if summary.blank?

    JSON.parse(summary)
  rescue JSON::ParserError
    {}
  end

  def self.locked_for?(task_type)
    in_progress.exists?(task_type: task_type)
  end

  def self.latest_for(task_type)
    where(task_type: task_type).order(created_at: :desc).first
  end
end
