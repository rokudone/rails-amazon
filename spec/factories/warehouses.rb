FactoryBot.define do
  factory :warehouse do
    sequence(:name) { |n| "倉庫#{n}" }
    sequence(:code) { |n| "WH#{n.to_s.rjust(3, '0')}" }
    address { "東京都渋谷区神宮前1-1-1" }
    city { "渋谷区" }
    state { "東京都" }
    postal_code { "150-0001" }
    country { "日本" }
    phone { "03-1234-5678" }
    email { "warehouse@example.com" }
    latitude { 35.6812362 }
    longitude { 139.7649361 }
    active { true }
    capacity { 10000 }
    warehouse_type { "standard" }
    description { "標準的な倉庫" }
    manager_name { "山田太郎" }

    trait :inactive do
      active { false }
    end

    trait :small do
      capacity { 1000 }
      warehouse_type { "small" }
      description { "小規模倉庫" }
    end

    trait :large do
      capacity { 50000 }
      warehouse_type { "large" }
      description { "大規模倉庫" }
    end

    trait :cold_storage do
      warehouse_type { "cold_storage" }
      description { "冷蔵・冷凍倉庫" }
    end

    trait :overseas do
      address { "123 Main St" }
      city { "New York" }
      state { "NY" }
      postal_code { "10001" }
      country { "USA" }
      latitude { 40.7127753 }
      longitude { -74.0059728 }
    end
  end
end
