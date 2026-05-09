class AudioPronunciation < ApplicationRecord
  SOURCE_KRMANIK = "krmanik".freeze
  LOCALE_ZH_CN = "zh-CN".freeze

  belongs_to :dictionary_entry
  has_one_attached :audio

  validates :source, presence: true
  validates :locale, presence: true
  validates :source, uniqueness: { scope: [ :dictionary_entry_id, :locale ] }
  validate :audio_must_be_attached

  private

  def audio_must_be_attached
    errors.add(:audio, "must be attached") unless audio.attached?
  end
end
