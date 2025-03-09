FactoryBot.define do
  factory :return do
    association :order
    association :user
    exchange_order { nil }

    sequence(:return_number) { |n| "RET#{n.to_s.rjust(8, '0')}" }
    status { "requested" }
    return_type { "refund" }
    return_reason { "damaged" }
    return_description { "商品が破損していました" }
    requested_at { Time.current }
    approved_at { nil }
    received_at { nil }
    completed_at { nil }
    return_method { "mail" }
    return_carrier { "yamato" }
    return_tracking_number { nil }
    return_label_url { nil }
    refund_amount { nil }
    refund_method { "original_payment" }
    refund_transaction_id { nil }
    refunded_at { nil }
    restocking_fee_applied { false }
    restocking_fee_amount { 0 }
    return_shipping_paid_by_customer { false }
    return_shipping_cost { 0 }
    exchange_order_number { nil }
    rma_number { nil }
    inspector_name { nil }
    inspection_notes { nil }
    condition_on_return { nil }
    is_warranty_claim { false }
    warranty_claim_number { nil }
    rejection_reason { nil }
    created_by { nil }
    approved_by { nil }
    metadata { {} }

    trait :requested do
      status { "requested" }
    end

    trait :approved do
      status { "approved" }
      approved_at { Time.current }
      approved_by { "admin" }
      return_label_url { "https://example.com/return_labels/label123.pdf" }
      rma_number { "RMA12345" }
    end

    trait :received do
      status { "received" }
      approved_at { 3.days.ago }
      approved_by { "admin" }
      received_at { Time.current }
      return_label_url { "https://example.com/return_labels/label123.pdf" }
      rma_number { "RMA12345" }
      return_tracking_number { "RTN123456789" }
    end

    trait :inspected do
      status { "inspected" }
      approved_at { 5.days.ago }
      approved_by { "admin" }
      received_at { 2.days.ago }
      return_label_url { "https://example.com/return_labels/label123.pdf" }
      rma_number { "RMA12345" }
      return_tracking_number { "RTN123456789" }
      inspector_name { "鈴木一郎" }
      inspection_notes { "商品は確かに破損しています" }
      condition_on_return { "damaged" }
    end

    trait :completed do
      status { "completed" }
      approved_at { 7.days.ago }
      approved_by { "admin" }
      received_at { 5.days.ago }
      completed_at { Time.current }
      return_label_url { "https://example.com/return_labels/label123.pdf" }
      rma_number { "RMA12345" }
      return_tracking_number { "RTN123456789" }
      inspector_name { "鈴木一郎" }
      inspection_notes { "商品は確かに破損しています" }
      condition_on_return { "damaged" }
      refund_amount { 10000 }
      refund_transaction_id { "REF123456789" }
      refunded_at { Time.current }
    end

    trait :rejected do
      status { "rejected" }
      rejection_reason { "商品に問題は見られません" }
    end

    trait :refund do
      return_type { "refund" }
    end

    trait :exchange do
      return_type { "exchange" }

      after(:create) do |return_record|
        exchange_order = create(:order, user: return_record.user)
        return_record.update(
          exchange_order: exchange_order,
          exchange_order_number: exchange_order.order_number
        )
      end
    end

    trait :store_credit do
      return_type { "store_credit" }
    end

    trait :warranty do
      return_type { "warranty" }
      is_warranty_claim { true }
      warranty_claim_number { "WC12345" }
    end

    trait :damaged do
      return_reason { "damaged" }
      return_description { "商品が破損していました" }
    end

    trait :defective do
      return_reason { "defective" }
      return_description { "商品が正常に動作しません" }
    end

    trait :wrong_item do
      return_reason { "wrong_item" }
      return_description { "注文した商品と異なる商品が届きました" }
    end

    trait :not_as_described do
      return_reason { "not_as_described" }
      return_description { "商品の説明と実際の商品が異なります" }
    end

    trait :no_longer_needed do
      return_reason { "no_longer_needed" }
      return_description { "商品が必要なくなりました" }
    end

    trait :with_restocking_fee do
      restocking_fee_applied { true }
      restocking_fee_amount { 1000 }
    end

    trait :customer_paid_shipping do
      return_shipping_paid_by_customer { true }
      return_shipping_cost { 800 }
    end

    trait :with_items do
      transient do
        items_count { 2 }
      end

      after(:create) do |return_record, evaluator|
        evaluator.items_count.times do
          order_item = create(:order_item, order: return_record.order)
          order_item.update(return_record: return_record, status: 'returned', return_reason: return_record.return_reason)
        end
      end
    end

    trait :with_tracking do
      return_tracking_number { "RTN123456789" }
      return_carrier { "yamato" }
    end
  end
end
