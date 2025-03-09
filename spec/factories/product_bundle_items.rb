FactoryBot.define do
  factory :product_bundle_item do
    association :product_bundle
    association :product
    quantity { rand(1..5) }
  end
end
