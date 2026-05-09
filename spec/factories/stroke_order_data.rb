FactoryBot.define do
  factory :stroke_order_datum do
    association :dictionary_entry
    strokes { [ "M 0 0 L 10 10" ] }
    medians { [ [ [ 0, 0 ], [ 10, 10 ] ] ] }
    source { "makemeahanzi" }
  end
end
