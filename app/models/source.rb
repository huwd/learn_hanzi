class Source < ApplicationRecord
  has_many :meanings, dependent: :nullify

  validates :name, presence: true
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }, allow_nil: true
  validates :date_accessed, presence: true, if: -> { url.present? }
end
