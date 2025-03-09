FactoryBot.define do
  factory :inventory_alert do
    association :inventory
    association :product, optional: true
    association :warehouse, optional: true
    alert_type { "low_stock" }
    threshold_value { 10 }
    active { true }
    notification_method { "email" }
    notification_recipients { "warehouse@example.com,manager@example.com" }
    message_template { "在庫が設定された閾値を下回りました。現在の在庫数: {{quantity}}" }
    frequency_days { 1 }
    last_triggered_at { nil }
    trigger_count { 0 }
    auto_reorder { false }
    auto_reorder_quantity { nil }
    severity { "medium" }

    trait :low_stock do
      alert_type { "low_stock" }
      threshold_value { 10 }
      message_template { "在庫が設定された閾値を下回りました。現在の在庫数: {{quantity}}" }
    end

    trait :overstock do
      alert_type { "overstock" }
      threshold_value { 200 }
      message_template { "在庫が設定された閾値を上回りました。現在の在庫数: {{quantity}}" }
    end

    trait :expiry do
      alert_type { "expiry" }
      threshold_value { 30 } # 30日前に通知
      message_template { "商品の有効期限が近づいています。残り日数: {{days_until_expiry}}" }
    end

    trait :no_movement do
      alert_type { "no_movement" }
      threshold_value { 90 } # 90日間動きがない場合
      message_template { "商品が{{threshold_value}}日間動いていません。" }
    end

    trait :inactive do
      active { false }
    end

    trait :triggered do
      last_triggered_at { 1.day.ago }
      trigger_count { 1 }
    end

    trait :multiple_triggers do
      last_triggered_at { 1.day.ago }
      trigger_count { 5 }
    end

    trait :with_auto_reorder do
      auto_reorder { true }
      auto_reorder_quantity { 50 }
    end

    trait :high_severity do
      severity { "high" }
    end

    trait :critical_severity do
      severity { "critical" }
    end

    trait :low_severity do
      severity { "low" }
    end

    trait :sms_notification do
      notification_method { "sms" }
      notification_recipients { "+81901234567,+81902345678" }
    end

    trait :dashboard_notification do
      notification_method { "dashboard" }
    end

    trait :all_notifications do
      notification_method { "all" }
      notification_recipients { "warehouse@example.com,+81901234567" }
    end
  end
end
