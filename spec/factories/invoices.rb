FactoryBot.define do
  factory :invoice do
    association :order
    association :user

    sequence(:invoice_number) { |n| "INV#{n.to_s.rjust(8, '0')}" }
    invoice_date { Date.today }
    due_date { 30.days.from_now.to_date }
    status { "pending" }
    subtotal { 10000 }
    tax_total { 1000 }
    shipping_total { 500 }
    discount_total { 0 }
    grand_total { 11500 }
    amount_paid { 0 }
    amount_due { 11500 }
    currency { "JPY" }
    payment_terms { "due_on_receipt" }
    notes { nil }
    billing_name { "山田太郎" }
    billing_company { nil }
    billing_address_line1 { "東京都渋谷区神宮前1-1-1" }
    billing_address_line2 { "渋谷ビル101" }
    billing_city { "渋谷区" }
    billing_state { "東京都" }
    billing_postal_code { "150-0001" }
    billing_country { "日本" }
    billing_phone { "03-1234-5678" }
    billing_email { "taro@example.com" }
    shipping_name { "山田花子" }
    shipping_company { nil }
    shipping_address_line1 { "東京都渋谷区神宮前1-1-1" }
    shipping_address_line2 { "渋谷ビル101" }
    shipping_city { "渋谷区" }
    shipping_state { "東京都" }
    shipping_postal_code { "150-0001" }
    shipping_country { "日本" }
    tax_id { nil }
    tax_exemption_number { nil }
    invoice_pdf_url { "https://example.com/invoices/inv123.pdf" }
    sent_at { nil }
    viewed_at { nil }
    view_count { 0 }
    created_by { "system" }
    metadata { {} }

    trait :pending do
      status { "pending" }
    end

    trait :paid do
      status { "paid" }
      amount_paid { 11500 }
      amount_due { 0 }
    end

    trait :partially_paid do
      status { "partially_paid" }
      amount_paid { 5000 }
      amount_due { 6500 }
    end

    trait :overdue do
      status { "overdue" }
      due_date { 10.days.ago.to_date }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :refunded do
      status { "refunded" }
      amount_paid { 0 }
      amount_due { 0 }
    end

    trait :sent do
      sent_at { 1.day.ago }
    end

    trait :viewed do
      sent_at { 2.days.ago }
      viewed_at { 1.day.ago }
      view_count { 3 }
    end

    trait :due_on_receipt do
      payment_terms { "due_on_receipt" }
    end

    trait :net_15 do
      payment_terms { "net_15" }
      due_date { 15.days.from_now.to_date }
    end

    trait :net_30 do
      payment_terms { "net_30" }
      due_date { 30.days.from_now.to_date }
    end

    trait :net_60 do
      payment_terms { "net_60" }
      due_date { 60.days.from_now.to_date }
    end

    trait :with_tax_id do
      tax_id { "T1234567890" }
    end

    trait :tax_exempt do
      tax_id { "T1234567890" }
      tax_exemption_number { "E12345" }
      tax_total { 0 }
      grand_total { 10500 }
    end

    trait :with_company do
      billing_company { "株式会社サンプル" }
      shipping_company { "株式会社サンプル" }
    end

    trait :with_notes do
      notes { "請求書に関する特記事項" }
    end

    trait :international do
      currency { "USD" }
      billing_address_line1 { "123 Main St" }
      billing_city { "New York" }
      billing_state { "NY" }
      billing_postal_code { "10001" }
      billing_country { "USA" }
      billing_phone { "+1-555-123-4567" }

      shipping_address_line1 { "123 Main St" }
      shipping_city { "New York" }
      shipping_state { "NY" }
      shipping_postal_code { "10001" }
      shipping_country { "USA" }
    end

    trait :with_discount do
      discount_total { 1000 }
      grand_total { 10500 }
    end

    trait :high_value do
      subtotal { 100000 }
      tax_total { 10000 }
      grand_total { 110500 }
      amount_due { 110500 }
    end
  end
end
