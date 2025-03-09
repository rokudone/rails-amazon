# セラー・その他データの作成
puts "\n=== Creating Seller and Other Data ==="

# 通貨の作成
puts "Creating currencies..."
admin = User.find_by(email: "admin@example.com")

jpy = Currency.create!(
  code: 'JPY',
  name: '日本円',
  symbol: '¥',
  is_active: true,
  is_default: true,
  decimal_places: 0,
  format: '%s%v',
  exchange_rate_to_default: 1.0,
  exchange_rate_updated_at: Time.current,
  updated_by: admin,
  flag_image_url: "https://example.com/flags/jp.png",
  position: 0
)

Currency.create!(
  code: 'USD',
  name: '米ドル',
  symbol: '$',
  is_active: true,
  is_default: false,
  decimal_places: 2,
  format: '%s%v',
  exchange_rate_to_default: 0.0091,
  exchange_rate_updated_at: Time.current,
  updated_by: admin,
  flag_image_url: "https://example.com/flags/us.png",
  position: 1
)

Currency.create!(
  code: 'EUR',
  name: 'ユーロ',
  symbol: '€',
  is_active: true,
  is_default: false,
  decimal_places: 2,
  format: '%s%v',
  exchange_rate_to_default: 0.0083,
  exchange_rate_updated_at: Time.current,
  updated_by: admin,
  flag_image_url: "https://example.com/flags/eu.png",
  position: 2
)

# 国と地域の作成
puts "Creating countries and regions..."
japan = Country.create!(
  code: 'JP',
  name: '日本',
  native_name: '日本',
  phone_code: '81',
  capital: '東京',
  currency_code: 'JPY',
  currency: jpy,
  tld: '.jp',
  region: 'Asia',
  subregion: 'Eastern Asia',
  latitude: 36.204824,
  longitude: 138.252924,
  flag_image_url: "https://example.com/flags/jp.png",
  is_active: true,
  is_shipping_available: true,
  is_billing_available: true,
  address_format: { format: '{zip}\n{state}{city}\n{address1}\n{address2}\n{name}' }.to_json,
  postal_code_format: { regex: '\\d{3}-\\d{4}' }.to_json,
  position: 0,
  locale: 'ja'
)

# 日本の都道府県
prefectures = [
  { code: '01', name: '北海道' },
  { code: '02', name: '青森県' },
  { code: '03', name: '岩手県' },
  { code: '04', name: '宮城県' },
  { code: '05', name: '秋田県' },
  { code: '06', name: '山形県' },
  { code: '07', name: '福島県' },
  { code: '08', name: '茨城県' },
  { code: '09', name: '栃木県' },
  { code: '10', name: '群馬県' },
  { code: '11', name: '埼玉県' },
  { code: '12', name: '千葉県' },
  { code: '13', name: '東京都' },
  { code: '14', name: '神奈川県' },
  { code: '15', name: '新潟県' },
  { code: '16', name: '富山県' },
  { code: '17', name: '石川県' },
  { code: '18', name: '福井県' },
  { code: '19', name: '山梨県' },
  { code: '20', name: '長野県' },
  { code: '21', name: '岐阜県' },
  { code: '22', name: '静岡県' },
  { code: '23', name: '愛知県' },
  { code: '24', name: '三重県' },
  { code: '25', name: '滋賀県' },
  { code: '26', name: '京都府' },
  { code: '27', name: '大阪府' },
  { code: '28', name: '兵庫県' },
  { code: '29', name: '奈良県' },
  { code: '30', name: '和歌山県' },
  { code: '31', name: '鳥取県' },
  { code: '32', name: '島根県' },
  { code: '33', name: '岡山県' },
  { code: '34', name: '広島県' },
  { code: '35', name: '山口県' },
  { code: '36', name: '徳島県' },
  { code: '37', name: '香川県' },
  { code: '38', name: '愛媛県' },
  { code: '39', name: '高知県' },
  { code: '40', name: '福岡県' },
  { code: '41', name: '佐賀県' },
  { code: '42', name: '長崎県' },
  { code: '43', name: '熊本県' },
  { code: '44', name: '大分県' },
  { code: '45', name: '宮崎県' },
  { code: '46', name: '鹿児島県' },
  { code: '47', name: '沖縄県' }
]

prefectures.each do |pref|
  Region.create!(
    country: japan,
    code: pref[:code],
    name: pref[:name],
    native_name: pref[:name],
    region_type: 'prefecture',
    is_active: true,
    is_shipping_available: true,
    is_billing_available: true,
    position: pref[:code].to_i
  )
end

# セラーの作成
puts "Creating sellers..."
users = User.all.to_a
products = Product.all.to_a

2.times do |i|
  user = users[i]

  seller = Seller.create!(
    user: user,
    company_name: "#{user.last_name}商事#{i+1}",
    legal_name: "#{user.last_name}商事株式会社",
    tax_identifier: "T#{i+1}#{SecureRandom.hex(6).upcase}",
    business_type: ['individual', 'corporation', 'partnership', 'llc'].sample,
    description: Faker::Company.catch_phrase,
    logo_url: "https://example.com/logos/seller#{i+1}.png",
    website_url: Faker::Internet.url,
    contact_email: "seller#{i+1}@example.com",
    contact_phone: Faker::PhoneNumber.phone_number,
    status: ['pending', 'approved', 'suspended', 'rejected'].sample,
    is_featured: i == 0,
    is_verified: i == 0,
    store_url: "/sellers/#{user.last_name.parameterize}-#{i+1}"
  )

  if seller.status == 'approved'
    seller.update(
      approved_at: Time.current - rand(1..90).days,
      approved_by: admin
    )
  end

  if seller.is_verified
    seller.update(verified_at: Time.current - rand(1..60).days)
  end

  # セラードキュメントの作成
  ['business_license', 'tax_certificate', 'identity_proof'].each do |doc_type|
    SellerDocument.create!(
      seller: seller,
      document_type: doc_type,
      file_url: "https://example.com/documents/seller#{i+1}/#{doc_type}.pdf",
      file_name: "#{doc_type}.pdf",
      content_type: 'application/pdf',
      file_size: rand(100_000..5_000_000),
      expiry_date: Time.current + rand(180..365).days,
      is_verified: seller.is_verified,
      status: seller.is_verified ? 'approved' : 'pending',
      is_required: true
    )
  end

  # セラーポリシーの作成
  ['return', 'shipping', 'privacy'].each do |policy_type|
    SellerPolicy.create!(
      seller: seller,
      policy_type: policy_type,
      content: Faker::Lorem.paragraphs(number: 3).join("\n\n"),
      is_active: true,
      effective_date: Date.current,
      is_approved: seller.is_verified,
      approved_at: seller.is_verified ? Time.current - rand(1..30).days : nil,
      approved_by: seller.is_verified ? admin : nil,
      version: '1.0',
      last_updated_at: Time.current - rand(1..30).days
    )
  end

  # セラー商品の作成
  rand(2..5).times do
    product = products.sample

    SellerProduct.create!(
      seller: seller,
      product: product,
      price: product.price * rand(0.9..1.1),
      quantity: rand(10..100),
      is_active: true,
      condition: ['new', 'used', 'refurbished', 'open_box'].sample,
      condition_description: Faker::Lorem.sentence,
      sku: "SP-#{seller.id}-#{product.id}-#{SecureRandom.hex(4).upcase}",
      shipping_cost: [0, rand(300..1000)].sample,
      handling_days: rand(1..5),
      is_featured: rand < 0.2,
      is_prime_eligible: rand < 0.5,
      is_fulfilled_by_amazon: rand < 0.3,
      seller_cost: product.price * rand(0.5..0.8),
      sales_count: rand(0..50),
      last_sold_at: rand < 0.7 ? Time.current - rand(1..30).days : nil
    )
  end

  # セラー評価の作成
  if seller.status == 'approved'
    rand(3..10).times do
      user = users.sample
      next if user == seller.user

      SellerRating.create!(
        user: user,
        seller: seller,
        rating: rand(3..5),
        comment: Faker::Lorem.paragraph,
        dimension: ['shipping_speed', 'product_quality', 'customer_service', 'overall'].sample,
        is_verified_purchase: [true, false].sample,
        is_anonymous: rand < 0.3,
        is_approved: true,
        approved_at: Time.current - rand(1..30).days,
        helpful_votes_count: rand(0..10),
        unhelpful_votes_count: rand(0..3)
      )
    end

    # 評価統計の更新
    seller.update_ratings_stats!
  end

  # セラー取引の作成
  if seller.status == 'approved'
    10.times do
      transaction_type = ['sale', 'refund', 'fee', 'payout', 'adjustment'].sample
      amount = case transaction_type
               when 'sale'
                 rand(1000..10000)
               when 'refund'
                 rand(1000..5000) * -1
               when 'fee'
                 rand(100..1000) * -1
               when 'payout'
                 rand(5000..20000) * -1
               when 'adjustment'
                 rand(-1000..1000)
               end

      SellerTransaction.create!(
        seller: seller,
        transaction_type: transaction_type,
        amount: amount,
        fee_amount: transaction_type == 'fee' ? 0 : (amount.abs * 0.15).round(2),
        tax_amount: (amount.abs * 0.1).round(2),
        currency: 'JPY',
        status: ['pending', 'completed', 'failed', 'cancelled'].sample,
        payment_method: ['credit_card', 'bank_transfer', 'amazon_pay'].sample,
        reference_number: "TX#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}",
        description: Faker::Lorem.sentence,
        created_at: Time.current - rand(1..90).days
      )
    end
  end

  # セラーパフォーマンスの作成
  if seller.status == 'approved'
    performance_status = ['excellent', 'good', 'fair', 'poor', 'at_risk'].sample

    SellerPerformance.create!(
      seller: seller,
      period_start: Time.current.beginning_of_month - 1.month,
      period_end: Time.current.end_of_month - 1.month,
      orders_count: rand(10..100),
      cancelled_orders_count: rand(0..5),
      cancellation_rate: rand(0..10.0).round(2),
      late_shipments_count: rand(0..10),
      late_shipment_rate: rand(0..15.0).round(2),
      returns_count: rand(0..10),
      return_rate: rand(0..15.0).round(2),
      average_rating: seller.average_rating || rand(3.0..5.0).round(2),
      ratings_count: seller.ratings_count || rand(5..50),
      negative_feedback_count: rand(0..5),
      negative_feedback_rate: rand(0..10.0).round(2),
      total_sales: rand(100000..1000000),
      total_fees: rand(10000..100000),
      total_profit: rand(50000..500000),
      performance_status: performance_status,
      is_eligible_for_featured: ['excellent', 'good'].include?(performance_status),
      is_eligible_for_prime: ['excellent', 'good', 'fair'].include?(performance_status)
    )
  end
end

# システム設定の作成
puts "Creating system configs..."
[
  { key: 'site.name', value: 'Amazon Clone', value_type: 'string', group: 'general' },
  { key: 'site.description', value: 'Amazon Clone - オンラインショッピングサイト', value_type: 'string', group: 'general' },
  { key: 'site.logo', value: 'https://example.com/logo.png', value_type: 'string', group: 'general' },
  { key: 'site.favicon', value: 'https://example.com/favicon.ico', value_type: 'string', group: 'general' },
  { key: 'site.currency', value: 'JPY', value_type: 'string', group: 'general' },
  { key: 'site.timezone', value: 'Asia/Tokyo', value_type: 'string', group: 'general' },
  { key: 'site.locale', value: 'ja', value_type: 'string', group: 'general' },

  { key: 'payment.methods', value: '["credit_card", "bank_transfer", "amazon_pay", "convenience_store"]', value_type: 'json', group: 'payment' },
  { key: 'payment.tax_rate', value: '10', value_type: 'float', group: 'payment' },
  { key: 'payment.min_order_amount', value: '500', value_type: 'integer', group: 'payment' },

  { key: 'shipping.free_shipping_threshold', value: '5000', value_type: 'integer', group: 'shipping' },
  { key: 'shipping.default_shipping_cost', value: '500', value_type: 'integer', group: 'shipping' },
  { key: 'shipping.express_shipping_cost', value: '1000', value_type: 'integer', group: 'shipping' },

  { key: 'email.from_address', value: 'noreply@example.com', value_type: 'string', group: 'email' },
  { key: 'email.contact_address', value: 'contact@example.com', value_type: 'string', group: 'email' },
  { key: 'email.send_welcome_email', value: 'true', value_type: 'boolean', group: 'email' },

  { key: 'social.facebook', value: 'https://facebook.com/amazonclone', value_type: 'string', group: 'social' },
  { key: 'social.twitter', value: 'https://twitter.com/amazonclone', value_type: 'string', group: 'social' },
  { key: 'social.instagram', value: 'https://instagram.com/amazonclone', value_type: 'string', group: 'social' },

  { key: 'security.password_min_length', value: '8', value_type: 'integer', group: 'security' },
  { key: 'security.session_timeout', value: '86400', value_type: 'integer', group: 'security' },
  { key: 'security.login_attempts', value: '5', value_type: 'integer', group: 'security' }
].each do |config|
  SystemConfig.create!(
    key: config[:key],
    value: config[:value],
    value_type: config[:value_type],
    group: config[:group],
    description: "#{config[:key]} の設定",
    is_editable: true,
    is_visible: true,
    updated_by: admin,
    last_updated_at: Time.current
  )
end

# イベントの作成
puts "Creating events..."
2.times do |i|
  event = Event.create!(
    name: "#{['夏の', '冬の', '春の', '秋の'].sample}#{['セール', 'キャンペーン', 'フェア', 'フェスティバル'].sample}",
    description: Faker::Lorem.paragraph,
    start_date: Time.current - rand(0..7).days,
    end_date: Time.current + rand(7..30).days,
    is_active: true,
    event_type: ['sale', 'promotion', 'holiday', 'product_launch', 'clearance'].sample,
    banner_image_url: "https://example.com/banners/event#{i+1}.jpg",
    landing_page_url: "https://example.com/events/event#{i+1}",
    is_featured: i == 0,
    priority: i == 0 ? 10 : 5,
    created_by: admin,
    status: 'active',
    is_recurring: false,
    timezone: 'Asia/Tokyo'
  )

  # イベントログの作成
  EventLog.create!(
    event_name: "event.created",
    event_type: 'system',
    loggable: event,
    details: { event_id: event.id, event_name: event.name }.to_json,
    severity: 'info',
    is_success: true,
    source: 'admin'
  )
end

# カートの作成
puts "Creating carts..."
3.times do |i|
  user = users[i]

  cart = Cart.create!(
    user: user,
    session_id: SecureRandom.hex(16),
    status: ['active', 'abandoned', 'converted'].sample,
    last_activity_at: Time.current - rand(0..30).days,
    is_guest: false,
    items_count: 0,
    total_amount: 0,
    discount_amount: 0,
    tax_amount: 0,
    shipping_amount: 0,
    final_amount: 0,
    currency: 'JPY'
  )

  # カートアイテムの追加
  rand(1..3).times do
    product = products.sample
    quantity = rand(1..3)
    unit_price = product.price

    CartItem.create!(
      cart: cart,
      product: product,
      quantity: quantity,
      unit_price: unit_price,
      total_price: unit_price * quantity,
      is_saved_for_later: false,
      is_gift: rand < 0.2,
      has_gift_wrap: rand < 0.1,
      status: 'in_stock',
      added_at: Time.current - rand(0..7).days,
      last_modified_at: Time.current - rand(0..3).days
    )
  end

  # カートの合計金額を更新
  cart.update_totals
  cart.save
end

# ウィッシュリストの作成
puts "Creating wishlists..."
3.times do |i|
  user = users[i]

  wishlist = Wishlist.create!(
    user: user,
    name: "#{user.first_name}のウィッシュリスト",
    description: Faker::Lorem.sentence,
    is_public: rand < 0.3,
    is_default: true,
    sharing_token: SecureRandom.urlsafe_base64(8),
    items_count: 0,
    last_modified_at: Time.current,
    status: 'active'
  )

  # ウィッシュリストアイテムの追加
  rand(2..5).times do
    product = products.sample

    # ウィッシュリストに商品を追加するメソッドを呼び出す
    wishlist.add_item(product, quantity: rand(1..2))
  end
end

# 最近閲覧した商品の作成
puts "Creating recently viewed products..."
users.each do |user|
  rand(3..8).times do
    product = products.sample

    RecentlyViewed.create!(
      user: user,
      product: product,
      view_count: rand(1..5),
      last_viewed_at: Time.current - rand(0..14).days,
      view_duration: rand(10..300),
      source: ['search', 'recommendation', 'category', 'direct'].sample,
      device_type: ['desktop', 'mobile', 'tablet'].sample,
      session_id: SecureRandom.hex(16),
      added_to_cart: rand < 0.3,
      added_to_wishlist: rand < 0.2,
      purchased: rand < 0.1
    )
  end
end

# 検索履歴の作成
puts "Creating search history..."
users.each do |user|
  rand(5..10).times do
    query = Faker::Commerce.product_name.split(' ').sample(rand(1..3)).join(' ')
    results_count = rand(0..100)

    search = SearchHistory.create!(
      user: user,
      query: query,
      filters: { category: rand(1..10), price_min: rand(1000..5000), price_max: rand(5001..10000) }.to_json,
      sort_by: ['relevance', 'price_asc', 'price_desc', 'newest', 'rating'].sample,
      results_count: results_count,
      has_clicked_result: results_count > 0 && rand < 0.7,
      category_path: "category/#{rand(1..10)}/subcategory/#{rand(1..5)}",
      device_type: ['desktop', 'mobile', 'tablet'].sample,
      browser: ['chrome', 'firefox', 'safari', 'edge'].sample,
      ip_address: Faker::Internet.ip_v4_address,
      session_id: SecureRandom.hex(16),
      search_duration: rand(0.1..5.0).round(2),
      is_voice_search: rand < 0.1,
      is_image_search: rand < 0.1,
      is_autocomplete: rand < 0.3,
      created_at: Time.current - rand(0..30).days
    )

    # 検索結果をクリックした場合
    if search.has_clicked_result
      search.update(
        position_clicked: rand(1..10),
        product_clicked: products.sample
      )
    end
  end
end

# 通知の作成
puts "Creating notifications..."
users.each do |user|
  rand(3..8).times do
    notification_type = ['order_status', 'price_drop', 'back_in_stock', 'shipping_update', 'payment_update', 'review_request', 'promotion', 'system'].sample

    title = case notification_type
            when 'order_status'
              "注文状況の更新"
            when 'price_drop'
              "価格が下がりました"
            when 'back_in_stock'
              "在庫が戻りました"
            when 'shipping_update'
              "配送状況の更新"
            when 'payment_update'
              "支払い状況の更新"
            when 'review_request'
              "レビューのお願い"
            when 'promotion'
              "新しいプロモーション"
            when 'system'
              "システムからのお知らせ"
            end

    Notification.create!(
      user: user,
      notification_type: notification_type,
      title: title,
      content: Faker::Lorem.paragraph,
      icon: ['info', 'success', 'warning', 'error'].sample,
      url: Faker::Internet.url,
      is_read: rand < 0.5,
      read_at: rand < 0.5 ? Time.current - rand(0..7).days : nil,
      is_actionable: rand < 0.7,
      action_text: rand < 0.7 ? "詳細を見る" : nil,
      action_url: rand < 0.7 ? Faker::Internet.url : nil,
      priority: [0, 1, 2].sample,
      delivery_method: ['in_app', 'email', 'sms', 'push'].sample,
      is_sent: true,
      sent_at: Time.current - rand(0..14).days,
      created_at: Time.current - rand(0..14).days
    )
  end
end

puts "Seller and other seed data created successfully!"
