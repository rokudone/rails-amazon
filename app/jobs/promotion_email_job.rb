class PromotionEmailJob < ApplicationJob
  queue_as :mailers

  # プロモーション通知メールを送信するジョブ
  def perform(promotion_id, user_ids = nil)
    # プロモーション情報を取得
    promotion = find_promotion(promotion_id)

    # プロモーションが見つからない場合は終了
    return unless promotion

    # プロモーションが有効でない場合は終了
    return unless promotion_active?(promotion)

    # 送信対象のユーザーを取得
    users = get_target_users(user_ids, promotion)

    # ユーザーが見つからない場合は終了
    return if users.empty?

    # クーポン情報を取得
    coupon = get_promotion_coupon(promotion)

    # 各ユーザーにプロモーションメールを送信
    users.each do |user|
      # ユーザー固有のクーポンを生成
      user_coupon = generate_user_coupon(user, promotion, coupon)

      # プロモーション商品を取得
      promotion_products = get_promotion_products(promotion, user)

      # メール送信
      PromotionMailer.send_promotion(user, promotion, user_coupon, promotion_products).deliver_later

      # ログ記録
      log_email_scheduled(user, promotion, user_coupon)
    end

    # プロモーションメール送信完了を記録
    update_promotion_status(promotion, users.size)
  end

  private

  # プロモーション情報を取得
  def find_promotion(promotion_id)
    # プロモーションモデルが定義されている場合
    if defined?(Promotion)
      Promotion.find_by(id: promotion_id)
    else
      # シミュレーション用のプロモーション情報
      {
        id: promotion_id,
        name: "Promotion ##{promotion_id}",
        description: "This is a special promotion with great discounts!",
        starts_at: Time.current - 1.day,
        ends_at: Time.current + 7.days,
        discount_type: 'percentage',
        discount_value: 20,
        is_active: true
      }
    end
  end

  # プロモーションが有効かチェック
  def promotion_active?(promotion)
    if promotion.is_a?(Hash)
      promotion[:is_active] &&
      promotion[:starts_at] <= Time.current &&
      promotion[:ends_at] >= Time.current
    else
      promotion.is_active &&
      promotion.starts_at <= Time.current &&
      promotion.ends_at >= Time.current
    end
  end

  # 送信対象のユーザーを取得
  def get_target_users(user_ids, promotion)
    if user_ids.present?
      # 指定されたユーザーIDのユーザーを取得
      User.where(id: user_ids).where(active: true)
    else
      # プロモーションの対象ユーザーを取得
      get_promotion_target_users(promotion)
    end
  end

  # プロモーションの対象ユーザーを取得
  def get_promotion_target_users(promotion)
    # ユーザー設定でプロモーションメールの受信を許可しているユーザーを取得
    if defined?(UserPreference)
      users = User.joins(:user_preference)
                  .where(active: true)
                  .where(user_preferences: { email_notifications: true })

      # プロモーションルールに基づいてユーザーをフィルタリング
      if defined?(PromotionRule) && !promotion.is_a?(Hash) && promotion.respond_to?(:promotion_rules)
        promotion.promotion_rules.each do |rule|
          users = apply_promotion_rule(users, rule)
        end
      end

      users
    else
      # シミュレーション用
      User.where(active: true)
    end
  end

  # プロモーションルールを適用
  def apply_promotion_rule(users, rule)
    case rule.rule_type
    when 'min_order_count'
      # 最小注文回数
      users.joins(:orders)
           .group('users.id')
           .having('COUNT(orders.id) >= ?', rule.value)
    when 'min_order_value'
      # 最小注文金額
      users.joins(:orders)
           .group('users.id')
           .having('SUM(orders.total) >= ?', rule.value)
    when 'specific_category'
      # 特定カテゴリの商品を購入したユーザー
      users.joins(orders: { order_items: :product })
           .where(products: { category_id: rule.value })
           .distinct
    when 'inactive_days'
      # 一定期間注文していないユーザー
      last_active_date = Time.current - rule.value.to_i.days
      users.joins(:orders)
           .group('users.id')
           .having('MAX(orders.created_at) < ?', last_active_date)
    else
      users
    end
  end

  # プロモーションのクーポン情報を取得
  def get_promotion_coupon(promotion)
    # プロモーションに関連するクーポンを取得
    if defined?(Coupon) && !promotion.is_a?(Hash) && promotion.respond_to?(:coupons)
      promotion.coupons.first
    else
      # シミュレーション用のクーポン情報
      {
        code: "PROMO#{promotion.is_a?(Hash) ? promotion[:id] : promotion.id}",
        discount_type: promotion.is_a?(Hash) ? promotion[:discount_type] : promotion.discount_type,
        discount_value: promotion.is_a?(Hash) ? promotion[:discount_value] : promotion.discount_value,
        starts_at: promotion.is_a?(Hash) ? promotion[:starts_at] : promotion.starts_at,
        expires_at: promotion.is_a?(Hash) ? promotion[:ends_at] : promotion.ends_at
      }
    end
  end

  # ユーザー固有のクーポンを生成
  def generate_user_coupon(user, promotion, coupon)
    # ユーザー固有のクーポンコードを生成
    if coupon.is_a?(Hash)
      user_coupon = coupon.dup
      user_coupon[:code] = "#{coupon[:code]}#{user.id}"
    else
      user_coupon = {
        code: "#{coupon.code}#{user.id}",
        discount_type: coupon.discount_type,
        discount_value: coupon.discount_value,
        starts_at: coupon.starts_at,
        expires_at: coupon.expires_at
      }
    end

    # クーポンをデータベースに保存
    if defined?(Coupon) && !coupon.is_a?(Hash)
      Coupon.create(
        code: user_coupon[:code],
        discount_type: user_coupon[:discount_type],
        discount_value: user_coupon[:discount_value],
        starts_at: user_coupon[:starts_at],
        expires_at: user_coupon[:expires_at],
        is_active: true,
        usage_limit: 1,
        user_id: user.id,
        promotion_id: promotion.is_a?(Hash) ? promotion[:id] : promotion.id
      )
    end

    user_coupon
  end

  # プロモーション商品を取得
  def get_promotion_products(promotion, user)
    # プロモーションに関連する商品を取得
    if defined?(Product) && !promotion.is_a?(Hash) && promotion.respond_to?(:products)
      promotion.products.limit(5).map do |product|
        {
          id: product.id,
          name: product.name,
          price: product.price,
          discount_price: calculate_discount_price(product.price, promotion),
          image_url: product.product_images.first&.image_url
        }
      end
    else
      # シミュレーション用
      if defined?(Product)
        Product.where(is_featured: true).limit(5).map do |product|
          {
            id: product.id,
            name: product.name,
            price: product.price,
            discount_price: calculate_discount_price(
              product.price,
              promotion.is_a?(Hash) ? promotion : { discount_type: promotion.discount_type, discount_value: promotion.discount_value }
            ),
            image_url: product.product_images.first&.image_url
          }
        end
      else
        []
      end
    end
  end

  # 割引価格を計算
  def calculate_discount_price(price, promotion)
    discount_type = promotion.is_a?(Hash) ? promotion[:discount_type] : promotion.discount_type
    discount_value = promotion.is_a?(Hash) ? promotion[:discount_value] : promotion.discount_value

    case discount_type
    when 'percentage'
      price * (1 - discount_value / 100.0)
    when 'fixed'
      [price - discount_value, 0].max
    else
      price
    end
  end

  # メール送信をログに記録
  def log_email_scheduled(user, promotion, user_coupon)
    # ユーザーログに記録
    if defined?(UserLog)
      UserLog.create(
        user_id: user.id,
        action: 'promotion_email_scheduled',
        details: {
          promotion_id: promotion.is_a?(Hash) ? promotion[:id] : promotion.id,
          promotion_name: promotion.is_a?(Hash) ? promotion[:name] : promotion.name,
          coupon_code: user_coupon[:code]
        }
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'email_scheduled',
        message: "Promotion email scheduled for user #{user.id}",
        details: {
          user_id: user.id,
          email_type: 'promotion',
          promotion_id: promotion.is_a?(Hash) ? promotion[:id] : promotion.id,
          promotion_name: promotion.is_a?(Hash) ? promotion[:name] : promotion.name,
          coupon_code: user_coupon[:code]
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Promotion email scheduled for user #{user.id} with coupon #{user_coupon[:code]}")
  end

  # プロモーションメール送信完了を記録
  def update_promotion_status(promotion, sent_count)
    # プロモーションモデルが定義されている場合
    if defined?(Promotion) && !promotion.is_a?(Hash)
      promotion.update(
        email_sent_at: Time.current,
        email_sent_count: (promotion.email_sent_count || 0) + sent_count
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'promotion_emails_sent',
        message: "Promotion emails sent to #{sent_count} users",
        details: {
          promotion_id: promotion.is_a?(Hash) ? promotion[:id] : promotion.id,
          promotion_name: promotion.is_a?(Hash) ? promotion[:name] : promotion.name,
          sent_count: sent_count
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Promotion emails sent to #{sent_count} users")
  end
end
