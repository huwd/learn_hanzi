FactoryBot.define do
  factory :meaning do
    association :dictionary_entry
    pinyin { "gǎn dòng" }
    language { "en" }
    text { "to be touched" }
  end
end
