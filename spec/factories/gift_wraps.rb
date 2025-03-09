FactoryBot.define do
  factory :gift_wrap do
    association :order
    order_item { nil }

    wrap_type { "standard" }
    wrap_color { "red" }
    wrap_pattern { nil }
    ribbon_type { "standard" }
    ribbon_color { "gold" }
    include_gift_box { false }
    include_gift_receipt { true }
    hide_prices { true }
    gift_message { "お誕生日おめでとう！素敵な一日になりますように。" }
    gift_from { "山田太郎" }
    gift_to { "山田花子" }
    wrap_cost { 500 }
    special_instructions { nil }
    is_gift_wrapped { false }
    wrapped_by { nil }
    wrapped_at { nil }
    gift_wrap_image_url { nil }
    options { nil }
    is_reusable_packaging { false }
    packaging_type { nil }
    notes { nil }

    trait :standard do
      wrap_type { "standard" }
      wrap_color { "red" }
      ribbon_type { "standard" }
      ribbon_color { "gold" }
      wrap_cost { 500 }
    end

    trait :premium do
      wrap_type { "premium" }
      wrap_color { "silver" }
      ribbon_type { "satin" }
      ribbon_color { "navy" }
      include_gift_box { true }
      wrap_cost { 800 }
    end

    trait :luxury do
      wrap_type { "luxury" }
      wrap_color { "gold" }
      wrap_pattern { "elegant" }
      ribbon_type { "velvet" }
      ribbon_color { "burgundy" }
      include_gift_box { true }
      wrap_cost { 1200 }
    end

    trait :eco_friendly do
      wrap_type { "eco_friendly" }
      wrap_color { "kraft" }
      ribbon_type { "jute" }
      ribbon_color { "natural" }
      is_reusable_packaging { true }
      packaging_type { "recyclable" }
      wrap_cost { 600 }
    end

    trait :seasonal do
      wrap_type { "seasonal" }
      wrap_color { "green" }
      wrap_pattern { "holiday" }
      ribbon_type { "grosgrain" }
      ribbon_color { "red" }
      wrap_cost { 700 }
    end

    trait :birthday do
      wrap_pattern { "birthday" }
      gift_message { "お誕生日おめでとう！素敵な一年になりますように。" }
    end

    trait :wedding do
      wrap_pattern { "wedding" }
      wrap_color { "white" }
      ribbon_color { "silver" }
      gift_message { "ご結婚おめでとうございます。末永くお幸せに。" }
    end

    trait :with_gift_box do
      include_gift_box { true }
    end

    trait :without_gift_receipt do
      include_gift_receipt { false }
    end

    trait :show_prices do
      hide_prices { false }
    end

    trait :wrapped do
      is_gift_wrapped { true }
      wrapped_by { "包装担当者" }
      wrapped_at { Time.current }
      gift_wrap_image_url { "https://example.com/gift_wraps/wrap123.jpg" }
    end

    trait :with_special_instructions do
      special_instructions { "リボンは大きめにしてください。" }
    end

    trait :with_options do
      options { {
        "add_card": true,
        "card_message": "おめでとう！",
        "add_confetti": true
      } }
    end

    trait :with_order_item do
      association :order_item
    end

    trait :reusable do
      is_reusable_packaging { true }
      packaging_type { "fabric_wrap" }
    end

    trait :with_notes do
      notes { "特別なラッピングが必要です。" }
    end
  end
end
