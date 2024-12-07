FactoryBot.define do
  factory :dictionary_entry_tag do
    association :dictionary_entry
    association :tag
  end
end
