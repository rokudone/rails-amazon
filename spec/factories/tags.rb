FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "Tag #{n}" }
    description { Faker::Lorem.sentence }

    trait :with_products do
      transient do
        products_count { 5 }
      end

      after(:create) do |tag, evaluator|
        create_list(:product_tag, evaluator.products_count, tag: tag)
      end
    end
  end
end
