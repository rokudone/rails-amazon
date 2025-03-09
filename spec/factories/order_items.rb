FactoryBot.define do
  factory :order_item do
    association :order
    association :product
    product_variant { nil }
    warehouse { nil }
    shipment { nil }
    return_record { nil }

    sequence(:sku) { |n| "SKU#{n.to_s.rjust(6, '0')}" }
    sequence(:name) { |n| "商品名#{n}" }
    description { "商品の説明文" }
    quantity { 1 }
    unit_price { 1000 }
    original_price { 1200 }
    discount_amount { 200 }
    discount_type { "percentage" }
    discount_description { "20%オフ" }
    tax_amount { 100 }
    tax_rate { 0.1 }
    subtotal { 1000 }
    total { 1100 }
    status { "pending" }
    is_gift { false }
    gift_message { nil }
    gift_wrap_type { nil }
    gift_wrap_cost { 0 }
    is_digital { false }
    digital_download_link { nil }
    download_count { 0 }
    download_expiry { nil }
    requires_shipping { true }
    weight { 0.5 }
    weight_unit { "kg" }
    dimensions { { "length": 10, "width": 5, "height": 2, "unit": "cm" } }
    return_reason { nil }
    notes { nil }
    metadata { {} }

    trait :with_variant do
      association :product_variant
    end

    trait :with_warehouse do
      association :warehouse
    end

    trait :with_shipment do
      association :shipment
      status { "shipped" }
    end

    trait :with_return do
      association :return_record, factory: :return
      status { "returned" }
      return_reason { "damaged" }
    end

    trait :pending do
      status { "pending" }
    end

    trait :processing do
      status { "processing" }
    end

    trait :shipped do
      status { "shipped" }
    end

    trait :delivered do
      status { "delivered" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :returned do
      status { "returned" }
      return_reason { "damaged" }
    end

    trait :digital do
      is_digital { true }
      requires_shipping { false }
      digital_download_link { "https://example.com/downloads/product123.zip" }
      download_expiry { 30.days.from_now }
    end

    trait :gift do
      is_gift { true }
      gift_message { "お誕生日おめでとう！素敵な一日になりますように。" }
      gift_wrap_type { "premium" }
      gift_wrap_cost { 500 }

      after(:create) do |item|
        create(:gift_wrap, order: item.order, order_item: item)
      end
    end

    trait :discounted do
      original_price { 2000 }
      unit_price { 1500 }
      discount_amount { 500 }
      discount_type { "fixed_amount" }
      discount_description { "500円引き" }
      subtotal { 1500 }
      total { 1650 }
    end

    trait :bulk do
      quantity { 10 }
      unit_price { 900 }
      original_price { 1000 }
      discount_amount { 1000 }
      discount_type { "bulk" }
      discount_description { "10個以上で10%オフ" }
      subtotal { 9000 }
      total { 9900 }
    end

    trait :heavy do
      weight { 10.0 }
      dimensions { { "length": 50, "width": 30, "height": 20, "unit": "cm" } }
    end

    trait :with_notes do
      notes { "特別な梱包が必要です。" }
    end

    trait :with_metadata do
      metadata { { "source_campaign": "summer_sale", "referrer": "email", "custom_field": "value" } }
    end
  end
end
