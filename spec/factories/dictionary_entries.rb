FactoryBot.define do
  factory :dictionary_entry do
    text { "感动" }

    after(:build) do |entry|
      entry.meanings << build(:meaning, dictionary_entry: entry)
    end
  end
end
