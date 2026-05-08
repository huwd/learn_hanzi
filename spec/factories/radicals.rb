FactoryBot.define do
  factory :radical do
    sequence(:character) { |n| "部#{n}" }
    meaning { "component" }
    stroke_count { 4 }
  end
end
