FactoryBot.define do
  factory :user_subscription do
    association :user
    subscription_type { %w[prime music video kindle unlimited business].sample }
    status { 'active' }
    start_date { Faker::Time.backward(days: 90) }
    end_date { Faker::Time.forward(days: 90) }
    amount { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    billing_period { %w[monthly quarterly biannual annual].sample }
    payment_method_id { SecureRandom.uuid }
    last_payment_date { Faker::Time.backward(days: 30) }
    next_payment_date { Faker::Time.forward(days: 30) }
    auto_renew { true }

    trait :active do
      status { 'active' }
    end

    trait :paused do
      status { 'paused' }
    end

    trait :cancelled do
      status { 'cancelled' }
      auto_renew { false }
    end

    trait :expired do
      status { 'expired' }
      end_date { Faker::Time.backward(days: 10) }
      auto_renew { false }
    end

    trait :trial do
      status { 'trial' }
      amount { 0 }
      end_date { Faker::Time.forward(days: 14) }
    end

    trait :monthly do
      billing_period { 'monthly' }
      amount { 9.99 }
    end

    trait :annual do
      billing_period { 'annual' }
      amount { 99.99 }
    end

    trait :prime do
      subscription_type { 'prime' }
      amount { 12.99 }
    end

    trait :music do
      subscription_type { 'music' }
      amount { 9.99 }
    end

    trait :video do
      subscription_type { 'video' }
      amount { 8.99 }
    end

    factory :prime_subscription do
      prime
    end

    factory :trial_subscription do
      trial
    end

    factory :cancelled_subscription do
      cancelled
    end
  end
end
