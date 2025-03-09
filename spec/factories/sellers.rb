FactoryBot.define do
  factory :seller do
    user
    sequence(:company_name) { |n| "Seller Company #{n}" }
    sequence(:legal_name) { |n| "Seller Legal Name #{n} LLC" }
    sequence(:tax_identifier) { |n| "TX#{n}#{SecureRandom.hex(6).upcase}" }
    business_type { ['individual', 'corporation', 'partnership', 'llc'].sample }
    description { Faker::Company.catch_phrase }
    logo_url { Faker::Internet.url(host: 'example.com', path: "/logos/#{SecureRandom.hex(8)}.png") }
    website_url { Faker::Internet.url }
    sequence(:contact_email) { |n| "seller#{n}@example.com" }
    contact_phone { Faker::PhoneNumber.phone_number }
    status { 'pending' }
    is_featured { false }
    is_verified { false }
    products_count { 0 }
    average_rating { nil }
    ratings_count { 0 }
    last_active_at { Time.current }
    store_url { nil }
    accepts_returns { true }
    return_period_days { 30 }

    trait :approved do
      status { 'approved' }
      approved_at { Time.current }
      association :approved_by, factory: :user
    end

    trait :suspended do
      status { 'suspended' }
    end

    trait :rejected do
      status { 'rejected' }
    end

    trait :verified do
      is_verified { true }
      verified_at { Time.current }
    end

    trait :featured do
      is_featured { true }
    end

    trait :with_ratings do
      transient do
        ratings_count { 5 }
        average_score { rand(3.0..5.0).round(1) }
      end

      after(:create) do |seller, evaluator|
        ratings = create_list(:seller_rating, evaluator.ratings_count, seller: seller, is_approved: true)
        seller.update(
          ratings_count: ratings.size,
          average_rating: evaluator.average_score
        )
      end
    end

    trait :with_products do
      transient do
        products_count { 5 }
      end

      after(:create) do |seller, evaluator|
        products = create_list(:product, evaluator.products_count, seller: seller)
        seller.update(products_count: products.size)
      end
    end

    trait :with_documents do
      transient do
        documents_count { 3 }
      end

      after(:create) do |seller, evaluator|
        create_list(:seller_document, evaluator.documents_count, seller: seller)
      end
    end

    trait :with_transactions do
      transient do
        transactions_count { 5 }
      end

      after(:create) do |seller, evaluator|
        create_list(:seller_transaction, evaluator.transactions_count, seller: seller)
      end
    end

    trait :with_policies do
      after(:create) do |seller|
        create(:seller_policy, seller: seller, policy_type: 'return')
        create(:seller_policy, seller: seller, policy_type: 'shipping')
        create(:seller_policy, seller: seller, policy_type: 'privacy')
      end
    end

    trait :with_performance do
      after(:create) do |seller|
        create(:seller_performance, seller: seller)
      end
    end

    factory :approved_seller do
      status { 'approved' }
      approved_at { Time.current }
      association :approved_by, factory: :user
    end

    factory :complete_seller do
      status { 'approved' }
      approved_at { Time.current }
      association :approved_by, factory: :user
      is_verified { true }
      verified_at { Time.current }

      after(:create) do |seller|
        create_list(:seller_rating, 10, seller: seller, is_approved: true)
        create_list(:product, 5, seller: seller)
        create_list(:seller_document, 3, seller: seller, is_verified: true)
        create_list(:seller_transaction, 5, seller: seller, status: 'completed')
        create(:seller_policy, seller: seller, policy_type: 'return', is_approved: true)
        create(:seller_policy, seller: seller, policy_type: 'shipping', is_approved: true)
        create(:seller_policy, seller: seller, policy_type: 'privacy', is_approved: true)
        create(:seller_performance, seller: seller)

        seller.update(
          ratings_count: 10,
          average_rating: rand(3.5..5.0).round(1),
          products_count: 5,
          store_url: "/sellers/#{seller.company_name.parameterize}-#{seller.id}"
        )
      end
    end
  end

  factory :seller_rating do
    user
    seller
    association :order
    rating { rand(1..5) }
    comment { Faker::Lorem.paragraph }
    dimension { ['shipping_speed', 'product_quality', 'customer_service', 'overall'].sample }
    is_verified_purchase { [true, false].sample }
    is_anonymous { [true, false].sample }
    is_approved { false }

    trait :approved do
      is_approved { true }
      approved_at { Time.current }
    end

    trait :featured do
      is_featured { true }
    end

    trait :with_votes do
      helpful_votes_count { rand(1..20) }
      unhelpful_votes_count { rand(0..5) }
    end

    factory :approved_seller_rating do
      is_approved { true }
      approved_at { Time.current }
    end
  end

  factory :seller_product do
    seller
    product
    price { Faker::Commerce.price(range: 10..1000.0) }
    quantity { rand(0..100) }
    is_active { true }
    condition { ['new', 'used', 'refurbished', 'open_box'].sample }
    condition_description { condition == 'new' ? nil : Faker::Lorem.sentence }
    sequence(:sku) { |n| "SP-#{n}-#{SecureRandom.hex(4).upcase}" }
    shipping_cost { [0, rand(300..1000)].sample }
    handling_days { rand(1..5) }
    is_featured { false }
    is_prime_eligible { [true, false].sample }
    is_fulfilled_by_amazon { [true, false].sample }
    seller_cost { price * rand(0.5..0.8) }
    profit_margin { ((price - seller_cost) / price * 100).round(2) }
    sales_count { rand(0..100) }
    last_sold_at { [nil, Time.current - rand(1..30).days].sample }

    trait :out_of_stock do
      quantity { 0 }
    end

    trait :featured do
      is_featured { true }
    end

    trait :prime do
      is_prime_eligible { true }
    end

    trait :fba do
      is_fulfilled_by_amazon { true }
    end

    trait :used do
      condition { 'used' }
      condition_description { Faker::Lorem.sentence }
    end

    trait :refurbished do
      condition { 'refurbished' }
      condition_description { Faker::Lorem.sentence }
    end
  end

  factory :seller_document do
    seller
    document_type { ['business_license', 'tax_certificate', 'identity_proof', 'bank_statement', 'address_proof'].sample }
    file_url { Faker::Internet.url(host: 'example.com', path: "/documents/#{SecureRandom.hex(8)}.pdf") }
    file_name { "#{document_type}_#{SecureRandom.hex(4)}.pdf" }
    content_type { 'application/pdf' }
    file_size { rand(100_000..5_000_000) }
    expiry_date { [nil, Date.current + rand(1..365).days].sample }
    is_verified { false }
    status { 'pending' }
    is_required { true }

    trait :verified do
      is_verified { true }
      verified_at { Time.current }
      association :verified_by, factory: :user
      status { 'approved' }
    end

    trait :rejected do
      is_verified { false }
      status { 'rejected' }
      verification_notes { Faker::Lorem.sentence }
    end

    trait :expired do
      expiry_date { Date.current - rand(1..30).days }
    end

    trait :optional do
      is_required { false }
    end

    factory :verified_seller_document do
      is_verified { true }
      verified_at { Time.current }
      association :verified_by, factory: :user
      status { 'approved' }
    end
  end

  factory :seller_transaction do
    seller
    association :order
    transaction_type { ['sale', 'refund', 'fee', 'payout', 'adjustment'].sample }
    amount { rand(100..10000) }
    fee_amount { transaction_type == 'fee' ? amount : (amount * 0.15).round(2) }
    tax_amount { (amount * 0.1).round(2) }
    net_amount { amount - fee_amount - tax_amount }
    currency { 'JPY' }
    status { ['pending', 'completed', 'failed', 'cancelled'].sample }
    payment_method { ['credit_card', 'bank_transfer', 'amazon_pay'].sample }
    sequence(:reference_number) { |n| "TX#{Time.current.strftime('%Y%m%d')}-#{n}#{SecureRandom.hex(4).upcase}" }
    description { Faker::Lorem.sentence }

    trait :sale do
      transaction_type { 'sale' }
      amount { rand(1000..10000) }
    end

    trait :refund do
      transaction_type { 'refund' }
      amount { rand(1000..10000) * -1 }
    end

    trait :fee do
      transaction_type { 'fee' }
      amount { rand(100..1000) * -1 }
      fee_amount { 0 }
      net_amount { amount - tax_amount }
    end

    trait :payout do
      transaction_type { 'payout' }
      amount { rand(10000..50000) * -1 }
      fee_amount { rand(100..500) }
      net_amount { amount - fee_amount - tax_amount }
    end

    trait :completed do
      status { 'completed' }
      processed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :cancelled do
      status { 'cancelled' }
    end

    factory :completed_sale_transaction do
      transaction_type { 'sale' }
      amount { rand(1000..10000) }
      status { 'completed' }
      processed_at { Time.current }
    end
  end

  factory :seller_policy do
    seller
    policy_type { ['return', 'shipping', 'privacy', 'terms', 'warranty', 'payment'].sample }
    content { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
    is_active { true }
    effective_date { Date.current }
    is_approved { false }
    version { '1.0' }

    trait :approved do
      is_approved { true }
      approved_at { Time.current }
      association :approved_by, factory: :user
    end

    trait :inactive do
      is_active { false }
    end

    trait :return_policy do
      policy_type { 'return' }
      content { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    end

    trait :shipping_policy do
      policy_type { 'shipping' }
      content { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    end

    trait :privacy_policy do
      policy_type { 'privacy' }
      content { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
    end

    trait :terms_policy do
      policy_type { 'terms' }
      content { Faker::Lorem.paragraphs(number: 7).join("\n\n") }
    end

    factory :approved_seller_policy do
      is_approved { true }
      approved_at { Time.current }
      association :approved_by, factory: :user
    end
  end

  factory :seller_performance do
    seller
    period_start { Time.current.beginning_of_month }
    period_end { Time.current.end_of_month }
    orders_count { rand(10..100) }
    cancelled_orders_count { rand(0..5) }
    cancellation_rate { (cancelled_orders_count.to_f / orders_count * 100).round(2) }
    late_shipments_count { rand(0..10) }
    late_shipment_rate { (late_shipments_count.to_f / orders_count * 100).round(2) }
    returns_count { rand(0..10) }
    return_rate { (returns_count.to_f / orders_count * 100).round(2) }
    average_rating { rand(3.0..5.0).round(2) }
    ratings_count { rand(5..50) }
    negative_feedback_count { rand(0..5) }
    negative_feedback_rate { (negative_feedback_count.to_f / ratings_count * 100).round(2) }
    total_sales { rand(100000..1000000) }
    total_fees { (total_sales * 0.15).round(2) }
    total_profit { total_sales - total_fees }
    performance_status { ['excellent', 'good', 'fair', 'poor', 'at_risk'].sample }
    improvement_suggestions { performance_status == 'excellent' ? nil : Faker::Lorem.sentences(number: 3).join("\n") }
    is_eligible_for_featured { ['excellent', 'good'].include?(performance_status) }
    is_eligible_for_prime { ['excellent', 'good', 'fair'].include?(performance_status) }

    trait :excellent do
      performance_status { 'excellent' }
      cancellation_rate { rand(0.0..1.0).round(2) }
      late_shipment_rate { rand(0.0..2.0).round(2) }
      return_rate { rand(0.0..3.0).round(2) }
      average_rating { rand(4.5..5.0).round(2) }
      negative_feedback_rate { rand(0.0..2.0).round(2) }
      is_eligible_for_featured { true }
      is_eligible_for_prime { true }
      improvement_suggestions { nil }
    end

    trait :good do
      performance_status { 'good' }
      cancellation_rate { rand(1.1..3.0).round(2) }
      late_shipment_rate { rand(2.1..5.0).round(2) }
      return_rate { rand(3.1..5.0).round(2) }
      average_rating { rand(4.0..4.4).round(2) }
      negative_feedback_rate { rand(2.1..5.0).round(2) }
      is_eligible_for_featured { true }
      is_eligible_for_prime { true }
      improvement_suggestions { Faker::Lorem.sentence }
    end

    trait :fair do
      performance_status { 'fair' }
      cancellation_rate { rand(3.1..5.0).round(2) }
      late_shipment_rate { rand(5.1..10.0).round(2) }
      return_rate { rand(5.1..10.0).round(2) }
      average_rating { rand(3.5..3.9).round(2) }
      negative_feedback_rate { rand(5.1..10.0).round(2) }
      is_eligible_for_featured { false }
      is_eligible_for_prime { true }
      improvement_suggestions { Faker::Lorem.sentences(number: 2).join("\n") }
    end

    trait :poor do
      performance_status { 'poor' }
      cancellation_rate { rand(5.1..10.0).round(2) }
      late_shipment_rate { rand(10.1..15.0).round(2) }
      return_rate { rand(10.1..15.0).round(2) }
      average_rating { rand(3.0..3.4).round(2) }
      negative_feedback_rate { rand(10.1..15.0).round(2) }
      is_eligible_for_featured { false }
      is_eligible_for_prime { false }
      improvement_suggestions { Faker::Lorem.sentences(number: 3).join("\n") }
    end

    trait :at_risk do
      performance_status { 'at_risk' }
      cancellation_rate { rand(10.1..20.0).round(2) }
      late_shipment_rate { rand(15.1..25.0).round(2) }
      return_rate { rand(15.1..25.0).round(2) }
      average_rating { rand(1.0..2.9).round(2) }
      negative_feedback_rate { rand(15.1..30.0).round(2) }
      is_eligible_for_featured { false }
      is_eligible_for_prime { false }
      improvement_suggestions { Faker::Lorem.sentences(number: 5).join("\n") }
    end
  end
end
