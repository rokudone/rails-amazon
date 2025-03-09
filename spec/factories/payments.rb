FactoryBot.define do
  factory :payment do
    association :order
    association :user
    association :payment_method, optional: true

    payment_provider { "credit_card" }
    payment_type { "full" }
    sequence(:transaction_id) { |n| "TXN#{n.to_s.rjust(10, '0')}" }
    sequence(:authorization_code) { |n| "AUTH#{n.to_s.rjust(8, '0')}" }
    amount { 10000 }
    currency { "JPY" }
    status { "pending" }
    payment_date { nil }
    error_message { nil }
    card_type { "Visa" }
    last_four_digits { "4242" }
    cardholder_name { "山田太郎" }
    expiry_month { 12 }
    expiry_year { Date.today.year + 2 }
    billing_address_line1 { "東京都渋谷区神宮前1-1-1" }
    billing_address_line2 { "渋谷ビル101" }
    billing_city { "渋谷区" }
    billing_state { "東京都" }
    billing_postal_code { "150-0001" }
    billing_country { "日本" }
    billing_phone { "03-1234-5678" }
    billing_email { "customer@example.com" }
    is_default { false }
    save_payment_method { false }
    customer_ip { "192.168.1.1" }
    user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36" }
    metadata { {} }
    notes { nil }

    trait :pending do
      status { "pending" }
    end

    trait :processing do
      status { "processing" }
    end

    trait :completed do
      status { "completed" }
      payment_date { Time.current }
    end

    trait :failed do
      status { "failed" }
      error_message { "カード決済が拒否されました。" }
    end

    trait :refunded do
      status { "refunded" }
      payment_date { 1.day.ago }

      after(:create) do |payment|
        create(:payment_transaction,
          payment: payment,
          order: payment.order,
          transaction_type: 'refund',
          amount: payment.amount,
          status: 'success'
        )
      end
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :credit_card do
      payment_provider { "credit_card" }
      card_type { "Visa" }
      last_four_digits { "4242" }
    end

    trait :mastercard do
      payment_provider { "credit_card" }
      card_type { "Mastercard" }
      last_four_digits { "5555" }
    end

    trait :amex do
      payment_provider { "credit_card" }
      card_type { "American Express" }
      last_four_digits { "0005" }
    end

    trait :paypal do
      payment_provider { "paypal" }
      card_type { nil }
      last_four_digits { nil }
      billing_email { "customer@example.com" }
    end

    trait :amazon_pay do
      payment_provider { "amazon_pay" }
      card_type { nil }
      last_four_digits { nil }
    end

    trait :bank_transfer do
      payment_provider { "bank_transfer" }
      card_type { nil }
      last_four_digits { nil }
      notes { "三井住友銀行 渋谷支店 普通 1234567" }
    end

    trait :partial do
      payment_type { "partial" }
      amount { 5000 }
    end

    trait :installment do
      payment_type { "installment" }
      notes { "3回払い" }
    end

    trait :refund do
      payment_type { "refund" }
      notes { "返品による返金" }
    end

    trait :international do
      currency { "USD" }
      billing_address_line1 { "123 Main St" }
      billing_city { "New York" }
      billing_state { "NY" }
      billing_postal_code { "10001" }
      billing_country { "USA" }
      billing_phone { "+1-555-123-4567" }
    end

    trait :with_metadata do
      metadata { { "source": "web", "promotion_code": "SUMMER2025", "customer_type": "returning" } }
    end

    trait :with_notes do
      notes { "特別な処理が必要な支払い" }
    end

    trait :saved_payment_method do
      is_default { true }
      save_payment_method { true }
    end
  end
end
