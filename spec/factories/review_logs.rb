FactoryBot.define do
  factory :review_log do
    association :user_learning
    ease { [ 1, 2, 3, 4 ].sample }
    interval { rand(1..30) } # Example: interval in days
    time_spent { rand(500..5000) } # Example: time spent in milliseconds
    factor { rand(1300..2000) } # Example: factor
    time { Time.now.to_i }
    log_type { [ 0, 1, 2, 3 ].sample }
  end
end
