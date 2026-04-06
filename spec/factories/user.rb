FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "test#{n}@example.com" }
    provider { "pocket_id" }
    sequence(:uid) { |n| "user-uid-#{n}" }
  end
end
