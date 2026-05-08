FactoryBot.define do
  factory :dictionary_entry_radical do
    association :dictionary_entry
    association :radical
    sequence(:position)
  end
end
