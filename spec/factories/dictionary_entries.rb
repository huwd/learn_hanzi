FactoryBot.define do
  factory :dictionary_entry do
    text { "感动" }
    pinyin { "gǎn dòng" }

    after(:build) do |entry|
      entry.meanings << build(:meaning, dictionary_entry: entry)
    end
  end
end
