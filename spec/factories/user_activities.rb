FactoryBot.define do
  factory :user_activity do
    association :user
    activity_type { %w[login logout search view purchase review wishlist cart follow share].sample }
    action { ['add', 'remove', 'update', 'view', 'click', 'submit'].sample }
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { "Mozilla/5.0 (#{['Windows NT 10.0', 'Macintosh', 'Linux'].sample}; rv:#{rand(70..100)}.0) Gecko/20100101 Firefox/#{rand(70..100)}.0" }
    resource_type { ['Product', 'Category', 'Order', 'Review', 'Seller', nil].sample }
    resource_id { resource_type ? rand(1..1000) : nil }
    details { Faker::Json.shallow_json(width: 3, options: { key: 'Commerce.product_name', value: 'Number.decimal' }) }
    activity_time { Faker::Time.backward(days: 30) }

    trait :login do
      activity_type { 'login' }
      action { 'submit' }
      resource_type { nil }
      resource_id { nil }
      details { { success: [true, false].sample, method: ['password', 'oauth', 'token'].sample }.to_json }
    end

    trait :logout do
      activity_type { 'logout' }
      action { 'submit' }
      resource_type { nil }
      resource_id { nil }
    end

    trait :search do
      activity_type { 'search' }
      action { 'submit' }
      details { { query: Faker::Commerce.product_name, filters: { category: Faker::Commerce.department, price_range: "#{rand(10..50)}-#{rand(51..200)}" } }.to_json }
    end

    trait :view_product do
      activity_type { 'view' }
      action { 'view' }
      resource_type { 'Product' }
      resource_id { rand(1..1000) }
      details { { product_name: Faker::Commerce.product_name, category: Faker::Commerce.department, price: Faker::Commerce.price }.to_json }
    end

    trait :purchase do
      activity_type { 'purchase' }
      action { 'submit' }
      resource_type { 'Order' }
      resource_id { rand(1..1000) }
      details { { order_total: Faker::Commerce.price(range: 20..200), items_count: rand(1..5), payment_method: ['credit_card', 'paypal', 'gift_card'].sample }.to_json }
    end

    trait :add_to_cart do
      activity_type { 'cart' }
      action { 'add' }
      resource_type { 'Product' }
      resource_id { rand(1..1000) }
      details { { product_name: Faker::Commerce.product_name, price: Faker::Commerce.price, quantity: rand(1..5) }.to_json }
    end

    factory :login_activity do
      login
    end

    factory :search_activity do
      search
    end

    factory :product_view_activity do
      view_product
    end

    factory :purchase_activity do
      purchase
    end
  end
end
