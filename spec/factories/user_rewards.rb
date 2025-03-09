FactoryBot.define do
  factory :user_reward do
    association :user
    reward_type { %w[points coupon discount gift promotion cashback].sample }
    status { 'active' }
    points { reward_type == 'points' ? rand(100..10000) : nil }
    amount { ['coupon', 'discount', 'cashback'].include?(reward_type) ? Faker::Number.decimal(l_digits: 2, r_digits: 2) : nil }
    code { Faker::Alphanumeric.alphanumeric(number: 10).upcase }
    description { Faker::Marketing.buzzwords }
    issued_at { Faker::Time.backward(days: 30) }
    expires_at { Faker::Time.forward(days: 90) }
    redeemed_at { nil }
    redemption_details { nil }

    trait :active do
      status { 'active' }
    end

    trait :expired do
      status { 'expired' }
      expires_at { Faker::Time.backward(days: 10) }
    end

    trait :redeemed do
      status { 'redeemed' }
      redeemed_at { Faker::Time.backward(days: 15) }
      redemption_details { { order_id: SecureRandom.uuid, amount_used: Faker::Number.decimal(l_digits: 2, r_digits: 2) }.to_json }
    end

    trait :cancelled do
      status { 'cancelled' }
    end

    trait :points do
      reward_type { 'points' }
      points { rand(100..10000) }
      amount { nil }
    end

    trait :coupon do
      reward_type { 'coupon' }
      points { nil }
      amount { rand(5..50) }
      description { "#{amount}% off your next purchase" }
    end

    trait :discount do
      reward_type { 'discount' }
      points { nil }
      amount { rand(5..30) }
      description { "#{amount}% discount on selected items" }
    end

    trait :gift do
      reward_type { 'gift' }
      points { nil }
      amount { nil }
      description { "Free #{Faker::Commerce.product_name}" }
    end

    factory :points_reward do
      points
    end

    factory :coupon_reward do
      coupon
    end

    factory :redeemed_reward do
      redeemed
    end
  end
end
