FactoryBot.define do
  factory :product_variant do
    association :product
    sequence(:sku) { |n| "VARIANT-#{n}-#{SecureRandom.hex(4).upcase}" }
    name { "#{product.name} - #{Faker::Commerce.color} #{Faker::Commerce.material}" }
    price { Faker::Commerce.price(range: 10..1000.0) }
    compare_at_price { price * 1.2 }
    color { Faker::Commerce.color }
    size { %w[XS S M L XL XXL].sample }
    material { Faker::Commerce.material }
    style { %w[Casual Formal Sport Vintage Modern].sample }
    weight { rand(0.1..10.0).round(2) }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :on_sale do
      compare_at_price { price * rand(1.1..1.5) }
    end

    trait :with_images do
      transient do
        images_count { 2 }
      end

      after(:create) do |variant, evaluator|
        create_list(:product_image, evaluator.images_count, product: variant.product, product_variant: variant)
        variant.product_images.first.update(is_primary: true)
      end
    end
  end
end
