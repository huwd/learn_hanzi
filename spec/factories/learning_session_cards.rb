FactoryBot.define do
  factory :learning_session_card do
    association :learning_session
    association :user_learning
    position { 0 }
  end
end
