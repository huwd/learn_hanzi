FactoryBot.define do
  factory :meaning do
    association :dictionary_entry
    association :source
    pinyin { "gǎn dòng" }
    language { "en" }
    text { "to be touched" }
  end
end
