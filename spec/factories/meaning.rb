FactoryBot.define do
  factory :meaning do
    association :dictionary_entry
    language { "en" }
    text { "to be touched" }
  end
end
