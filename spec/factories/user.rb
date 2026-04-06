FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "test#{n}@example.com" }
    provider { OIDC_PROVIDER_NAME }
    sequence(:uid) { |n| "user-uid-#{n}" }
  end
end
