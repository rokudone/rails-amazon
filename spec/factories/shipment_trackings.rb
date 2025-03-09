FactoryBot.define do
  factory :shipment_tracking do
    association :shipment
    association :order, optional: true

    sequence(:tracking_number) { |n| "TRK#{n.to_s.rjust(10, '0')}" }
    carrier { "yamato" }
    status { "in_transit" }
    status_code { "IT" }
    status_description { "配送中" }
    tracking_date { Time.current }
    location { "東京配送センター" }
    city { "東京" }
    state { "東京都" }
    postal_code { "100-0001" }
    country { "日本" }
    latitude { 35.6812362 }
    longitude { 139.7649361 }
    is_exception { false }
    exception_details { nil }
    estimated_delivery_date { 3.days.from_now.to_s }
    raw_tracking_data { { "carrier_status": "in_transit", "location_details": { "facility": "東京配送センター" } } }
    tracking_url { "https://example.com/track?number=#{tracking_number}" }
    is_delivered { false }
    delivered_at { nil }
    received_by { nil }
    signature_required { false }
    signature_image_url { nil }
    proof_of_delivery_url { nil }
    notes { nil }

    trait :pending do
      status { "pending" }
      status_code { "PD" }
      status_description { "出荷準備中" }
      location { "出荷元倉庫" }
    end

    trait :shipped do
      status { "shipped" }
      status_code { "SH" }
      status_description { "出荷完了" }
      location { "出荷元倉庫" }
    end

    trait :in_transit do
      status { "in_transit" }
      status_code { "IT" }
      status_description { "配送中" }
      location { "東京配送センター" }
    end

    trait :out_for_delivery do
      status { "out_for_delivery" }
      status_code { "OD" }
      status_description { "配達中" }
      location { "渋谷配送センター" }
    end

    trait :delivered do
      status { "delivered" }
      status_code { "DL" }
      status_description { "配達完了" }
      location { "配達先住所" }
      is_delivered { true }
      delivered_at { Time.current }
      received_by { "山田花子" }
    end

    trait :failed do
      status { "failed" }
      status_code { "FL" }
      status_description { "配達失敗" }
      location { "配達先住所" }
      is_exception { true }
      exception_details { "不在のため配達できませんでした" }
    end

    trait :returned do
      status { "returned" }
      status_code { "RT" }
      status_description { "返送中" }
      location { "渋谷配送センター" }
    end

    trait :exception do
      is_exception { true }
      exception_details { "配達に問題が発生しました" }
    end

    trait :with_signature do
      signature_required { true }
      signature_image_url { "https://example.com/signatures/sig123.png" }
      proof_of_delivery_url { "https://example.com/pod/pod123.pdf" }
    end

    trait :yamato do
      carrier { "yamato" }
    end

    trait :sagawa do
      carrier { "sagawa" }
    end

    trait :japan_post do
      carrier { "japan_post" }
    end

    trait :fedex do
      carrier { "fedex" }
    end

    trait :dhl do
      carrier { "dhl" }
    end

    trait :amazon_logistics do
      carrier { "amazon_logistics" }
    end

    trait :international do
      location { "JFK International Airport" }
      city { "New York" }
      state { "NY" }
      postal_code { "11430" }
      country { "USA" }
      raw_tracking_data { { "carrier_status": "in_transit", "location_details": { "facility": "JFK International Airport", "country": "USA" } } }
    end

    trait :with_notes do
      notes { "特別な配送状況の備考" }
    end

    trait :old_tracking do
      tracking_date { 1.week.ago }
    end

    trait :recent_tracking do
      tracking_date { 1.hour.ago }
    end
  end
end
