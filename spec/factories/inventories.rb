FactoryBot.define do
  factory :inventory do
    association :product
    association :warehouse
    product_variant { nil }
    sequence(:sku) { |n| "SKU#{n.to_s.rjust(6, '0')}" }
    quantity { 100 }
    reserved_quantity { 0 }
    available_quantity { 100 }
    minimum_stock_level { 10 }
    maximum_stock_level { 200 }
    reorder_point { 20 }
    location_in_warehouse { "A-1-2-3" }
    last_restock_date { 1.month.ago }
    next_restock_date { 1.month.from_now }
    status { "active" }
    unit_cost { 10.0 }
    batch_number { "BATCH001" }
    expiry_date { 1.year.from_now }

    trait :with_variant do
      association :product_variant
    end

    trait :low_stock do
      quantity { 5 }
      available_quantity { 5 }
    end

    trait :out_of_stock do
      quantity { 0 }
      available_quantity { 0 }
    end

    trait :overstock do
      quantity { 250 }
      available_quantity { 250 }
    end

    trait :reserved do
      quantity { 100 }
      reserved_quantity { 50 }
      available_quantity { 50 }
    end

    trait :fully_reserved do
      quantity { 100 }
      reserved_quantity { 100 }
      available_quantity { 0 }
    end

    trait :inactive do
      status { "inactive" }
    end

    trait :expiring_soon do
      expiry_date { 10.days.from_now }
    end

    trait :expired do
      expiry_date { 10.days.ago }
    end

    trait :high_value do
      unit_cost { 1000.0 }
    end

    trait :needs_reorder do
      quantity { 15 }
      available_quantity { 15 }
      reorder_point { 20 }
    end
  end
end
