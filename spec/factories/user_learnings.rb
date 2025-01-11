# Factory for UserLearning
FactoryBot.define do
  factory :user_learning do
    association :dictionary_entry
    state { 'new' }
    next_due { Time.now + 7.days }
    last_interval { 1 }
  end
end
