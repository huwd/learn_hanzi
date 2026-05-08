FactoryBot.define do
  factory :dictionary_entry do
    sequence(:text) { |n| "感动#{n}" }

    transient do
      meanings_count { 1 }
    end

    after(:build) do |entry, evaluator|
      if entry.meanings.empty? && evaluator.meanings_count > 0
        evaluator.meanings_count.times do
          entry.meanings << build(:meaning, dictionary_entry: entry)
        end
      end
    end
  end
end
