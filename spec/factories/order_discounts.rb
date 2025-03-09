FactoryBot.define do
  factory :order_discount do
    association :order

    discount_type { "coupon" }
    sequence(:discount_code) { |n| "COUPON#{n}" }
    description { "10%オフクーポン" }
    calculation_type { "percentage" }
    discount_value { 10.0 }
    maximum_discount_amount { nil }
    minimum_order_amount { nil }
    is_applied { true }
    applied_amount { 1000 }
    applied_at { Time.current }
    valid_from { 1.month.ago }
    valid_until { 1.month.from_now }
    is_combinable { true }
    usage_limit { nil }
    usage_count { 1 }
    created_by { "system" }
    notes { nil }
    conditions { nil }
    metadata { {} }

    trait :coupon do
      discount_type { "coupon" }
      discount_code { "SAVE10" }
      description { "10%オフクーポン" }
    end

    trait :promotion do
      discount_type { "promotion" }
      discount_code { "SUMMER2025" }
      description { "夏のプロモーション" }
    end

    trait :volume do
      discount_type { "volume" }
      description { "数量割引" }
      conditions { { "min_quantity": 5 } }
    end

    trait :loyalty do
      discount_type { "loyalty" }
      description { "ロイヤルティ会員割引" }
    end

    trait :seasonal do
      discount_type { "seasonal" }
      discount_code { "SPRING2025" }
      description { "春の特別割引" }
      valid_from { Date.new(2025, 3, 1) }
      valid_until { Date.new(2025, 5, 31) }
    end

    trait :employee do
      discount_type { "employee" }
      discount_code { "EMPLOYEE25" }
      description { "従業員割引" }
      discount_value { 25.0 }
    end

    trait :bundle do
      discount_type { "bundle" }
      description { "セット割引" }
      conditions { { "bundle_products": [1, 2, 3] } }
    end

    trait :percentage do
      calculation_type { "percentage" }
      discount_value { 10.0 }
      description { "10%オフ" }
    end

    trait :fixed_amount do
      calculation_type { "fixed_amount" }
      discount_value { 1000 }
      description { "1000円オフ" }
    end

    trait :free_shipping do
      calculation_type { "free_shipping" }
      discount_value { 0 }
      description { "送料無料" }
    end

    trait :buy_x_get_y do
      calculation_type { "buy_x_get_y" }
      discount_value { 1 }
      description { "1つ買うともう1つ無料" }
      conditions { { "buy_quantity": 1, "get_quantity": 1 } }
    end

    trait :inactive do
      is_applied { false }
    end

    trait :with_maximum do
      maximum_discount_amount { 5000 }
    end

    trait :with_minimum do
      minimum_order_amount { 5000 }
    end

    trait :non_combinable do
      is_combinable { false }
    end

    trait :with_usage_limit do
      usage_limit { 100 }
      usage_count { 50 }
    end

    trait :usage_limit_reached do
      usage_limit { 100 }
      usage_count { 100 }
    end

    trait :expired do
      valid_from { 2.months.ago }
      valid_until { 1.month.ago }
    end

    trait :future do
      valid_from { 1.month.from_now }
      valid_until { 2.months.from_now }
    end

    trait :high_value do
      calculation_type { "percentage" }
      discount_value { 50.0 }
      description { "50%オフ" }
    end

    trait :with_conditions do
      conditions { {
        "product_categories": [1, 2, 3],
        "customer_groups": ["premium", "vip"],
        "min_order_count": 3
      } }
    end

    trait :with_notes do
      notes { "特別なプロモーションコード" }
    end

    trait :with_metadata do
      metadata { {
        "campaign_id": "SUMMER2025",
        "source": "email",
        "created_by_user_id": 1
      } }
    end
  end
end
