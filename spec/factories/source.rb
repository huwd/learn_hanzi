FactoryBot.define do
  factory :source do
    name { "Example Dictionary" }
    url { "https://example.com" }
    date_accessed { Date.today }

    trait :without_url do
      url { nil }
      date_accessed { nil }
    end
  end
end
