FactoryBot.define do
  factory :supplier_order do
    association :warehouse
    sequence(:order_number) { |n| "PO-#{Date.today.strftime('%Y%m%d')}-#{n.to_s.rjust(4, '0')}" }
    supplier_name { "サプライヤー株式会社" }
    supplier_email { "supplier@example.com" }
    supplier_phone { "03-1234-5678" }
    supplier_contact_person { "鈴木一郎" }
    supplier_address { "東京都千代田区丸の内1-1-1" }
    order_date { Date.today }
    expected_delivery_date { 2.weeks.from_now.to_date }
    actual_delivery_date { nil }
    status { "draft" }
    total_amount { 100000 }
    tax_amount { 10000 }
    shipping_cost { 5000 }
    payment_terms { "30日以内" }
    payment_status { "pending" }
    shipping_method { "truck" }
    tracking_number { nil }
    notes { "標準的な発注" }
    created_by { "admin" }
    approved_by { nil }
    approved_at { nil }
    currency { "JPY" }
    exchange_rate { 1.0 }
    line_items {
      [
        {
          product_id: 1,
          variant_id: nil,
          sku: "SKU001",
          name: "商品A",
          quantity: 10,
          unit_price: 1000,
          total_price: 10000
        },
        {
          product_id: 2,
          variant_id: nil,
          sku: "SKU002",
          name: "商品B",
          quantity: 20,
          unit_price: 2000,
          total_price: 40000
        }
      ]
    }

    trait :draft do
      status { "draft" }
    end

    trait :submitted do
      status { "submitted" }
    end

    trait :confirmed do
      status { "confirmed" }
      approved_by { "manager" }
      approved_at { 1.day.ago }
    end

    trait :shipped do
      status { "shipped" }
      approved_by { "manager" }
      approved_at { 1.week.ago }
      tracking_number { "TRK123456789" }
    end

    trait :partially_received do
      status { "partially_received" }
      approved_by { "manager" }
      approved_at { 2.weeks.ago }
      tracking_number { "TRK123456789" }
    end

    trait :received do
      status { "received" }
      approved_by { "manager" }
      approved_at { 2.weeks.ago }
      tracking_number { "TRK123456789" }
      actual_delivery_date { Date.today }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :paid do
      payment_status { "paid" }
    end

    trait :partial_payment do
      payment_status { "partial" }
    end

    trait :international do
      supplier_name { "Global Supplies Inc." }
      supplier_email { "global@example.com" }
      supplier_phone { "+1-555-123-4567" }
      supplier_contact_person { "John Smith" }
      supplier_address { "123 Main St, New York, NY 10001, USA" }
      currency { "USD" }
      exchange_rate { 110.0 }
      shipping_method { "air_freight" }
    end

    trait :with_many_items do
      line_items {
        items = []
        30.times do |i|
          items << {
            product_id: i + 1,
            variant_id: nil,
            sku: "SKU#{(i + 1).to_s.rjust(3, '0')}",
            name: "商品#{(i + 65).chr}",
            quantity: rand(1..50),
            unit_price: rand(100..5000),
            total_price: rand(1000..100000)
          }
        end
        items
      }
      total_amount { 500000 }
    end

    trait :with_notes do
      notes { "この注文は優先的に処理してください。顧客からの特別注文のための仕入れです。" }
    end
  end
end
