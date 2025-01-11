FactoryBot.define do
  factory :review_log do
    association :user_learning
    ease { [ 1, 2, 3, 4 ].sample }
    interval { rand(1..30) } # Example: interval in days
    time_spent { rand(500..5000) } # Example: time spent in milliseconds
    reviewed_at { Time.now - rand(1..100).days }
  end
end
