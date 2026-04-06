class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :user_learnings, dependent: :destroy
  has_many :anki_imports, dependent: :destroy

  validates :email_address, presence: true
  validates :email_address, uniqueness: true
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :session_size, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 100 }
  validates :new_cards_per_session, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :new_cards_per_session_within_session_size

  private

  def new_cards_per_session_within_session_size
    return unless session_size.present? && new_cards_per_session.present?
    return unless new_cards_per_session > session_size

    errors.add(:new_cards_per_session, "cannot exceed session size")
  end
end
