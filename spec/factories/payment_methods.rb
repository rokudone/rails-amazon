FactoryBot.define do
  factory :payment_method do
    association :user
    payment_type { %w[credit_card debit_card bank_account paypal other].sample }
    provider { ['Visa', 'MasterCard', 'American Express', 'PayPal', 'Bank Transfer'].sample }
    account_number { "****#{Faker::Number.number(digits: 4)}" }
    expiry_date { "#{format('%02d', rand(1..12))}/#{(Time.current.year + rand(1..5)).to_s[-2..-1]}" }
    name_on_card { Faker::Name.name }
    is_default { false }

    trait :default do
      is_default { true }
    end

    trait :credit_card do
      payment_type { 'credit_card' }
      provider { ['Visa', 'MasterCard', 'American Express'].sample }
    end

    trait :debit_card do
      payment_type { 'debit_card' }
      provider { ['Visa Debit', 'MasterCard Debit'].sample }
    end

    trait :bank_account do
      payment_type { 'bank_account' }
      provider { ['Bank Transfer', 'Direct Debit'].sample }
      expiry_date { nil }
    end

    trait :paypal do
      payment_type { 'paypal' }
      provider { 'PayPal' }
      account_number { nil }
      expiry_date { nil }
    end

    factory :default_payment_method do
      default
    end

    factory :credit_card_payment do
      credit_card
    end

    factory :paypal_payment do
      paypal
    end
  end
end
