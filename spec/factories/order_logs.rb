FactoryBot.define do
  factory :order_log do
    association :order
    user { nil }

    action { "created" }
    previous_status { nil }
    new_status { nil }
    message { "注文が作成されました" }
    data_changes { nil }
    ip_address { "192.168.1.1" }
    user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36" }
    source { "system" }
    reference_id { nil }
    reference_type { nil }
    notes { nil }
    is_customer_visible { false }
    is_notification_sent { false }
    notification_sent_at { nil }
    notification_type { nil }

    trait :created do
      action { "created" }
      message { "注文が作成されました" }
    end

    trait :updated do
      action { "updated" }
      message { "注文が更新されました" }
      data_changes { { "shipping_address": { "old": "旧住所", "new": "新住所" } } }
    end

    trait :status_changed do
      action { "status_changed" }
      previous_status { "pending" }
      new_status { "processing" }
      message { "注文ステータスが「保留中」から「処理中」に変更されました" }
    end

    trait :payment_received do
      action { "payment_received" }
      message { "支払いが完了しました" }
      reference_type { "payment" }
      reference_id { "1" }
    end

    trait :payment_failed do
      action { "payment_failed" }
      message { "支払いに失敗しました" }
      reference_type { "payment" }
      reference_id { "1" }
    end

    trait :payment_refunded do
      action { "payment_refunded" }
      message { "返金が処理されました" }
      reference_type { "payment" }
      reference_id { "1" }
    end

    trait :shipped do
      action { "shipped" }
      message { "注文が出荷されました" }
      reference_type { "shipment" }
      reference_id { "1" }
    end

    trait :delivered do
      action { "delivered" }
      message { "注文が配達されました" }
      reference_type { "shipment" }
      reference_id { "1" }
    end

    trait :cancelled do
      action { "cancelled" }
      message { "注文がキャンセルされました" }
    end

    trait :return_requested do
      action { "return_requested" }
      message { "返品がリクエストされました" }
      reference_type { "return" }
      reference_id { "1" }
    end

    trait :return_approved do
      action { "return_approved" }
      message { "返品が承認されました" }
      reference_type { "return" }
      reference_id { "1" }
    end

    trait :return_received do
      action { "return_received" }
      message { "返品が受領されました" }
      reference_type { "return" }
      reference_id { "1" }
    end

    trait :return_completed do
      action { "return_completed" }
      message { "返品が完了しました" }
      reference_type { "return" }
      reference_id { "1" }
    end

    trait :return_rejected do
      action { "return_rejected" }
      message { "返品が拒否されました" }
      reference_type { "return" }
      reference_id { "1" }
    end

    trait :invoice_created do
      action { "invoice_created" }
      message { "請求書が作成されました" }
      reference_type { "invoice" }
      reference_id { "1" }
    end

    trait :invoice_sent do
      action { "invoice_sent" }
      message { "請求書が送信されました" }
      reference_type { "invoice" }
      reference_id { "1" }
    end

    trait :invoice_paid do
      action { "invoice_paid" }
      message { "請求書が支払われました" }
      reference_type { "invoice" }
      reference_id { "1" }
    end

    trait :shipment_created do
      action { "shipment_created" }
      message { "出荷が作成されました" }
      reference_type { "shipment" }
      reference_id { "1" }
    end

    trait :item_returned do
      action { "item_returned" }
      message { "商品が返品されました" }
      reference_type { "return" }
      reference_id { "1" }
    end

    trait :with_user do
      association :user
      source { "customer" }
    end

    trait :admin_action do
      source { "admin" }
    end

    trait :api_action do
      source { "api" }
    end

    trait :customer_visible do
      is_customer_visible { true }
    end

    trait :notification_sent do
      is_notification_sent { true }
      notification_sent_at { Time.current }
      notification_type { "email" }
    end

    trait :with_notes do
      notes { "特記事項があります" }
    end
  end
end
