FactoryBot.define do
  factory :order_status do
    sequence(:name) { |n| "ステータス#{n}" }
    sequence(:code) { |n| "status_#{n}" }
    description { "注文ステータスの説明" }
    sequence(:display_order) { |n| n }
    color_code { "#007bff" }
    is_active { true }
    is_default { false }
    is_cancellable { true }
    is_returnable { false }
    requires_shipping { true }
    requires_payment { true }
    email_template { nil }
    sms_template { nil }
    notification_message { nil }

    trait :pending do
      name { "保留中" }
      code { "pending" }
      description { "注文は作成されましたが、まだ処理されていません" }
      display_order { 1 }
      color_code { "#ffc107" }
      is_default { true }
      is_cancellable { true }
      is_returnable { false }
      requires_shipping { true }
      requires_payment { true }
    end

    trait :processing do
      name { "処理中" }
      code { "processing" }
      description { "注文は処理中です" }
      display_order { 2 }
      color_code { "#17a2b8" }
      is_default { false }
      is_cancellable { true }
      is_returnable { false }
      requires_shipping { true }
      requires_payment { true }
    end

    trait :shipped do
      name { "出荷済み" }
      code { "shipped" }
      description { "注文は出荷されました" }
      display_order { 3 }
      color_code { "#6f42c1" }
      is_default { false }
      is_cancellable { false }
      is_returnable { false }
      requires_shipping { true }
      requires_payment { true }
    end

    trait :delivered do
      name { "配達済み" }
      code { "delivered" }
      description { "注文は配達されました" }
      display_order { 4 }
      color_code { "#28a745" }
      is_default { false }
      is_cancellable { false }
      is_returnable { true }
      requires_shipping { true }
      requires_payment { true }
    end

    trait :completed do
      name { "完了" }
      code { "completed" }
      description { "注文は完了しました" }
      display_order { 5 }
      color_code { "#28a745" }
      is_default { false }
      is_cancellable { false }
      is_returnable { false }
      requires_shipping { true }
      requires_payment { true }
    end

    trait :cancelled do
      name { "キャンセル" }
      code { "cancelled" }
      description { "注文はキャンセルされました" }
      display_order { 6 }
      color_code { "#dc3545" }
      is_default { false }
      is_cancellable { false }
      is_returnable { false }
      requires_shipping { false }
      requires_payment { false }
    end

    trait :returned do
      name { "返品済み" }
      code { "returned" }
      description { "注文は返品されました" }
      display_order { 7 }
      color_code { "#fd7e14" }
      is_default { false }
      is_cancellable { false }
      is_returnable { false }
      requires_shipping { false }
      requires_payment { false }
    end

    trait :refunded do
      name { "返金済み" }
      code { "refunded" }
      description { "注文は返金されました" }
      display_order { 8 }
      color_code { "#20c997" }
      is_default { false }
      is_cancellable { false }
      is_returnable { false }
      requires_shipping { false }
      requires_payment { false }
    end

    trait :inactive do
      is_active { false }
    end

    trait :default do
      is_default { true }
    end
  end
end
