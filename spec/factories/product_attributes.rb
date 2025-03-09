FactoryBot.define do
  factory :product_attribute do
    association :product
    sequence(:name) { |n| ["Material", "Color", "Size", "Weight", "Dimensions", "Country of Origin", "Warranty", "Feature #{n}"].sample }
    sequence(:value) { |n| "Value #{n}" }
    is_filterable { [true, false].sample }
    is_searchable { [true, false].sample }

    trait :filterable do
      is_filterable { true }
    end

    trait :searchable do
      is_searchable { true }
    end

    trait :material do
      name { "Material" }
      value { Faker::Commerce.material }
    end

    trait :color do
      name { "Color" }
      value { Faker::Commerce.color }
    end

    trait :size do
      name { "Size" }
      value { %w[XS S M L XL XXL].sample }
    end
  end
end
