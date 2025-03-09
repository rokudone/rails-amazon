# レビュー・マーケティング関連データの作成
puts "\n=== Creating Review and Marketing Data ==="

# レビューの作成
puts "Creating reviews..."
users = User.all.to_a
products = Product.all.to_a

10.times do
  user = users.sample
  product = products.sample

  review = Review.create!(
    user: user,
    product: product,
    title: Faker::Lorem.sentence(word_count: 5),
    content: Faker::Lorem.paragraph(sentence_count: 5),
    rating: rand(3..5),
    verified_purchase: [true, false].sample,
    is_approved: [true, false].sample,
    approved_at: Time.current - rand(1..30).days,
    status: ['pending', 'approved', 'rejected'].sample,
    helpful_votes_count: rand(0..20),
    unhelpful_votes_count: rand(0..5)
  )

  # レビュー画像の追加
  if rand < 0.3
    rand(1..3).times do |i|
      ReviewImage.create!(
        review: review,
        image_url: "https://example.com/reviews/images/#{SecureRandom.hex(8)}.jpg",
        alt_text: "Review image #{i+1} for #{product.name}",
        position: i,
        is_approved: review.is_approved,
        approved_at: review.approved_at,
        status: review.status
      )
    end
  end

  # レビュー投票の追加
  if review.is_approved
    rand(0..10).times do
      voter = users.sample
      next if voter == user

      ReviewVote.create!(
        user: voter,
        review: review,
        is_helpful: rand < 0.8, # 80%が役に立つと評価
        reason: rand < 0.3 ? Faker::Lorem.sentence : nil
      )
    end
  end
end

# 評価の作成
puts "Creating ratings..."
15.times do
  user = users.sample
  product = products.sample

  Rating.create!(
    user: user,
    product: product,
    value: rand(1..5),
    dimension: ['quality', 'price', 'shipping', 'customer_service'].sample,
    comment: rand < 0.5 ? Faker::Lorem.sentence : nil,
    is_anonymous: rand < 0.3
  )
end

# 質問と回答の作成
puts "Creating questions and answers..."
5.times do
  user = users.sample
  product = products.sample

  question = Question.create!(
    user: user,
    product: product,
    content: Faker::Lorem.paragraph(sentence_count: 2) + "?",
    is_approved: [true, false].sample,
    approved_at: Time.current - rand(1..60).days,
    status: ['pending', 'approved', 'rejected'].sample,
    votes_count: rand(0..15)
  )

  if question.is_approved && rand < 0.8
    # 回答の追加
    rand(1..3).times do
      answerer = users.sample

      Answer.create!(
        user: answerer,
        question: question,
        content: Faker::Lorem.paragraph(sentence_count: 2),
        is_approved: [true, false].sample,
        approved_at: Time.current - rand(1..30).days,
        is_seller_answer: rand < 0.2,
        is_amazon_answer: rand < 0.1,
        status: ['pending', 'approved', 'rejected'].sample,
        helpful_votes_count: rand(0..10),
        unhelpful_votes_count: rand(0..3),
        is_best_answer: false
      )
    end

    # ベストアンサーの設定
    if question.answers.approved.exists? && rand < 0.5
      best_answer = question.answers.approved.sample
      best_answer.update(is_best_answer: true)
    end

    # 質問のステータス更新
    question.update(
      answers_count: question.answers.approved.count,
      is_answered: question.answers.approved.exists?
    )
  end
end

# プロモーションの作成
puts "Creating promotions..."
admin = User.find_by(email: "admin@example.com")

3.times do |i|
  promotion = Promotion.create!(
    name: Faker::Marketing.buzzwords,
    description: Faker::Lorem.paragraph,
    start_date: Time.current - rand(1..10).days,
    end_date: Time.current + rand(10..60).days,
    is_active: true,
    promotion_type: ['percentage_discount', 'fixed_amount', 'buy_x_get_y'].sample,
    discount_amount: rand(5..50),
    minimum_order_amount: rand < 0.5 ? rand(1000..5000) : nil,
    usage_limit: rand < 0.7 ? rand(100..1000) : nil,
    code: "PROMO#{i+1}#{SecureRandom.hex(3).upcase}",
    is_public: rand < 0.7,
    is_combinable: rand < 0.3,
    priority: rand(0..10),
    created_by: admin
  )

  # プロモーションルールの追加
  rand(1..3).times do
    rule_type = ['product', 'category', 'customer', 'cart_quantity', 'cart_amount'].sample

    value = case rule_type
            when 'product'
              products.sample.id.to_s
            when 'category'
              Category.all.sample.id.to_s
            when 'customer'
              ['new_customer', 'returning_customer', 'prime_member'].sample
            when 'cart_quantity'
              rand(1..10).to_s
            when 'cart_amount'
              rand(1000..10000).to_s
            end

    operator = case rule_type
               when 'product', 'category'
                 ['include', 'exclude'].sample
               when 'customer'
                 nil
               when 'cart_quantity', 'cart_amount'
                 ['greater_than', 'equal', 'less_than'].sample
               end

    PromotionRule.create!(
      promotion: promotion,
      rule_type: rule_type,
      operator: operator,
      value: value,
      is_mandatory: rand < 0.7,
      position: rand(0..10)
    )
  end
end

# クーポンの作成
puts "Creating coupons..."
5.times do |i|
  coupon = Coupon.create!(
    code: "COUPON#{i+1}#{SecureRandom.hex(3).upcase}",
    name: "#{Faker::Commerce.product_name} クーポン",
    description: Faker::Lorem.sentence,
    start_date: Time.current - rand(1..10).days,
    end_date: Time.current + rand(10..60).days,
    is_active: true,
    coupon_type: ['percentage', 'fixed_amount', 'free_shipping'].sample,
    discount_amount: rand(5..50),
    minimum_order_amount: rand < 0.5 ? rand(1000..5000) : nil,
    usage_limit_per_user: rand < 0.7 ? rand(1..5) : nil,
    usage_limit_total: rand < 0.5 ? rand(100..1000) : nil,
    is_single_use: rand < 0.3,
    is_first_order_only: rand < 0.2,
    promotion: rand < 0.3 ? Promotion.all.sample : nil,
    created_by: admin
  )

  # 特定のカテゴリやプロダクトに限定するクーポン
  if rand < 0.3
    if rand < 0.5
      coupon.update(category: Category.all.sample)
    else
      coupon.update(product: products.sample)
    end
  end
end

# 割引の作成
puts "Creating discounts..."
3.times do
  discount = Discount.create!(
    name: "#{Faker::Commerce.product_name} セール",
    description: Faker::Lorem.sentence,
    start_date: Time.current - rand(1..10).days,
    end_date: Time.current + rand(10..60).days,
    is_active: true,
    discount_type: ['percentage', 'fixed_amount', 'buy_one_get_one'].sample,
    discount_amount: rand(5..50),
    minimum_purchase_amount: rand < 0.5 ? rand(1000..5000) : nil,
    usage_limit: rand < 0.5 ? rand(100..1000) : nil,
    created_by: admin,
    status: ['active', 'scheduled', 'expired', 'cancelled'].sample
  )

  # 特定のカテゴリ、プロダクト、またはブランドに限定する割引
  case rand(3)
  when 0
    discount.update(product: products.sample)
  when 1
    discount.update(category: Category.all.sample)
  when 2
    discount.update(brand: Brand.all.sample)
  end
end

# キャンペーンの作成
puts "Creating campaigns..."
2.times do
  campaign = Campaign.create!(
    name: "#{Faker::Commerce.department} キャンペーン",
    description: Faker::Lorem.paragraph,
    start_date: Time.current - rand(1..10).days,
    end_date: Time.current + rand(10..60).days,
    is_active: true,
    campaign_type: ['seasonal', 'holiday', 'flash_sale', 'clearance'].sample,
    budget: rand(10000..100000),
    spent_amount: rand(0..5000),
    target_audience: ['all', 'prime_members', 'new_customers'].sample,
    status: ['active', 'scheduled', 'completed', 'cancelled'].sample,
    created_by: admin,
    tracking_code: "CAM-#{SecureRandom.hex(4).upcase}-#{rand(1000..9999)}",
    is_featured: rand < 0.3
  )

  # キャンペーンにプロモーションを関連付け
  if rand < 0.5 && Promotion.exists?
    campaign.update(promotion: Promotion.all.sample)
  end

  # 広告の作成
  rand(1..3).times do
    ad = Advertisement.create!(
      name: "#{campaign.name} 広告 #{SecureRandom.hex(3)}",
      description: Faker::Lorem.sentence,
      start_date: campaign.start_date,
      end_date: campaign.end_date,
      is_active: campaign.is_active,
      ad_type: ['banner', 'sidebar', 'popup', 'sponsored_product'].sample,
      image_url: "https://example.com/ads/#{SecureRandom.hex(8)}.jpg",
      target_url: Faker::Internet.url,
      placement: ['home_page', 'product_page', 'search_results', 'category_page'].sample,
      budget: rand(1000..10000),
      spent_amount: rand(0..500),
      cost_per_click: (rand(10..100) / 100.0).round(2),
      impressions_count: rand(1000..10000),
      clicks_count: rand(10..1000),
      campaign: campaign,
      created_by: admin,
      status: campaign.status
    )

    # クリックスルーレートの計算
    if ad.impressions_count > 0
      ad.update(click_through_rate: (ad.clicks_count.to_f / ad.impressions_count * 100).round(2))
    end

    # 広告のターゲット設定
    case rand(3)
    when 0
      ad.update(product: products.sample)
    when 1
      ad.update(category: Category.all.sample)
    when 2
      # セラーがいる場合はセラーを設定
      ad.update(seller: Seller.first) if Seller.exists?
    end
  end
end

# アフィリエイトプログラムの作成
puts "Creating affiliate program..."
AffiliateProgram.create!(
  name: "Amazon Clone アフィリエイトプログラム",
  description: "商品を紹介して報酬を獲得しましょう",
  is_active: true,
  commission_rate: rand(1..10),
  commission_type: ['percentage', 'fixed_amount'].sample,
  minimum_payout: 5000,
  payment_method: ['bank_transfer', 'paypal', 'amazon_gift_card'].sample,
  cookie_days: 30,
  terms_and_conditions: Faker::Lorem.paragraphs(number: 5).join("\n\n"),
  created_by: admin,
  status: 'active',
  tracking_code_prefix: 'ACLNAFF'
)

# 紹介プログラムの作成
puts "Creating referral program..."
ReferralProgram.create!(
  name: "お友達紹介プログラム",
  description: "お友達を紹介して、あなたもお友達も特典をゲット！",
  is_active: true,
  start_date: Time.current - 30.days,
  end_date: Time.current + 90.days,
  reward_type: ['discount', 'credit', 'gift_card'].sample,
  referrer_reward_amount: 1000,
  referee_reward_amount: 500,
  usage_limit_per_user: 10,
  usage_limit_total: 1000,
  terms_and_conditions: Faker::Lorem.paragraphs(number: 3).join("\n\n"),
  created_by: admin,
  status: 'active',
  code_prefix: 'REFER'
)

puts "Review and marketing seed data created successfully!"
