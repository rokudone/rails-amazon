FactoryBot.define do
  factory :shipment do
    association :order
    association :warehouse, optional: true

    sequence(:shipment_number) { |n| "SH#{n.to_s.rjust(8, '0')}" }
    carrier { "yamato" }
    service_level { "standard" }
    sequence(:tracking_number) { |n| "TRK#{n.to_s.rjust(10, '0')}" }
    status { "pending" }
    shipped_at { nil }
    estimated_delivery_date { 5.days.from_now }
    actual_delivery_date { nil }
    shipping_cost { 800 }
    insurance_cost { 0 }
    is_insured { false }
    declared_value { nil }
    weight { 2.5 }
    weight_unit { "kg" }
    dimensions { { "length": 30, "width": 20, "height": 15, "unit": "cm" } }
    dimensions_unit { "cm" }
    package_count { 1 }
    shipping_method { "ground" }
    shipping_notes { nil }
    recipient_name { "山田花子" }
    recipient_phone { "090-1234-5678" }
    recipient_email { "hanako@example.com" }
    shipping_address_line1 { "東京都渋谷区神宮前1-1-1" }
    shipping_address_line2 { "渋谷ビル101" }
    shipping_city { "渋谷区" }
    shipping_state { "東京都" }
    shipping_postal_code { "150-0001" }
    shipping_country { "日本" }
    requires_signature { false }
    is_gift { false }
    gift_message { nil }
    customs_declaration_number { nil }
    customs_information { nil }
    return_label_url { nil }
    shipping_label_url { "https://example.com/labels/shipping_label.pdf" }
    packing_slip_url { "https://example.com/labels/packing_slip.pdf" }
    created_by { "system" }
    metadata { {} }

    trait :pending do
      status { "pending" }
    end

    trait :processing do
      status { "processing" }
    end

    trait :shipped do
      status { "shipped" }
      shipped_at { Time.current }
    end

    trait :in_transit do
      status { "in_transit" }
      shipped_at { 2.days.ago }
    end

    trait :out_for_delivery do
      status { "out_for_delivery" }
      shipped_at { 4.days.ago }
    end

    trait :delivered do
      status { "delivered" }
      shipped_at { 5.days.ago }
      actual_delivery_date { Time.current }
    end

    trait :failed do
      status { "failed" }
      shipped_at { 5.days.ago }
    end

    trait :returned do
      status { "returned" }
      shipped_at { 5.days.ago }
    end

    trait :with_tracking do
      after(:create) do |shipment|
        create(:shipment_tracking, shipment: shipment, order: shipment.order)
      end
    end

    trait :with_multiple_tracking do
      after(:create) do |shipment|
        create(:shipment_tracking, shipment: shipment, order: shipment.order, status: 'shipped', tracking_date: 2.days.ago)
        create(:shipment_tracking, shipment: shipment, order: shipment.order, status: 'in_transit', tracking_date: 1.day.ago)
        create(:shipment_tracking, shipment: shipment, order: shipment.order, status: 'out_for_delivery', tracking_date: 3.hours.ago)
      end
    end

    trait :with_items do
      transient do
        items_count { 3 }
      end

      after(:create) do |shipment, evaluator|
        evaluator.items_count.times do
          order_item = create(:order_item, order: shipment.order)
          order_item.update(shipment: shipment, status: 'shipped')
        end
      end
    end

    trait :yamato do
      carrier { "yamato" }
      service_level { "standard" }
    end

    trait :sagawa do
      carrier { "sagawa" }
      service_level { "standard" }
    end

    trait :japan_post do
      carrier { "japan_post" }
      service_level { "yu_pack" }
    end

    trait :fedex do
      carrier { "fedex" }
      service_level { "international_priority" }
    end

    trait :dhl do
      carrier { "dhl" }
      service_level { "express" }
    end

    trait :amazon_logistics do
      carrier { "amazon_logistics" }
      service_level { "standard" }
    end

    trait :express do
      shipping_method { "express" }
      service_level { "express" }
      shipping_cost { 1500 }
    end

    trait :international do
      shipping_method { "international" }
      service_level { "international_priority" }
      shipping_cost { 3000 }
      customs_declaration_number { "CUST123456789" }
      customs_information { { "contents_type": "merchandise", "value": 15000, "currency": "JPY", "country_of_origin": "JP" } }

      shipping_address_line1 { "123 Main St" }
      shipping_city { "New York" }
      shipping_state { "NY" }
      shipping_postal_code { "10001" }
      shipping_country { "USA" }
    end

    trait :insured do
      is_insured { true }
      insurance_cost { 500 }
      declared_value { 50000 }
    end

    trait :signature_required do
      requires_signature { true }
    end

    trait :gift do
      is_gift { true }
      gift_message { "お誕生日おめでとう！素敵な一日になりますように。" }
    end

    trait :heavy do
      weight { 20.0 }
      dimensions { { "length": 100, "width": 80, "height": 60, "unit": "cm" } }
      package_count { 2 }
    end

    trait :with_notes do
      shipping_notes { "配達時に電話してください。" }
    end
  end
end
