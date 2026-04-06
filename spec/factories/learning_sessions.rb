FactoryBot.define do
  factory :learning_session do
    association :user
    state { "in_progress" }
    started_at { Time.current }
    card_count { 0 }
  end
end
