FactoryBot.define do
  factory :sub_category do
    association :category
    sequence(:name) { |n| "SubCategory #{n}" }
    sequence(:slug) { |n| "subcategory-#{n}" }
    description { Faker::Lorem.paragraph }
    position { rand(1..100) }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :with_products do
      transient do
        products_count { 5 }
      end

      after(:create) do |sub_category, evaluator|
        create_list(:product, evaluator.products_count, sub_category: sub_category)
      end
    end
  end
end
