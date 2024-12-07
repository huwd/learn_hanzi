FactoryBot.define do
  factory :tag do
    name { "HSK 4" }
    category { "HSK" }

    factory :parent_tag do
      after(:create) do |tag|
        create_list(:tag, parent: tag, name: "Chapter 1")
      end
    end
  end
end
