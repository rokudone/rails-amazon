FactoryBot.define do
  factory :order do
    association :user
    association :order_status, factory: [:order_status, :pending]
    association :billing_address, factory: :address
    association :shipping_address, factory: :address

    sequence(:order_number) { |n| "ORD-#{Date.today.strftime('%Y%m%d')}-#{n.to_s.rjust(4, '0')}" }
    order_date { Time.current }
    subtotal { 10000 }
    tax_total { 1000 }
    shipping_total { 500 }
    discount_total { 0 }
    grand_total { 11500 }
    currency { "JPY" }
    exchange_rate { 1.0 }
    payment_status { "pending" }
    fulfillment_status { "pending" }
    is_gift { false }
    gift_message { nil }
    coupon_code { nil }
    tracking_number { nil }
    shipping_method { "standard" }
    estimated_delivery_date { 1.week.from_now }
    actual_delivery_date { nil }
    customer_notes { nil }
    admin_notes { nil }
    source { "website" }
    ip_address { "192.168.1.1" }
    user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36" }
    is_prime { false }
    requires_signature { false }
    cancelled_at { nil }
    cancellation_reason { nil }
    locale { "ja" }

    trait :with_items do
      transient do
        items_count { 3 }
      end

      after(:create) do |order, evaluator|
        create_list(:order_item, evaluator.items_count, order: order)
        order.update(
          subtotal: order.order_items.sum(&:subtotal),
          grand_total: order.order_items.sum(&:subtotal) + order.tax_total + order.shipping_total - order.discount_total
        )
      end
    end

    trait :with_single_item do
      after(:create) do |order|
        create(:order_item, order: order)
        order.update(
          subtotal: order.order_items.sum(&:subtotal),
          grand_total: order.order_items.sum(&:subtotal) + order.tax_total + order.shipping_total - order.discount_total
        )
      end
    end

    trait :with_payment do
      after(:create) do |order|
        create(:payment, order: order, user: order.user, amount: order.grand_total, status: 'completed')
        order.update(payment_status: 'paid')
      end
    end

    trait :with_shipment do
      after(:create) do |order|
        create(:shipment, order: order)
      end
    end

    trait :pending do
      association :order_status, factory: [:order_status, :pending]
      payment_status { "pending" }
      fulfillment_status { "pending" }
    end

    trait :processing do
      association :order_status, factory: [:order_status, :processing]
      payment_status { "paid" }
      fulfillment_status { "processing" }
    end

    trait :shipped do
      association :order_status, factory: [:order_status, :shipped]
      payment_status { "paid" }
      fulfillment_status { "shipped" }
      tracking_number { "TRK123456789" }
    end

    trait :delivered do
      association :order_status, factory: [:order_status, :delivered]
      payment_status { "paid" }
      fulfillment_status { "delivered" }
      tracking_number { "TRK123456789" }
      actual_delivery_date { Date.today }
    end

    trait :completed do
      association :order_status, factory: [:order_status, :completed]
      payment_status { "paid" }
      fulfillment_status { "delivered" }
      tracking_number { "TRK123456789" }
      actual_delivery_date { 1.week.ago }
    end

    trait :cancelled do
      association :order_status, factory: [:order_status, :cancelled]
      payment_status { "refunded" }
      fulfillment_status { "cancelled" }
      cancelled_at { 1.day.ago }
      cancellation_reason { "顧客によるキャンセル" }
    end

    trait :returned do
      association :order_status, factory: [:order_status, :returned]
      payment_status { "refunded" }
      fulfillment_status { "delivered" }
      tracking_number { "TRK123456789" }
      actual_delivery_date { 2.weeks.ago }

      after(:create) do |order|
        create(:return, order: order, user: order.user)
      end
    end

    trait :with_discount do
      discount_total { 1000 }
      grand_total { 10500 }
      coupon_code { "DISCOUNT10" }

      after(:create) do |order|
        create(:order_discount, order: order, discount_code: "DISCOUNT10", discount_value: 10, calculation_type: "percentage", applied_amount: 1000)
      end
    end

    trait :gift do
      is_gift { true }
      gift_message { "お誕生日おめでとう！素敵な一日になりますように。" }

      after(:create) do |order|
        create(:gift_wrap, order: order)
      end
    end

    trait :prime do
      is_prime { true }
      shipping_method { "express" }
      shipping_total { 0 }
    end

    trait :international do
      shipping_method { "international" }
      shipping_total { 2000 }
      currency { "USD" }
      exchange_rate { 0.0091 }

      after(:create) do |order|
        address = create(:address, :international)
        order.update(shipping_address: address)
      end
    end

    trait :with_notes do
      customer_notes { "配達時に電話してください。" }
      admin_notes { "VIP顧客、特別対応が必要。" }
    end

    trait :mobile_app do
      source { "mobile_app" }
      user_agent { "Amazon/1.0 (iPhone; iOS 14.5; Scale/3.00)" }
    end
  end
end
