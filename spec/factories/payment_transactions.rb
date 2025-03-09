FactoryBot.define do
  factory :payment_transaction do
    association :payment
    association :order, optional: true

    transaction_type { "sale" }
    sequence(:transaction_id) { |n| "TXN#{n.to_s.rjust(10, '0')}" }
    sequence(:reference_id) { |n| "REF#{n.to_s.rjust(8, '0')}" }
    gateway_response_code { "00" }
    gateway_response_message { "承認されました" }
    gateway_response_data { { "processor_response": "APPROVED", "avs_result": "Y", "cvv_result": "M" } }
    amount { 10000 }
    currency { "JPY" }
    status { "success" }
    transaction_date { Time.current }
    payment_provider { "credit_card" }
    payment_method_details { "Visa" }
    error_code { nil }
    error_description { nil }
    is_test_transaction { false }
    processor_id { "processor_123" }
    authorization_code { "AUTH12345" }
    response_time_ms { 350 }
    ip_address { "192.168.1.1" }
    user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36" }
    notes { nil }
    created_by { "system" }
    metadata { {} }

    trait :authorization do
      transaction_type { "authorization" }
    end

    trait :capture do
      transaction_type { "capture" }
    end

    trait :sale do
      transaction_type { "sale" }
    end

    trait :refund do
      transaction_type { "refund" }
    end

    trait :void do
      transaction_type { "void" }
    end

    trait :pending do
      status { "pending" }
    end

    trait :success do
      status { "success" }
    end

    trait :failed do
      status { "failed" }
      gateway_response_code { "05" }
      gateway_response_message { "カード拒否" }
      error_code { "card_declined" }
      error_description { "カードが拒否されました。別のカードをお試しください。" }
    end

    trait :processing do
      status { "processing" }
    end

    trait :credit_card do
      payment_provider { "credit_card" }
      payment_method_details { "Visa" }
    end

    trait :paypal do
      payment_provider { "paypal" }
      payment_method_details { "PayPal Account" }
    end

    trait :amazon_pay do
      payment_provider { "amazon_pay" }
      payment_method_details { "Amazon Pay" }
    end

    trait :bank_transfer do
      payment_provider { "bank_transfer" }
      payment_method_details { "Bank Transfer" }
    end

    trait :test_transaction do
      is_test_transaction { true }
    end

    trait :with_error do
      status { "failed" }
      gateway_response_code { "E01" }
      gateway_response_message { "エラーが発生しました" }
      error_code { "processing_error" }
      error_description { "決済処理中にエラーが発生しました。" }
    end

    trait :network_error do
      status { "failed" }
      gateway_response_code { "E02" }
      gateway_response_message { "ネットワークエラー" }
      error_code { "network_error" }
      error_description { "決済ネットワークに接続できませんでした。" }
    end

    trait :fraud_check do
      status { "failed" }
      gateway_response_code { "F01" }
      gateway_response_message { "不正の疑いがあります" }
      error_code { "fraud_detected" }
      error_description { "不正の疑いがあるため、この取引は拒否されました。" }
    end

    trait :international do
      currency { "USD" }
    end

    trait :with_notes do
      notes { "特別な処理が必要なトランザクション" }
    end

    trait :with_metadata do
      metadata { { "source": "web", "retry_count": 0, "original_amount": 12000 } }
    end

    trait :fast_response do
      response_time_ms { 50 }
    end

    trait :slow_response do
      response_time_ms { 2500 }
    end
  end
end
