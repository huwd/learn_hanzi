class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :user_learnings, dependent: :destroy
  has_many :anki_imports, dependent: :destroy
  has_many :learning_sessions, dependent: :destroy

  validates :email_address, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def self.find_or_create_by_omniauth(auth)
    user = find_or_create_by!(provider: auth.provider, uid: auth.uid) do |u|
      u.email_address = auth.info.email
    end
    user.update!(email_address: auth.info.email) if user.email_address != auth.info.email.to_s.strip.downcase
    user
  rescue ActiveRecord::RecordNotUnique
    find_by!(provider: auth.provider, uid: auth.uid)
  end

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
