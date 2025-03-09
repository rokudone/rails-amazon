# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Clear existing data
puts "Clearing existing data..."
# 商品関連データの削除
puts "Clearing product data..."
ProductTag.destroy_all
Tag.destroy_all
ProductAccessory.destroy_all
ProductBundleItem.destroy_all
ProductBundle.destroy_all
PriceHistory.destroy_all
ProductSpecification.destroy_all
ProductDescription.destroy_all
ProductDocument.destroy_all
ProductVideo.destroy_all
ProductImage.destroy_all
ProductAttribute.destroy_all
ProductVariant.destroy_all
Product.destroy_all
SubCategory.destroy_all
Category.destroy_all
Brand.destroy_all

# ユーザー関連データの削除
puts "Clearing user data..."
UserActivity.destroy_all
UserPermission.destroy_all
UserReward.destroy_all
UserSubscription.destroy_all
UserSession.destroy_all
UserDevice.destroy_all
UserLog.destroy_all
UserPreference.destroy_all
PaymentMethod.destroy_all
Address.destroy_all
Profile.destroy_all
User.destroy_all

# レビュー・マーケティング関連データの削除
puts "Clearing review and marketing data..."
ReviewVote.destroy_all
ReviewImage.destroy_all
Review.destroy_all
Rating.destroy_all
Answer.destroy_all
Question.destroy_all
ReferralProgram.destroy_all
AffiliateProgram.destroy_all
Advertisement.destroy_all
Campaign.destroy_all
Discount.destroy_all
Coupon.destroy_all
PromotionRule.destroy_all
Promotion.destroy_all

# セラー・その他データの削除
puts "Clearing seller and other data..."
SellerPerformance.destroy_all
SellerPolicy.destroy_all
SellerTransaction.destroy_all
SellerDocument.destroy_all
SellerProduct.destroy_all
SellerRating.destroy_all
Seller.destroy_all
Region.destroy_all
Country.destroy_all
Currency.destroy_all
SystemConfig.destroy_all
EventLog.destroy_all
Event.destroy_all
CartItem.destroy_all
Cart.destroy_all
Wishlist.destroy_all
RecentlyViewed.destroy_all
SearchHistory.destroy_all
Notification.destroy_all

puts "Creating admin user..."
admin = User.create!(
  email: "admin@example.com",
  password: "password123",
  first_name: "Admin",
  last_name: "User",
  phone_number: "12025550123",
  active: true,
  last_login_at: Time.current
)

puts "Creating admin profile..."
Profile.create!(
  user: admin,
  gender: "prefer_not_to_say",
  bio: "System administrator",
  occupation: "Administrator",
  company: "Amazon Clone Inc."
)

puts "Creating admin preferences..."
UserPreference.create!(
  user: admin,
  email_notifications: true,
  sms_notifications: true,
  push_notifications: true,
  language: "en",
  currency: "USD",
  timezone: "UTC",
  two_factor_auth: true
)

puts "Creating admin permissions..."
UserPermission.create!(
  user: admin,
  permission_name: "admin",
  action: "all",
  is_allowed: true,
  granted_at: Time.current,
  granted_by: "System"
)

puts "Creating regular users..."
5.times do |i|
  puts "Creating user #{i+1}..."
  user = User.create!(
    email: "user#{i+1}@example.com",
    password: "password123",
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    phone_number: Faker::PhoneNumber.cell_phone_in_e164.gsub(/\+/, ''),
    active: true,
    last_login_at: Faker::Time.backward(days: 14)
  )

  puts "Creating profile for user #{i+1}..."
  Profile.create!(
    user: user,
    birth_date: Faker::Date.birthday(min_age: 18, max_age: 65),
    gender: %w[male female other prefer_not_to_say].sample,
    bio: Faker::Lorem.paragraph(sentence_count: 3),
    avatar: "https://example.com/avatars/user#{i+1}.jpg",
    website: Faker::Internet.url,
    occupation: Faker::Job.title,
    company: Faker::Company.name
  )

  puts "Creating preferences for user #{i+1}..."
  UserPreference.create!(
    user: user,
    email_notifications: [true, false].sample,
    sms_notifications: [true, false].sample,
    push_notifications: [true, false].sample,
    language: %w[en ja fr es de].sample,
    currency: %w[USD EUR JPY GBP].sample,
    timezone: ActiveSupport::TimeZone.all.sample.name,
    two_factor_auth: [true, false].sample
  )

  puts "Creating addresses for user #{i+1}..."
  2.times do |j|
    Address.create!(
      user: user,
      address_type: %w[billing shipping both].sample,
      name: user.first_name + " " + user.last_name,
      address_line1: Faker::Address.street_address,
      address_line2: j.even? ? Faker::Address.secondary_address : nil,
      city: Faker::Address.city,
      state: Faker::Address.state,
      postal_code: Faker::Address.zip_code,
      country: Faker::Address.country_code,
      phone_number: Faker::PhoneNumber.cell_phone_in_e164.gsub(/\+/, ''),
      is_default: j.zero?
    )
  end

  puts "Creating payment methods for user #{i+1}..."
  2.times do |j|
    PaymentMethod.create!(
      user: user,
      payment_type: %w[credit_card debit_card bank_account paypal].sample,
      provider: ['Visa', 'MasterCard', 'American Express', 'PayPal', 'Bank Transfer'].sample,
      account_number: "****#{Faker::Number.number(digits: 4)}",
      expiry_date: "#{format('%02d', rand(1..12))}/#{(Time.current.year + rand(1..5)).to_s[-2..-1]}",
      name_on_card: user.first_name + " " + user.last_name,
      is_default: j.zero?
    )
  end

  puts "Creating logs for user #{i+1}..."
  5.times do
    UserLog.create!(
      user: user,
      action: ['login', 'logout', 'password_reset', 'profile_update', 'payment_method_added', 'address_added'].sample,
      ip_address: Faker::Internet.ip_v4_address,
      user_agent: "Mozilla/5.0 (#{['Windows NT 10.0', 'Macintosh', 'Linux'].sample}; rv:#{rand(70..100)}.0) Gecko/20100101 Firefox/#{rand(70..100)}.0",
      details: { timestamp: Faker::Time.backward(days: 30).iso8601 }.to_json,
      created_at: Faker::Time.backward(days: 30)
    )
  end

  puts "Creating devices for user #{i+1}..."
  2.times do
    UserDevice.create!(
      user: user,
      device_type: %w[mobile tablet desktop].sample,
      device_token: SecureRandom.uuid,
      device_id: SecureRandom.uuid,
      os_type: %w[ios android windows macos].sample,
      os_version: "#{rand(8..15)}.#{rand(0..9)}.#{rand(0..9)}",
      app_version: "#{rand(1..5)}.#{rand(0..9)}.#{rand(0..9)}",
      last_used_at: Faker::Time.backward(days: 30),
      is_active: [true, false].sample
    )
  end

  puts "Creating sessions for user #{i+1}..."
  3.times do |j|
    UserSession.create!(
      user: user,
      session_token: SecureRandom.hex(32),
      ip_address: Faker::Internet.ip_v4_address,
      user_agent: "Mozilla/5.0 (#{['Windows NT 10.0', 'Macintosh', 'Linux'].sample}; rv:#{rand(70..100)}.0) Gecko/20100101 Firefox/#{rand(70..100)}.0",
      last_activity_at: j.zero? ? Time.current : Faker::Time.backward(days: 7),
      expires_at: j.zero? ? 24.hours.from_now : Faker::Time.backward(days: 1),
      is_active: j.zero?
    )
  end

  if i < 3 # Only create subscriptions for some users
    puts "Creating subscriptions for user #{i+1}..."
    UserSubscription.create!(
      user: user,
      subscription_type: %w[prime music video].sample,
      status: %w[active trial].sample,
      start_date: Faker::Time.backward(days: 90),
      end_date: Faker::Time.forward(days: 90),
      amount: Faker::Number.decimal(l_digits: 2, r_digits: 2),
      billing_period: %w[monthly annual].sample,
      payment_method_id: user.payment_methods.first.id.to_s,
      last_payment_date: Faker::Time.backward(days: 30),
      next_payment_date: Faker::Time.forward(days: 30),
      auto_renew: true
    )
  end

  puts "Creating rewards for user #{i+1}..."
  2.times do
    UserReward.create!(
      user: user,
      reward_type: %w[points coupon discount].sample,
      status: %w[active expired redeemed].sample,
      points: rand(100..10000),
      amount: Faker::Number.decimal(l_digits: 2, r_digits: 2),
      code: Faker::Alphanumeric.alphanumeric(number: 10).upcase,
      description: Faker::Marketing.buzzwords,
      issued_at: Faker::Time.backward(days: 30),
      expires_at: Faker::Time.forward(days: 90),
      redeemed_at: [nil, Faker::Time.backward(days: 15)].sample
    )
  end

  puts "Creating permissions for user #{i+1}..."
  UserPermission.create!(
    user: user,
    permission_name: %w[buyer seller].sample,
    resource_type: ['Product', 'Order', 'Review'].sample,
    resource_id: rand(1..100),
    action: %w[read write].sample,
    is_allowed: true,
    granted_at: Faker::Time.backward(days: 30),
    granted_by: "System"
  )

  puts "Creating activities for user #{i+1}..."
  10.times do
    activity_type = %w[login logout search view purchase review wishlist cart].sample

    UserActivity.create!(
      user: user,
      activity_type: activity_type,
      action: ['add', 'remove', 'update', 'view', 'click', 'submit'].sample,
      ip_address: Faker::Internet.ip_v4_address,
      user_agent: "Mozilla/5.0 (#{['Windows NT 10.0', 'Macintosh', 'Linux'].sample}; rv:#{rand(70..100)}.0) Gecko/20100101 Firefox/#{rand(70..100)}.0",
      resource_type: activity_type == 'view' ? 'Product' : (activity_type == 'purchase' ? 'Order' : nil),
      resource_id: rand(1..1000),
      details: { timestamp: Faker::Time.backward(days: 30).iso8601 }.to_json,
      activity_time: Faker::Time.backward(days: 30),
      created_at: Faker::Time.backward(days: 30)
    )
  end
end

# 商品関連データの作成
puts "\n=== Creating Product Data ==="

# カテゴリ階層の作成
puts "Creating categories..."
electronics = Category.create!(
  name: "Electronics",
  slug: "electronics",
  description: "Electronic devices and gadgets",
  is_active: true
)

computers = Category.create!(
  name: "Computers",
  slug: "computers",
  description: "Desktop and laptop computers",
  parent: electronics,
  is_active: true
)

smartphones = Category.create!(
  name: "Smartphones",
  slug: "smartphones",
  description: "Mobile phones and accessories",
  parent: electronics,
  is_active: true
)

home_appliances = Category.create!(
  name: "Home Appliances",
  slug: "home-appliances",
  description: "Appliances for your home",
  is_active: true
)

kitchen = Category.create!(
  name: "Kitchen",
  slug: "kitchen",
  description: "Kitchen appliances and gadgets",
  parent: home_appliances,
  is_active: true
)

clothing = Category.create!(
  name: "Clothing",
  slug: "clothing",
  description: "Clothes, shoes, and accessories",
  is_active: true
)

mens_clothing = Category.create!(
  name: "Men's Clothing",
  slug: "mens-clothing",
  description: "Clothing for men",
  parent: clothing,
  is_active: true
)

womens_clothing = Category.create!(
  name: "Women's Clothing",
  slug: "womens-clothing",
  description: "Clothing for women",
  parent: clothing,
  is_active: true
)

books = Category.create!(
  name: "Books",
  slug: "books",
  description: "Books, e-books, and audiobooks",
  is_active: true
)

# サブカテゴリの作成
puts "Creating subcategories..."
# コンピュータのサブカテゴリ
SubCategory.create!(
  category: computers,
  name: "Laptops",
  slug: "laptops",
  description: "Portable computers",
  is_active: true
)

SubCategory.create!(
  category: computers,
  name: "Desktops",
  slug: "desktops",
  description: "Desktop computers",
  is_active: true
)

SubCategory.create!(
  category: computers,
  name: "Computer Accessories",
  slug: "computer-accessories",
  description: "Accessories for computers",
  is_active: true
)

# スマートフォンのサブカテゴリ
SubCategory.create!(
  category: smartphones,
  name: "Android Phones",
  slug: "android-phones",
  description: "Phones running Android OS",
  is_active: true
)

SubCategory.create!(
  category: smartphones,
  name: "iPhones",
  slug: "iphones",
  description: "Apple iPhones",
  is_active: true
)

SubCategory.create!(
  category: smartphones,
  name: "Phone Cases",
  slug: "phone-cases",
  description: "Cases for smartphones",
  is_active: true
)

# キッチンのサブカテゴリ
SubCategory.create!(
  category: kitchen,
  name: "Blenders",
  slug: "blenders",
  description: "Blenders and food processors",
  is_active: true
)

SubCategory.create!(
  category: kitchen,
  name: "Coffee Makers",
  slug: "coffee-makers",
  description: "Coffee and espresso machines",
  is_active: true
)

# 男性服のサブカテゴリ
SubCategory.create!(
  category: mens_clothing,
  name: "T-Shirts",
  slug: "mens-tshirts",
  description: "T-shirts for men",
  is_active: true
)

SubCategory.create!(
  category: mens_clothing,
  name: "Jeans",
  slug: "mens-jeans",
  description: "Jeans for men",
  is_active: true
)

# 女性服のサブカテゴリ
SubCategory.create!(
  category: womens_clothing,
  name: "Dresses",
  slug: "womens-dresses",
  description: "Dresses for women",
  is_active: true
)

SubCategory.create!(
  category: womens_clothing,
  name: "Tops",
  slug: "womens-tops",
  description: "Tops for women",
  is_active: true
)

# 書籍のサブカテゴリ
SubCategory.create!(
  category: books,
  name: "Fiction",
  slug: "fiction",
  description: "Fiction books",
  is_active: true
)

SubCategory.create!(
  category: books,
  name: "Non-Fiction",
  slug: "non-fiction",
  description: "Non-fiction books",
  is_active: true
)

# ブランドの作成
puts "Creating brands..."
apple = Brand.create!(
  name: "Apple",
  description: "American technology company that designs, develops, and sells consumer electronics, computer software, and online services.",
  logo: "https://example.com/logos/apple.png",
  website: "https://www.apple.com",
  country_of_origin: "United States",
  year_established: 1976,
  is_active: true
)

samsung = Brand.create!(
  name: "Samsung",
  description: "South Korean multinational conglomerate company that manufactures electronic components and consumer electronics.",
  logo: "https://example.com/logos/samsung.png",
  website: "https://www.samsung.com",
  country_of_origin: "South Korea",
  year_established: 1938,
  is_active: true
)

sony = Brand.create!(
  name: "Sony",
  description: "Japanese multinational conglomerate corporation that manufactures electronic products.",
  logo: "https://example.com/logos/sony.png",
  website: "https://www.sony.com",
  country_of_origin: "Japan",
  year_established: 1946,
  is_active: true
)

dell = Brand.create!(
  name: "Dell",
  description: "American multinational computer technology company that develops, sells, repairs, and supports computers and related products and services.",
  logo: "https://example.com/logos/dell.png",
  website: "https://www.dell.com",
  country_of_origin: "United States",
  year_established: 1984,
  is_active: true
)

nike = Brand.create!(
  name: "Nike",
  description: "American multinational corporation that designs, develops, manufactures, and markets footwear, apparel, equipment, accessories, and services.",
  logo: "https://example.com/logos/nike.png",
  website: "https://www.nike.com",
  country_of_origin: "United States",
  year_established: 1964,
  is_active: true
)

# サンプル商品の作成
puts "Creating sample products..."

# iPhone
iphone = Product.create!(
  name: "iPhone 15 Pro",
  short_description: "Apple's latest flagship smartphone with advanced features",
  price: 999.99,
  sku: "APPL-IP15PRO-001",
  upc: "123456789012",
  manufacturer: "Apple Inc.",
  brand: apple,
  category: smartphones,
  is_active: true,
  is_featured: true,
  published_at: Time.current
)

# iPhone のバリアント
["Space Black", "Silver", "Gold", "Deep Purple"].each do |color|
  ["128GB", "256GB", "512GB", "1TB"].each do |storage|
    price_modifier = case storage
                     when "128GB" then 0
                     when "256GB" then 100
                     when "512GB" then 300
                     when "1TB" then 500
                     end

    ProductVariant.create!(
      product: iphone,
      sku: "APPL-IP15PRO-#{color.parameterize}-#{storage.parameterize}",
      name: "iPhone 15 Pro - #{color} #{storage}",
      price: iphone.price + price_modifier,
      color: color,
      size: storage,
      is_active: true
    )
  end
end

# iPhone の画像
ProductImage.create!(
  product: iphone,
  image_url: "https://example.com/products/iphone15pro/main.jpg",
  alt_text: "iPhone 15 Pro - Main Image",
  position: 0,
  is_primary: true
)

ProductImage.create!(
  product: iphone,
  image_url: "https://example.com/products/iphone15pro/angle.jpg",
  alt_text: "iPhone 15 Pro - Angle View",
  position: 1
)

ProductImage.create!(
  product: iphone,
  image_url: "https://example.com/products/iphone15pro/back.jpg",
  alt_text: "iPhone 15 Pro - Back View",
  position: 2
)

# iPhone の説明
ProductDescription.create!(
  product: iphone,
  full_description: "The iPhone 15 Pro features a stunning Super Retina XDR display, A17 Pro chip, and a professional camera system. With its sleek design and powerful performance, it's the ultimate iPhone experience.",
  features: "- A17 Pro chip for lightning-fast performance\n- Pro camera system with 48MP main camera\n- Super Retina XDR display with ProMotion\n- Ceramic Shield front cover\n- Surgical-grade stainless steel design\n- Face ID for secure authentication\n- 5G capable for ultra-fast downloads and streaming",
  care_instructions: "- Use a soft, slightly damp, lint-free cloth to clean\n- Avoid using abrasive cleaning solvents\n- Keep away from liquids and extreme temperatures",
  warranty_info: "One-year limited warranty included. AppleCare+ available for extended coverage.",
  return_policy: "Return within 14 days of purchase for a full refund. Product must be in original condition with all accessories."
)

# iPhone の仕様
[
  ["Display", "6.1-inch Super Retina XDR", "inches"],
  ["Resolution", "2556 x 1179", "pixels"],
  ["Processor", "A17 Pro chip", ""],
  ["RAM", "8", "GB"],
  ["Storage", "128GB to 1TB", ""],
  ["Rear Camera", "48MP main, 12MP ultra wide, 12MP telephoto", ""],
  ["Front Camera", "12", "MP"],
  ["Battery", "Up to 23 hours video playback", ""],
  ["Operating System", "iOS 17", ""],
  ["Dimensions", "146.7 x 71.5 x 8.3", "mm"],
  ["Weight", "187", "g"],
  ["Water Resistance", "IP68", ""]
].each_with_index do |spec, index|
  ProductSpecification.create!(
    product: iphone,
    name: spec[0],
    value: spec[1],
    unit: spec[2],
    position: index
  )
end

# iPhone の属性
[
  ["Color Options", "Space Black, Silver, Gold, Deep Purple"],
  ["Storage Options", "128GB, 256GB, 512GB, 1TB"],
  ["Connectivity", "5G, Wi-Fi 6E, Bluetooth 5.3, NFC"],
  ["Biometric Authentication", "Face ID"],
  ["Charging", "USB-C, MagSafe, Qi wireless"]
].each_with_index do |attr, index|
  ProductAttribute.create!(
    product: iphone,
    name: attr[0],
    value: attr[1],
    is_filterable: true,
    is_searchable: true
  )
end

# MacBook
macbook = Product.create!(
  name: "MacBook Pro 16-inch",
  short_description: "Powerful laptop for professionals with M2 Pro or M2 Max chip",
  price: 2499.99,
  sku: "APPL-MBP16-001",
  upc: "123456789013",
  manufacturer: "Apple Inc.",
  brand: apple,
  category: computers,
  is_active: true,
  is_featured: true,
  published_at: Time.current
)

# MacBook のバリアント
["Space Gray", "Silver"].each do |color|
  ["M2 Pro/16GB/512GB", "M2 Pro/16GB/1TB", "M2 Max/32GB/1TB", "M2 Max/64GB/2TB"].each do |config|
    price_modifier = case config
                     when "M2 Pro/16GB/512GB" then 0
                     when "M2 Pro/16GB/1TB" then 200
                     when "M2 Max/32GB/1TB" then 700
                     when "M2 Max/64GB/2TB" then 1400
                     end

    ProductVariant.create!(
      product: macbook,
      sku: "APPL-MBP16-#{color.parameterize}-#{config.parameterize}",
      name: "MacBook Pro 16-inch - #{color} #{config}",
      price: macbook.price + price_modifier,
      color: color,
      material: "Aluminum",
      is_active: true
    )
  end
end

# Samsung Galaxy
galaxy = Product.create!(
  name: "Samsung Galaxy S23 Ultra",
  short_description: "Samsung's premium smartphone with S Pen and advanced camera system",
  price: 1199.99,
  sku: "SMSNG-GS23U-001",
  upc: "123456789014",
  manufacturer: "Samsung Electronics",
  brand: samsung,
  category: smartphones,
  is_active: true,
  is_featured: false,
  published_at: Time.current
)

# Dell XPS
dell_xps = Product.create!(
  name: "Dell XPS 15",
  short_description: "Premium 15-inch laptop with InfinityEdge display",
  price: 1899.99,
  sku: "DELL-XPS15-001",
  upc: "123456789015",
  manufacturer: "Dell Inc.",
  brand: dell,
  category: computers,
  is_active: true,
  is_featured: false,
  published_at: Time.current
)

# タグの作成
puts "Creating tags..."
["New Arrival", "Best Seller", "Limited Edition", "Sale", "Premium", "Eco-Friendly"].each do |tag_name|
  Tag.create!(name: tag_name, description: "Products tagged as #{tag_name}")
end

# 商品にタグを付ける
best_seller_tag = Tag.find_by(name: "Best Seller")
new_arrival_tag = Tag.find_by(name: "New Arrival")
premium_tag = Tag.find_by(name: "Premium")

ProductTag.create!(product: iphone, tag: new_arrival_tag)
ProductTag.create!(product: iphone, tag: premium_tag)
ProductTag.create!(product: macbook, tag: premium_tag)
ProductTag.create!(product: macbook, tag: best_seller_tag)
ProductTag.create!(product: galaxy, tag: new_arrival_tag)

# バンドルの作成
puts "Creating product bundles..."
apple_bundle = ProductBundle.create!(
  name: "Apple Pro Bundle",
  description: "Get the ultimate Apple experience with this bundle of premium products",
  price: 3999.99,
  discount_percentage: 15,
  start_date: Time.current - 7.days,
  end_date: Time.current + 30.days,
  is_active: true
)

# バンドルに商品を追加
ProductBundleItem.create!(product_bundle: apple_bundle, product: iphone, quantity: 1)
ProductBundleItem.create!(product_bundle: apple_bundle, product: macbook, quantity: 1)

# 在庫・注文関連データの作成
puts "\n=== Creating Inventory and Order Data ==="

# 倉庫データの作成
puts "Creating warehouses..."
main_warehouse = Warehouse.create!(
  name: "東京メイン倉庫",
  code: "TKY-MAIN",
  address: "東京都江東区有明1-1-1",
  city: "江東区",
  state: "東京都",
  postal_code: "135-0063",
  country: "日本",
  phone: "03-1234-5678",
  email: "warehouse-tokyo@example.com",
  latitude: 35.6372,
  longitude: 139.7965,
  active: true,
  capacity: 50000,
  warehouse_type: "main",
  description: "東京の主要倉庫",
  manager_name: "佐藤一郎"
)

osaka_warehouse = Warehouse.create!(
  name: "大阪支店倉庫",
  code: "OSK-MAIN",
  address: "大阪府大阪市住之江区南港北2-1-10",
  city: "大阪市",
  state: "大阪府",
  postal_code: "559-0034",
  country: "日本",
  phone: "06-1234-5678",
  email: "warehouse-osaka@example.com",
  latitude: 34.6431,
  longitude: 135.4301,
  active: true,
  capacity: 30000,
  warehouse_type: "regional",
  description: "関西地方の主要倉庫",
  manager_name: "田中次郎"
)

fukuoka_warehouse = Warehouse.create!(
  name: "福岡支店倉庫",
  code: "FUK-MAIN",
  address: "福岡県福岡市博多区博多駅前2-1-1",
  city: "福岡市",
  state: "福岡県",
  postal_code: "812-0011",
  country: "日本",
  phone: "092-123-4567",
  email: "warehouse-fukuoka@example.com",
  latitude: 33.5902,
  longitude: 130.4017,
  active: true,
  capacity: 20000,
  warehouse_type: "regional",
  description: "九州地方の主要倉庫",
  manager_name: "山田三郎"
)

# 在庫データの作成
puts "Creating inventory data..."
# iPhoneの在庫
iphone.product_variants.each do |variant|
  Inventory.create!(
    product: iphone,
    product_variant: variant,
    warehouse: main_warehouse,
    quantity: rand(50..200),
    reserved_quantity: rand(0..20),
    minimum_stock_level: 20,
    maximum_stock_level: 300,
    reorder_point: 50,
    sku: variant.sku,
    location_in_warehouse: "A-#{rand(1..5)}-#{rand(1..10)}-#{rand(1..20)}",
    last_restock_date: rand(1..30).days.ago,
    status: "active",
    unit_cost: variant.price * 0.7
  )

  # 大阪倉庫にも在庫を作成（一部のバリアントのみ）
  if rand < 0.7
    Inventory.create!(
      product: iphone,
      product_variant: variant,
      warehouse: osaka_warehouse,
      quantity: rand(20..100),
      reserved_quantity: rand(0..10),
      minimum_stock_level: 10,
      maximum_stock_level: 150,
      reorder_point: 30,
      sku: "OSK-#{variant.sku}",
      location_in_warehouse: "B-#{rand(1..3)}-#{rand(1..8)}-#{rand(1..15)}",
      last_restock_date: rand(1..30).days.ago,
      status: "active",
      unit_cost: variant.price * 0.7
    )
  end
end

# MacBookの在庫
macbook.product_variants.each do |variant|
  Inventory.create!(
    product: macbook,
    product_variant: variant,
    warehouse: main_warehouse,
    quantity: rand(10..50),
    reserved_quantity: rand(0..5),
    minimum_stock_level: 5,
    maximum_stock_level: 100,
    reorder_point: 15,
    sku: variant.sku,
    location_in_warehouse: "C-#{rand(1..3)}-#{rand(1..5)}-#{rand(1..10)}",
    last_restock_date: rand(1..30).days.ago,
    status: "active",
    unit_cost: variant.price * 0.75
  )
end

# Galaxyの在庫
Inventory.create!(
  product: galaxy,
  warehouse: main_warehouse,
  quantity: rand(30..120),
  reserved_quantity: rand(0..15),
  minimum_stock_level: 15,
  maximum_stock_level: 200,
  reorder_point: 40,
  sku: galaxy.sku,
  location_in_warehouse: "A-6-#{rand(1..10)}-#{rand(1..20)}",
  last_restock_date: rand(1..30).days.ago,
  status: "active",
  unit_cost: galaxy.price * 0.65
)

# Dell XPSの在庫
Inventory.create!(
  product: dell_xps,
  warehouse: main_warehouse,
  quantity: rand(5..30),
  reserved_quantity: rand(0..3),
  minimum_stock_level: 5,
  maximum_stock_level: 50,
  reorder_point: 10,
  sku: dell_xps.sku,
  location_in_warehouse: "C-4-#{rand(1..5)}-#{rand(1..10)}",
  last_restock_date: rand(1..30).days.ago,
  status: "active",
  unit_cost: dell_xps.price * 0.7
)

# 在庫移動の作成
puts "Creating stock movements..."
# 入庫記録
StockMovement.create!(
  inventory: Inventory.where(warehouse: main_warehouse).sample,
  destination_warehouse: main_warehouse,
  quantity: rand(10..50),
  movement_type: "inbound",
  reference_number: "PO-#{Date.today.strftime('%Y%m%d')}-#{rand(1000..9999)}",
  reason: "定期入荷",
  status: "completed",
  completed_at: rand(1..10).days.ago,
  created_by: "system",
  unit_cost: rand(100..1000)
)

# 出庫記録
StockMovement.create!(
  inventory: Inventory.where(warehouse: main_warehouse).sample,
  source_warehouse: main_warehouse,
  quantity: rand(1..5),
  movement_type: "outbound",
  reference_number: "SO-#{Date.today.strftime('%Y%m%d')}-#{rand(1000..9999)}",
  reason: "注文出荷",
  status: "completed",
  completed_at: rand(1..5).days.ago,
  created_by: "system"
)

# 倉庫間移動
if Inventory.where(warehouse: osaka_warehouse).exists?
  inventory = Inventory.where(warehouse: main_warehouse).sample
  StockMovement.create!(
    inventory: inventory,
    source_warehouse: main_warehouse,
    destination_warehouse: osaka_warehouse,
    quantity: rand(5..20),
    movement_type: "transfer",
    reference_number: "TR-#{Date.today.strftime('%Y%m%d')}-#{rand(1000..9999)}",
    reason: "倉庫間移動",
    status: "completed",
    completed_at: rand(1..15).days.ago,
    created_by: "system",
    unit_cost: inventory.unit_cost
  )
end

# 注文ステータスの作成
puts "Creating order statuses..."
OrderStatus.create!(
  name: "保留中",
  code: "pending",
  description: "注文は作成されましたが、まだ処理されていません",
  display_order: 1,
  color_code: "#ffc107",
  is_active: true,
  is_default: true,
  is_cancellable: true,
  is_returnable: false,
  requires_shipping: true,
  requires_payment: true
)

OrderStatus.create!(
  name: "処理中",
  code: "processing",
  description: "注文は処理中です",
  display_order: 2,
  color_code: "#17a2b8",
  is_active: true,
  is_default: false,
  is_cancellable: true,
  is_returnable: false,
  requires_shipping: true,
  requires_payment: true
)

OrderStatus.create!(
  name: "出荷済み",
  code: "shipped",
  description: "注文は出荷されました",
  display_order: 3,
  color_code: "#6f42c1",
  is_active: true,
  is_default: false,
  is_cancellable: false,
  is_returnable: false,
  requires_shipping: true,
  requires_payment: true
)

OrderStatus.create!(
  name: "配達済み",
  code: "delivered",
  description: "注文は配達されました",
  display_order: 4,
  color_code: "#28a745",
  is_active: true,
  is_default: false,
  is_cancellable: false,
  is_returnable: true,
  requires_shipping: true,
  requires_payment: true
)

OrderStatus.create!(
  name: "完了",
  code: "completed",
  description: "注文は完了しました",
  display_order: 5,
  color_code: "#28a745",
  is_active: true,
  is_default: false,
  is_cancellable: false,
  is_returnable: false,
  requires_shipping: true,
  requires_payment: true
)

OrderStatus.create!(
  name: "キャンセル",
  code: "cancelled",
  description: "注文はキャンセルされました",
  display_order: 6,
  color_code: "#dc3545",
  is_active: true,
  is_default: false,
  is_cancellable: false,
  is_returnable: false,
  requires_shipping: false,
  requires_payment: false
)

OrderStatus.create!(
  name: "返品済み",
  code: "returned",
  description: "注文は返品されました",
  display_order: 7,
  color_code: "#fd7e14",
  is_active: true,
  is_default: false,
  is_cancellable: false,
  is_returnable: false,
  requires_shipping: false,
  requires_payment: false
)

OrderStatus.create!(
  name: "返金済み",
  code: "refunded",
  description: "注文は返金されました",
  display_order: 8,
  color_code: "#20c997",
  is_active: true,
  is_default: false,
  is_cancellable: false,
  is_returnable: false,
  requires_shipping: false,
  requires_payment: false
)

# 追加のシードデータを読み込む
puts "\n=== Loading additional seed data ==="

# レビュー・マーケティング関連データの読み込み
load File.join(Rails.root, 'db', 'seeds', 'reviews_marketing.rb')

# セラー・その他データの読み込み
load File.join(Rails.root, 'db', 'seeds', 'sellers_others.rb')

puts "All seed data created successfully!"
