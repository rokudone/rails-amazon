FactoryBot.define do
  factory :promotion do
    sequence(:name) { |n| "Promotion #{n}" }
    description { Faker::Lorem.paragraph }
    start_date { 1.day.ago }
    end_date { 30.days.from_now }
    is_active { true }
    promotion_type { ['percentage_discount', 'fixed_amount', 'buy_x_get_y', 'free_shipping'].sample }
    discount_amount { rand(5..50) }
    minimum_order_amount { [nil, rand(500..5000)].sample }
    usage_limit { [nil, rand(100..1000)].sample }
    usage_count { 0 }
    sequence(:code) { |n| "PROMO#{n}#{SecureRandom.hex(3).upcase}" }
    is_public { true }
    is_combinable { false }
    priority { rand(0..10) }
    association :created_by, factory: :user

    trait :expired do
      start_date { 60.days.ago }
      end_date { 30.days.ago }
    end

    trait :upcoming do
      start_date { 30.days.from_now }
      end_date { 60.days.from_now }
    end

    trait :inactive do
      is_active { false }
    end

    trait :percentage do
      promotion_type { 'percentage_discount' }
      discount_amount { rand(5..50) }
    end

    trait :fixed_amount do
      promotion_type { 'fixed_amount' }
      discount_amount { rand(500..5000) }
    end

    trait :with_rules do
      transient do
        rules_count { 2 }
      end

      after(:create) do |promotion, evaluator|
        create_list(:promotion_rule, evaluator.rules_count, promotion: promotion)
      end
    end

    factory :complete_promotion do
      after(:create) do |promotion|
        create_list(:promotion_rule, 2, promotion: promotion)
        create(:coupon, promotion: promotion)
      end
    end
  end

  factory :promotion_rule do
    promotion
    rule_type { ['product', 'category', 'customer', 'cart_quantity', 'cart_amount', 'time'].sample }
    operator { ['include', 'exclude', 'equal', 'greater_than', 'less_than'].sample }
    value { rule_type == 'cart_amount' ? rand(1000..10000).to_s : (rule_type == 'cart_quantity' ? rand(1..10).to_s : SecureRandom.hex(4)) }
    is_mandatory { [true, false].sample }
    position { rand(0..10) }

    trait :product_rule do
      rule_type { 'product' }
      operator { ['include', 'exclude'].sample }
      value { rand(1..100).to_s }
    end

    trait :category_rule do
      rule_type { 'category' }
      operator { ['include', 'exclude'].sample }
      value { rand(1..20).to_s }
    end

    trait :customer_rule do
      rule_type { 'customer' }
      operator { ['new_customer', 'returning_customer', 'prime_member'].sample }
    end

    trait :cart_quantity_rule do
      rule_type { 'cart_quantity' }
      operator { ['greater_than', 'equal', 'less_than'].sample }
      value { rand(1..10).to_s }
    end

    trait :cart_amount_rule do
      rule_type { 'cart_amount' }
      operator { ['greater_than', 'equal', 'less_than'].sample }
      value { rand(1000..10000).to_s }
    end
  end

  factory :coupon do
    sequence(:code) { |n| "COUPON#{n}#{SecureRandom.hex(3).upcase}" }
    sequence(:name) { |n| "Coupon #{n}" }
    description { Faker::Lorem.paragraph }
    start_date { 1.day.ago }
    end_date { 30.days.from_now }
    is_active { true }
    coupon_type { ['percentage', 'fixed_amount', 'free_shipping'].sample }
    discount_amount { rand(5..50) }
    minimum_order_amount { [nil, rand(500..5000)].sample }
    usage_limit_per_user { [nil, rand(1..5)].sample }
    usage_limit_total { [nil, rand(100..1000)].sample }
    usage_count { 0 }
    is_single_use { [true, false].sample }
    is_first_order_only { [true, false].sample }
    promotion
    association :created_by, factory: :user

    trait :expired do
      start_date { 60.days.ago }
      end_date { 30.days.ago }
    end

    trait :upcoming do
      start_date { 30.days.from_now }
      end_date { 60.days.from_now }
    end

    trait :inactive do
      is_active { false }
    end

    trait :percentage do
      coupon_type { 'percentage' }
      discount_amount { rand(5..50) }
    end

    trait :fixed_amount do
      coupon_type { 'fixed_amount' }
      discount_amount { rand(500..5000) }
    end

    trait :free_shipping do
      coupon_type { 'free_shipping' }
      discount_amount { nil }
    end

    trait :for_category do
      association :category
    end

    trait :for_product do
      association :product
    end
  end

  factory :discount do
    sequence(:name) { |n| "Discount #{n}" }
    description { Faker::Lorem.paragraph }
    start_date { 1.day.ago }
    end_date { 30.days.from_now }
    is_active { true }
    discount_type { ['percentage', 'fixed_amount', 'buy_one_get_one'].sample }
    discount_amount { rand(5..50) }
    minimum_purchase_amount { [nil, rand(500..5000)].sample }
    usage_limit { [nil, rand(100..1000)].sample }
    usage_count { 0 }
    association :created_by, factory: :user
    status { 'active' }

    trait :for_product do
      association :product
    end

    trait :for_category do
      association :category
    end

    trait :for_brand do
      association :brand
    end

    trait :expired do
      start_date { 60.days.ago }
      end_date { 30.days.ago }
      status { 'expired' }
    end

    trait :upcoming do
      start_date { 30.days.from_now }
      end_date { 60.days.from_now }
      status { 'scheduled' }
    end

    trait :inactive do
      is_active { false }
      status { 'cancelled' }
    end
  end

  factory :campaign do
    sequence(:name) { |n| "Campaign #{n}" }
    description { Faker::Lorem.paragraph }
    start_date { 1.day.ago }
    end_date { 30.days.from_now }
    is_active { true }
    campaign_type { ['seasonal', 'holiday', 'flash_sale', 'clearance'].sample }
    budget { rand(10000..100000) }
    spent_amount { rand(0..5000) }
    target_audience { ['all', 'prime_members', 'new_customers'].sample }
    status { 'active' }
    association :created_by, factory: :user
    sequence(:tracking_code) { |n| "CAM-#{SecureRandom.hex(4).upcase}-#{n}" }

    trait :with_promotion do
      association :promotion
    end

    trait :expired do
      start_date { 60.days.ago }
      end_date { 30.days.ago }
      status { 'completed' }
    end

    trait :upcoming do
      start_date { 30.days.from_now }
      end_date { 60.days.from_now }
      status { 'scheduled' }
    end

    trait :inactive do
      is_active { false }
      status { 'cancelled' }
    end

    trait :featured do
      is_featured { true }
    end

    trait :with_advertisements do
      transient do
        ads_count { 2 }
      end

      after(:create) do |campaign, evaluator|
        create_list(:advertisement, evaluator.ads_count, campaign: campaign)
      end
    end
  end

  factory :advertisement do
    sequence(:name) { |n| "Advertisement #{n}" }
    description { Faker::Lorem.paragraph }
    start_date { 1.day.ago }
    end_date { 30.days.from_now }
    is_active { true }
    ad_type { ['banner', 'sidebar', 'popup', 'sponsored_product'].sample }
    image_url { Faker::Internet.url(host: 'example.com', path: "/ads/#{SecureRandom.hex(8)}.jpg") }
    target_url { Faker::Internet.url }
    placement { ['home_page', 'product_page', 'search_results', 'category_page'].sample }
    budget { rand(1000..10000) }
    spent_amount { rand(0..500) }
    cost_per_click { (rand(10..100) / 100.0).round(2) }
    impressions_count { rand(1000..10000) }
    clicks_count { rand(10..1000) }
    status { 'active' }
    association :created_by, factory: :user

    trait :with_campaign do
      association :campaign
    end

    trait :for_product do
      association :product
    end

    trait :for_category do
      association :category
    end

    trait :for_seller do
      association :seller
    end

    trait :expired do
      start_date { 60.days.ago }
      end_date { 30.days.ago }
      status { 'completed' }
    end

    trait :upcoming do
      start_date { 30.days.from_now }
      end_date { 60.days.from_now }
      status { 'scheduled' }
    end

    trait :inactive do
      is_active { false }
      status { 'cancelled' }
    end

    trait :high_performing do
      impressions_count { rand(10000..50000) }
      clicks_count { rand(1000..5000) }
      click_through_rate { (clicks_count.to_f / impressions_count * 100).round(2) }
    end
  end

  factory :affiliate_program do
    sequence(:name) { |n| "Affiliate Program #{n}" }
    description { Faker::Lorem.paragraph }
    is_active { true }
    commission_rate { rand(1..20) }
    commission_type { ['percentage', 'fixed_amount'].sample }
    minimum_payout { rand(1000..5000) }
    payment_method { ['bank_transfer', 'paypal', 'amazon_gift_card'].sample }
    cookie_days { [7, 14, 30, 60, 90].sample }
    terms_and_conditions { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    association :created_by, factory: :user
    status { 'active' }

    trait :inactive do
      is_active { false }
      status { 'inactive' }
    end

    trait :pending do
      status { 'pending_approval' }
    end

    trait :percentage_commission do
      commission_type { 'percentage' }
      commission_rate { rand(1..20) }
    end

    trait :fixed_commission do
      commission_type { 'fixed_amount' }
      commission_rate { rand(100..500) }
    end
  end

  factory :referral_program do
    sequence(:name) { |n| "Referral Program #{n}" }
    description { Faker::Lorem.paragraph }
    is_active { true }
    start_date { 1.day.ago }
    end_date { 90.days.from_now }
    reward_type { ['discount', 'credit', 'gift_card'].sample }
    referrer_reward_amount { rand(500..2000) }
    referee_reward_amount { rand(500..2000) }
    usage_limit_per_user { rand(5..10) }
    usage_limit_total { rand(1000..5000) }
    usage_count { 0 }
    terms_and_conditions { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    association :created_by, factory: :user
    status { 'active' }
    referral_count { 0 }
    total_rewards_given { 0 }
    conversion_rate { 0 }
    sequence(:code_prefix) { |n| "REF#{n}" }

    trait :inactive do
      is_active { false }
      status { 'inactive' }
    end

    trait :expired do
      start_date { 120.days.ago }
      end_date { 30.days.ago }
    end

    trait :upcoming do
      start_date { 30.days.from_now }
      end_date { 120.days.from_now }
    end

    trait :discount_reward do
      reward_type { 'discount' }
      referrer_reward_amount { rand(5..25) }
      referee_reward_amount { rand(5..25) }
    end

    trait :credit_reward do
      reward_type { 'credit' }
      referrer_reward_amount { rand(500..2000) }
      referee_reward_amount { rand(500..2000) }
    end

    trait :gift_card_reward do
      reward_type { 'gift_card' }
      referrer_reward_amount { rand(1000..5000) }
      referee_reward_amount { rand(1000..5000) }
    end
  end
end
