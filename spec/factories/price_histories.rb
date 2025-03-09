FactoryBot.define do
  factory :price_history do
    association :product
    association :product_variant, required: false
    old_price { Faker::Commerce.price(range: 10..1000.0) }
    new_price { Faker::Commerce.price(range: 10..1000.0) }
    reason { ["Price adjustment", "Seasonal discount", "Promotion", "Cost increase", "Competitor pricing", "Inventory clearance", nil].sample }

    trait :price_increase do
      old_price { Faker::Commerce.price(range: 10..500.0) }
      new_price { old_price * rand(1.05..1.5) }
      reason { ["Cost increase", "Supplier price change", "Market adjustment", "Demand increase"].sample }
    end

    trait :price_decrease do
      old_price { Faker::Commerce.price(range: 100..1000.0) }
      new_price { old_price * rand(0.5..0.95) }
      reason { ["Seasonal discount", "Promotion", "Inventory clearance", "Competitor pricing"].sample }
    end

    trait :for_variant do
      product_variant { association :product_variant, product: product }
    end
  end
end
