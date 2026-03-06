FactoryBot.define do
  factory :dictionary_entry do
    sequence(:text) { |n| "感动#{n}" }

    after(:build) do |entry|
      entry.meanings << build(:meaning, dictionary_entry: entry)
    end
  end
end
