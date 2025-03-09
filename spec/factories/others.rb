FactoryBot.define do
  factory :notification do
    user
    notification_type { ['order_status', 'price_drop', 'back_in_stock', 'shipping_update', 'payment_update', 'review_request', 'promotion', 'system'].sample }
    sequence(:title) { |n| "Notification #{n}" }
    content { Faker::Lorem.paragraph }
    icon { ['info', 'success', 'warning', 'error'].sample }
    url { Faker::Internet.url }
    is_read { false }
    is_actionable { [true, false].sample }
    action_text { is_actionable ? Faker::Lorem.word : nil }
    action_url { is_actionable ? Faker::Internet.url : nil }
    priority { [0, 1, 2].sample }
    delivery_method { ['in_app', 'email', 'sms', 'push'].sample }
    is_sent { true }
    sent_at { Time.current }

    trait :read do
      is_read { true }
      read_at { Time.current }
    end

    trait :unread do
      is_read { false }
      read_at { nil }
    end

    trait :actionable do
      is_actionable { true }
      action_text { Faker::Lorem.word }
      action_url { Faker::Internet.url }
    end

    trait :high_priority do
      priority { 2 }
    end

    trait :order_notification do
      notification_type { 'order_status' }
      title { 'Order Status Update' }
      association :notifiable, factory: :order
    end

    trait :price_drop_notification do
      notification_type { 'price_drop' }
      title { 'Price Drop Alert' }
      association :notifiable, factory: :product
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end

  factory :search_history do
    association :user, optional: true
    query { Faker::Lorem.words(number: rand(1..3)).join(' ') }
    filters { { category: rand(1..10), price_min: rand(1000..5000), price_max: rand(5001..10000) }.to_json }
    sort_by { ['relevance', 'price_asc', 'price_desc', 'newest', 'rating'].sample }
    results_count { rand(0..100) }
    has_clicked_result { [true, false].sample }
    position_clicked { has_clicked_result ? rand(1..10) : nil }
    association :product_clicked, factory: :product, optional: true
    category_path { "category/#{rand(1..10)}/subcategory/#{rand(1..5)}" }
    device_type { ['desktop', 'mobile', 'tablet'].sample }
    browser { ['chrome', 'firefox', 'safari', 'edge'].sample }
    ip_address { Faker::Internet.ip_v4_address }
    session_id { SecureRandom.hex(16) }
    search_duration { rand(0.1..5.0).round(2) }
    is_voice_search { [true, false].sample(weight: [0.1, 0.9]) }
    is_image_search { [true, false].sample(weight: [0.1, 0.9]) }
    is_autocomplete { [true, false].sample(weight: [0.3, 0.7]) }

    trait :with_results do
      results_count { rand(1..100) }
    end

    trait :no_results do
      results_count { 0 }
    end

    trait :clicked do
      has_clicked_result { true }
      position_clicked { rand(1..10) }
      association :product_clicked, factory: :product
    end

    trait :voice_search do
      is_voice_search { true }
    end

    trait :image_search do
      is_image_search { true }
    end

    trait :from_mobile do
      device_type { 'mobile' }
    end
  end

  factory :recently_viewed do
    user
    product
    view_count { rand(1..10) }
    last_viewed_at { Time.current }
    view_duration { rand(10..300) }
    source { ['search', 'recommendation', 'category', 'direct'].sample }
    device_type { ['desktop', 'mobile', 'tablet'].sample }
    session_id { SecureRandom.hex(16) }
    added_to_cart { [true, false].sample }
    added_to_wishlist { [true, false].sample }
    purchased { [true, false].sample }

    trait :multiple_views do
      view_count { rand(2..10) }
    end

    trait :long_view do
      view_duration { rand(300..1800) }
    end

    trait :added_to_cart do
      added_to_cart { true }
    end

    trait :added_to_wishlist do
      added_to_wishlist { true }
    end

    trait :purchased do
      purchased { true }
    end

    trait :from_search do
      source { 'search' }
    end

    trait :from_recommendation do
      source { 'recommendation' }
    end
  end

  factory :wishlist do
    user
    sequence(:name) { |n| "Wishlist #{n}" }
    description { Faker::Lorem.sentence }
    is_public { false }
    is_default { false }
    sharing_token { SecureRandom.urlsafe_base64(8) }
    items_count { 0 }
    last_modified_at { Time.current }
    occasion { ['birthday', 'wedding', 'holiday', 'graduation'].sample }
    occasion_date { rand(1..365).days.from_now }
    status { 'active' }

    trait :public do
      is_public { true }
    end

    trait :default do
      is_default { true }
      name { 'My Wishlist' }
    end

    trait :archived do
      status { 'archived' }
    end

    trait :deleted do
      status { 'deleted' }
    end

    trait :with_items do
      transient do
        items_count { 5 }
      end

      after(:create) do |wishlist, evaluator|
        evaluator.items_count.times do
          product = create(:product)
          wishlist.add_item(product, quantity: rand(1..3))
        end
        wishlist.update(items_count: evaluator.items_count)
      end
    end

    trait :for_birthday do
      occasion { 'birthday' }
      occasion_date { rand(1..60).days.from_now }
    end

    trait :for_wedding do
      occasion { 'wedding' }
      occasion_date { rand(30..180).days.from_now }
    end

    factory :default_wishlist do
      is_default { true }
      name { 'My Wishlist' }
    end
  end

  factory :cart do
    association :user, optional: true
    session_id { user.nil? ? SecureRandom.hex(16) : nil }
    status { 'active' }
    last_activity_at { Time.current }
    is_guest { user.nil? }
    items_count { 0 }
    total_amount { 0 }
    discount_amount { 0 }
    tax_amount { 0 }
    shipping_amount { 0 }
    final_amount { 0 }
    currency { 'JPY' }

    trait :with_items do
      transient do
        items_count { 3 }
      end

      after(:create) do |cart, evaluator|
        create_list(:cart_item, evaluator.items_count, cart: cart)

        # 合計金額の更新
        cart.update_totals
        cart.save
      end
    end

    trait :with_coupon do
      coupon_code { "COUPON#{SecureRandom.hex(4).upcase}" }
      discount_amount { rand(500..2000) }

      after(:create) do |cart|
        cart.update_totals
        cart.save
      end
    end

    trait :abandoned do
      status { 'abandoned' }
      last_activity_at { rand(1..30).days.ago }
    end

    trait :converted do
      status { 'converted' }
      converted_at { Time.current }
      association :converted_to_order, factory: :order
    end

    trait :merged do
      status { 'merged' }
    end

    trait :guest_cart do
      user { nil }
      session_id { SecureRandom.hex(16) }
      is_guest { true }
    end

    trait :with_shipping_address do
      association :shipping_address, factory: :address
    end

    trait :with_billing_address do
      association :billing_address, factory: :address
    end

    factory :abandoned_cart do
      status { 'abandoned' }
      last_activity_at { rand(1..30).days.ago }

      after(:create) do |cart|
        create_list(:cart_item, 2, cart: cart)
        cart.update_totals
        cart.save
      end
    end
  end

  factory :cart_item do
    cart
    product
    association :product_variant, optional: true
    association :seller, optional: true
    quantity { rand(1..5) }
    unit_price { product.price }
    total_price { unit_price * quantity }
    is_saved_for_later { false }
    is_gift { false }
    has_gift_wrap { false }
    status { 'in_stock' }
    added_at { Time.current }
    last_modified_at { Time.current }

    after(:create) do |cart_item|
      cart_item.cart.update_totals
    end

    trait :saved_for_later do
      is_saved_for_later { true }
    end

    trait :gift do
      is_gift { true }
      gift_message { Faker::Lorem.sentence }
    end

    trait :with_gift_wrap do
      has_gift_wrap { true }
      association :gift_wrap
    end

    trait :out_of_stock do
      status { 'out_of_stock' }
    end

    trait :back_ordered do
      status { 'back_ordered' }
    end

    trait :with_variant do
      association :product_variant
    end

    trait :with_options do
      selected_options { { color: 'Red', size: 'Large' }.to_json }
    end
  end

  factory :event do
    sequence(:name) { |n| "Event #{n}" }
    description { Faker::Lorem.paragraph }
    start_date { 1.day.ago }
    end_date { 7.days.from_now }
    is_active { true }
    event_type { ['sale', 'promotion', 'holiday', 'product_launch', 'clearance'].sample }
    banner_image_url { Faker::Internet.url(host: 'example.com', path: "/banners/#{SecureRandom.hex(8)}.jpg") }
    landing_page_url { Faker::Internet.url }
    is_featured { false }
    priority { rand(0..10) }
    association :created_by, factory: :user
    status { 'active' }
    is_recurring { false }
    timezone { 'Asia/Tokyo' }

    trait :with_campaign do
      association :campaign
    end

    trait :with_promotion do
      association :promotion
    end

    trait :current do
      start_date { 1.day.ago }
      end_date { 7.days.from_now }
      status { 'active' }
    end

    trait :upcoming do
      start_date { 7.days.from_now }
      end_date { 14.days.from_now }
      status { 'scheduled' }
    end

    trait :past do
      start_date { 14.days.ago }
      end_date { 7.days.ago }
      status { 'completed' }
    end

    trait :inactive do
      is_active { false }
      status { 'cancelled' }
    end

    trait :featured do
      is_featured { true }
    end

    trait :recurring do
      is_recurring { true }
      recurrence_pattern { ['daily', 'weekly', 'monthly', 'yearly'].sample }
    end

    trait :sale_event do
      event_type { 'sale' }
      name { 'Flash Sale' }
    end

    trait :holiday_event do
      event_type { 'holiday' }
      name { ['Christmas Sale', 'New Year Sale', 'Golden Week Sale'].sample }
    end

    trait :product_launch do
      event_type { 'product_launch' }
      name { 'New Product Launch' }
    end
  end

  factory :event_log do
    sequence(:event_name) { |n| "event.#{n}" }
    event_type { ['system', 'user', 'error', 'security', 'api'].sample }
    association :user, optional: true
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { Faker::Internet.user_agent }
    session_id { SecureRandom.hex(16) }
    request_method { ['GET', 'POST', 'PUT', 'DELETE'].sample }
    request_path { "/api/#{Faker::Lorem.word}/#{rand(1..100)}" }
    request_params { { id: rand(1..100), page: rand(1..10) }.to_json }
    response_status { [200, 201, 400, 401, 403, 404, 500].sample }
    details { Faker::Lorem.paragraph }
    severity { ['info', 'warning', 'error', 'critical'].sample }
    duration { rand(10..1000) }
    is_success { [true, false].sample }
    source { ['web', 'api', 'admin', 'background_job'].sample }
    browser { ['chrome', 'firefox', 'safari', 'edge'].sample }
    device_type { ['desktop', 'mobile', 'tablet'].sample }
    operating_system { ['windows', 'macos', 'linux', 'ios', 'android'].sample }

    trait :system_log do
      event_type { 'system' }
      event_name { "system.#{Faker::Lorem.word}" }
    end

    trait :user_log do
      event_type { 'user' }
      event_name { "user.#{Faker::Lorem.word}" }
      user
    end

    trait :error_log do
      event_type { 'error' }
      event_name { "error.#{Faker::Lorem.word}" }
      severity { ['error', 'critical'].sample }
      is_success { false }
      response_status { [400, 401, 403, 404, 500].sample }
      details { { error_class: 'RuntimeError', message: Faker::Lorem.sentence, backtrace: Array.new(5) { Faker::Lorem.sentence } }.to_json }
    end

    trait :security_log do
      event_type { 'security' }
      event_name { "security.#{['login', 'logout', 'password_change', 'access_denied'].sample}" }
      severity { 'warning' }
    end

    trait :api_log do
      event_type { 'api' }
      event_name { "api.#{request_method.downcase}.#{request_path.gsub('/', '.')}" }
      source { 'api' }
    end

    trait :successful do
      is_success { true }
      response_status { [200, 201, 204].sample }
    end

    trait :failed do
      is_success { false }
      response_status { [400, 401, 403, 404, 500].sample }
    end

    trait :with_loggable do
      association :loggable, factory: :user
    end
  end

  factory :system_config do
    sequence(:key) { |n| "config.key.#{n}" }
    value { Faker::Lorem.word }
    value_type { ['string', 'integer', 'float', 'boolean', 'json'].sample }
    group { ['general', 'payment', 'shipping', 'email', 'social', 'api', 'security'].sample }
    description { Faker::Lorem.sentence }
    is_editable { true }
    is_visible { true }
    association :updated_by, factory: :user, optional: true
    last_updated_at { Time.current }
    requires_restart { false }
    is_encrypted { false }
    position { rand(0..100) }

    trait :string_config do
      value { Faker::Lorem.word }
      value_type { 'string' }
    end

    trait :integer_config do
      value { rand(1..1000).to_s }
      value_type { 'integer' }
    end

    trait :float_config do
      value { rand(1.0..1000.0).round(2).to_s }
      value_type { 'float' }
    end

    trait :boolean_config do
      value { ['true', 'false'].sample }
      value_type { 'boolean' }
    end

    trait :json_config do
      value { { key1: Faker::Lorem.word, key2: Faker::Lorem.word }.to_json }
      value_type { 'json' }
    end

    trait :with_options do
      options { ['option1', 'option2', 'option3'].to_json }
    end

    trait :with_validation do
      validation_rules { { required: true, min: 1, max: 100 }.to_json }
    end

    trait :non_editable do
      is_editable { false }
    end

    trait :hidden do
      is_visible { false }
    end

    trait :requires_restart do
      requires_restart { true }
    end

    trait :encrypted do
      is_encrypted { true }
    end

    trait :general_config do
      group { 'general' }
      key { "general.#{Faker::Lorem.word}" }
    end

    trait :payment_config do
      group { 'payment' }
      key { "payment.#{Faker::Lorem.word}" }
    end

    trait :shipping_config do
      group { 'shipping' }
      key { "shipping.#{Faker::Lorem.word}" }
    end
  end

  factory :currency do
    sequence(:code) { |n| "CU#{n}" }
    sequence(:name) { |n| "Currency #{n}" }
    sequence(:symbol) { |n| "C#{n}" }
    is_active { true }
    is_default { false }
    decimal_places { 2 }
    format { '%s%v' }
    exchange_rate_to_default { 1.0 }
    exchange_rate_updated_at { Time.current }
    association :updated_by, factory: :user, optional: true
    flag_image_url { Faker::Internet.url(host: 'example.com', path: "/flags/#{code.downcase}.png") }
    position { rand(0..100) }

    trait :default do
      is_default { true }
      exchange_rate_to_default { 1.0 }
    end

    trait :inactive do
      is_active { false }
    end

    trait :jpy do
      code { 'JPY' }
      name { '日本円' }
      symbol { '¥' }
      decimal_places { 0 }
      is_default { true }
      exchange_rate_to_default { 1.0 }
    end

    trait :usd do
      code { 'USD' }
      name { '米ドル' }
      symbol { '$' }
      decimal_places { 2 }
      exchange_rate_to_default { 0.0091 }
    end

    trait :eur do
      code { 'EUR' }
      name { 'ユーロ' }
      symbol { '€' }
      decimal_places { 2 }
      exchange_rate_to_default { 0.0083 }
    end

    trait :gbp do
      code { 'GBP' }
      name { '英ポンド' }
      symbol { '£' }
      decimal_places { 2 }
      exchange_rate_to_default { 0.0071 }
    end
  end

  factory :country do
    sequence(:code) { |n| "C#{n}" }
    sequence(:name) { |n| "Country #{n}" }
    native_name { name }
    phone_code { rand(1..999).to_s }
    capital { Faker::Address.city }
    currency_code { 'JPY' }
    tld { ".#{code.downcase}" }
    region { ['Asia', 'Europe', 'North America', 'South America', 'Africa', 'Oceania'].sample }
    subregion { Faker::Address.state }
    latitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }
    flag_image_url { Faker::Internet.url(host: 'example.com', path: "/flags/#{code.downcase}.png") }
    is_active { true }
    is_shipping_available { true }
    is_billing_available { true }
    address_format { { format: '{name}\n{address1}\n{address2}\n{city}, {state} {zip}\n{country}' }.to_json }
    postal_code_format { { regex: '\\d{3}-\\d{4}' }.to_json }
    association :currency, optional: true
    position { rand(0..100) }
    locale { 'ja' }

    trait :japan do
      code { 'JP' }
      name { '日本' }
      native_name { '日本' }
      phone_code { '81' }
      capital { '東京' }
      currency_code { 'JPY' }
      tld { '.jp' }
      region { 'Asia' }
      subregion { 'Eastern Asia' }
      latitude { 36.204824 }
      longitude { 138.252924 }
      address_format { { format: '{zip}\n{state}{city}\n{address1}\n{address2}\n{name}' }.to_json }
      postal_code_format { { regex: '\\d{3}-\\d{4}' }.to_json }
      locale { 'ja' }

      after(:create) do |country|
        currency = Currency.find_by(code: 'JPY') || create(:currency, :jpy)
        country.update(currency: currency)
      end
    end

    trait :usa do
      code { 'US' }
      name { 'United States' }
      native_name { 'United States of America' }
      phone_code { '1' }
      capital { 'Washington D.C.' }
      currency_code { 'USD' }
      tld { '.us' }
      region { 'North America' }
      subregion { 'Northern America' }
      latitude { 37.09024 }
      longitude { -95.712891 }
      address_format { { format: '{name}\n{address1}\n{address2}\n{city}, {state} {zip}\n{country}' }.to_json }
      postal_code_format { { regex: '\\d{5}(-\\d{4})?' }.to_json }
      locale { 'en' }

      after(:create) do |country|
        currency = Currency.find_by(code: 'USD') || create(:currency, :usd)
        country.update(currency: currency)
      end
    end

    trait :inactive do
      is_active { false }
    end

    trait :no_shipping do
      is_shipping_available { false }
    end

    trait :no_billing do
      is_billing_available { false }
    end

    trait :with_regions do
      transient do
        regions_count { 5 }
      end

      after(:create) do |country, evaluator|
        create_list(:region, evaluator.regions_count, country: country)
      end
    end
  end

  factory :region do
    country
    sequence(:code) { |n| "R#{n}" }
    sequence(:name) { |n| "Region #{n}" }
    native_name { name }
    region_type { ['state', 'province', 'prefecture', 'territory', 'district'].sample }
    latitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }
    is_active { true }
    is_shipping_available { true }
    is_billing_available { true }
    position { rand(0..100) }

    trait :prefecture do
      region_type { 'prefecture' }
      sequence(:name) { |n| "Prefecture #{n}" }
    end

    trait :state do
      region_type { 'state' }
      sequence(:name) { |n| "State #{n}" }
    end

    trait :province do
      region_type { 'province' }
      sequence(:name) { |n| "Province #{n}" }
    end

    trait :inactive do
      is_active { false }
    end

    trait :no_shipping do
      is_shipping_available { false }
    end

    trait :no_billing do
      is_billing_available { false }
    end

    trait :with_metadata do
      metadata { { population: rand(10000..1000000), area: rand(100..10000) }.to_json }
    end
  end
end
