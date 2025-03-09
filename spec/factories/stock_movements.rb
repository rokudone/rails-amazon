FactoryBot.define do
  factory :stock_movement do
    association :inventory
    source_warehouse { nil }
    destination_warehouse { nil }
    quantity { 10 }
    movement_type { "inbound" }
    sequence(:reference_number) { |n| "REF#{n.to_s.rjust(6, '0')}" }
    order { nil }
    supplier_order { nil }
    return_record { nil }
    reason { "定期入荷" }
    status { "completed" }
    completed_at { Time.current }
    created_by { "system" }
    approved_by { nil }
    unit_cost { 10.0 }
    total_cost { 100.0 }
    batch_number { "BATCH001" }
    expiry_date { 1.year.from_now }

    trait :inbound do
      movement_type { "inbound" }
      association :destination_warehouse, factory: :warehouse
      reason { "定期入荷" }
    end

    trait :outbound do
      movement_type { "outbound" }
      association :source_warehouse, factory: :warehouse
      reason { "出荷" }
    end

    trait :transfer do
      movement_type { "transfer" }
      association :source_warehouse, factory: :warehouse
      association :destination_warehouse, factory: :warehouse
      reason { "倉庫間移動" }
    end

    trait :return do
      movement_type { "return" }
      association :destination_warehouse, factory: :warehouse
      reason { "返品" }
    end

    trait :adjustment do
      movement_type { "adjustment" }
      reason { "在庫調整" }
    end

    trait :disposal do
      movement_type { "disposal" }
      association :source_warehouse, factory: :warehouse
      reason { "期限切れ廃棄" }
    end

    trait :with_order do
      movement_type { "outbound" }
      association :order
      association :source_warehouse, factory: :warehouse
    end

    trait :with_supplier_order do
      movement_type { "inbound" }
      association :supplier_order
      association :destination_warehouse, factory: :warehouse
    end

    trait :with_return do
      movement_type { "return" }
      association :return_record, factory: :return
      association :destination_warehouse, factory: :warehouse
    end

    trait :pending do
      status { "pending" }
      completed_at { nil }
    end

    trait :in_progress do
      status { "in_progress" }
      completed_at { nil }
    end

    trait :cancelled do
      status { "cancelled" }
      completed_at { nil }
    end
  end
end
