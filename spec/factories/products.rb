FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:sku) { |n| "SKU-#{n}-#{SecureRandom.hex(4).upcase}" }
    price { Faker::Commerce.price(range: 10..1000.0) }
    short_description { Faker::Lorem.paragraph(sentence_count: 2) }
    upc { Faker::Barcode.upc_a }
    manufacturer { Faker::Company.name }
    is_active { true }
    is_featured { false }
    published_at { Time.current }

    trait :with_brand do
      association :brand
    end

    trait :with_category do
      association :category
    end

    trait :inactive do
      is_active { false }
    end

    trait :featured do
      is_featured { true }
    end

    trait :unpublished do
      published_at { nil }
    end

    trait :with_variants do
      transient do
        variants_count { 3 }
      end

      after(:create) do |product, evaluator|
        create_list(:product_variant, evaluator.variants_count, product: product)
      end
    end

    trait :with_images do
      transient do
        images_count { 3 }
      end

      after(:create) do |product, evaluator|
        create_list(:product_image, evaluator.images_count, product: product)
        product.product_images.first.update(is_primary: true)
      end
    end

    trait :with_description do
      after(:create) do |product|
        create(:product_description, product: product)
      end
    end

    trait :with_specifications do
      transient do
        specifications_count { 5 }
      end

      after(:create) do |product, evaluator|
        create_list(:product_specification, evaluator.specifications_count, product: product)
      end
    end

    trait :with_attributes do
      transient do
        attributes_count { 5 }
      end

      after(:create) do |product, evaluator|
        create_list(:product_attribute, evaluator.attributes_count, product: product)
      end
    end

    trait :with_tags do
      transient do
        tags_count { 3 }
      end

      after(:create) do |product, evaluator|
        create_list(:product_tag, evaluator.tags_count, product: product)
      end
    end

    factory :complete_product do
      with_brand
      with_category
      with_variants
      with_images
      with_description
      with_specifications
      with_attributes
      with_tags
    end
  end
end
