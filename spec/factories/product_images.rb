FactoryBot.define do
  factory :product_image do
    association :product
    association :product_variant, required: false
    sequence(:image_url) { |n| "https://example.com/products/#{product.id}/images/image-#{n}.jpg" }
    sequence(:alt_text) { |n| "#{product.name} - Image #{n}" }
    position { rand(0..10) }
    is_primary { false }

    trait :primary do
      is_primary { true }
    end

    trait :for_variant do
      product_variant { association :product_variant, product: product }
    end
  end
end
