FactoryBot.define do
  factory :anki_import do
    association :user
    state { "pending" }
    cards_imported { 0 }
    review_logs_imported { 0 }
  end
end
