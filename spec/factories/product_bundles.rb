FactoryBot.define do
  factory :product_bundle do
    sequence(:name) { |n| "Bundle #{n}" }
    description { Faker::Lorem.paragraph }
    price { Faker::Commerce.price(range: 50..2000.0) }
    discount_percentage { rand(5..30) }
    start_date { Time.current - 1.day }
    end_date { Time.current + 30.days }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :expired do
      start_date { Time.current - 60.days }
      end_date { Time.current - 1.day }
    end

    trait :upcoming do
      start_date { Time.current + 1.day }
      end_date { Time.current + 30.days }
    end

    trait :with_products do
      transient do
        products_count { 3 }
      end

      after(:create) do |bundle, evaluator|
        products = create_list(:product, evaluator.products_count)
        products.each do |product|
          create(:product_bundle_item, product_bundle: bundle, product: product, quantity: rand(1..3))
        end
      end
    end
  end
end
