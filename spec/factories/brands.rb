FactoryBot.define do
  factory :brand do
    sequence(:name) { |n| "Brand #{n}" }
    description { Faker::Lorem.paragraph }
    logo { "https://example.com/logos/#{name.parameterize}.png" }
    website { "https://#{name.parameterize}.example.com" }
    country_of_origin { Faker::Address.country }
    year_established { rand(1900..2020) }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :with_products do
      transient do
        products_count { 5 }
      end

      after(:create) do |brand, evaluator|
        create_list(:product, evaluator.products_count, brand: brand)
      end
    end
  end
end
