class StrokeOrderDatum < ApplicationRecord
  belongs_to :dictionary_entry

  validates :source, presence: true

  def strokes
    parse_json_array(super)
  end

  def strokes=(value)
    super(serialize_json_array(value))
  end

  def medians
    parse_json_array(super)
  end

  def medians=(value)
    super(serialize_json_array(value))
  end

  private

  def parse_json_array(value)
    return value if value.is_a?(Array)
    return [] if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError
    []
  end

  def serialize_json_array(value)
    value.is_a?(String) ? value : value.to_json
  end
end
