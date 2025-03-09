class AbandonedCartReminderJob < ApplicationJob
  queue_as :mailers

  # 放棄カートリマインダーメールを送信するジョブ
  def perform(cart_id)
    # カート情報を取得
    cart = Cart.find_by(id: cart_id)

    # カートが見つからない場合は終了
    return unless cart

    # カートが空の場合は終了
    return if cart.cart_items.empty?

    # ユーザー情報を取得
    user = cart.user

    # ユーザーが見つからない場合は終了
    return unless user

    # カートが最近更新されている場合は終了（放棄とみなさない）
    return if cart.updated_at > 24.hours.ago

    # カート内容を取得
    cart_contents = get_cart_contents(cart)

    # おすすめ商品を取得
    recommended_products = get_recommended_products(user, cart_contents)

    # 割引クーポンを生成
    discount_coupon = generate_discount_coupon(user)

    # メール送信
    CartMailer.abandoned_cart_reminder(user, cart_contents, recommended_products, discount_coupon).deliver_now

    # ログ記録
    log_email_sent(user, cart, cart_contents, discount_coupon)
  end

  private

  # カート内容を取得
  def get_cart_contents(cart)
    # カートアイテムを取得
    cart.cart_items.map do |item|
      product = item.product
      variant = item.product_variant

      {
        id: item.id,
        product_id: product.id,
        product_name: product.name,
        variant_id: variant&.id,
        variant_name: variant&.name,
        price: item.price,
        quantity: item.quantity,
        subtotal: item.price * item.quantity,
        image_url: product.product_images.first&.image_url
      }
    end
  end

  # おすすめ商品を取得
  def get_recommended_products(user, cart_contents)
    # カート内の商品に基づいておすすめ商品を取得
    product_ids = cart_contents.map { |item| item[:product_id] }

    # 関連商品を取得
    if defined?(Product) && product_ids.present?
      # カート内の商品と同じカテゴリの商品を取得
      categories = Product.where(id: product_ids).pluck(:category_id).compact.uniq

      Product.where(category_id: categories)
             .where.not(id: product_ids)
             .where(is_active: true)
             .limit(5)
             .map do |product|
        {
          id: product.id,
          name: product.name,
          price: product.price,
          image_url: product.product_images.first&.image_url
        }
      end
    else
      []
    end
  end

  # 割引クーポンを生成
  def generate_discount_coupon(user)
    # 割引クーポンを生成
    if defined?(Coupon)
      # クーポンコードを生成
      code = "COMEBACK#{user.id}#{Time.current.to_i.to_s(36).upcase}"

      # クーポンを作成
      coupon = Coupon.create(
        code: code,
        discount_type: 'percentage',
        discount_value: 10,
        minimum_order_amount: 0,
        starts_at: Time.current,
        expires_at: 7.days.from_now,
        is_active: true,
        usage_limit: 1,
        user_id: user.id
      )

      {
        code: coupon.code,
        discount_type: coupon.discount_type,
        discount_value: coupon.discount_value,
        expires_at: coupon.expires_at
      }
    else
      {
        code: "COMEBACK#{user.id}#{Time.current.to_i.to_s(36).upcase}",
        discount_type: 'percentage',
        discount_value: 10,
        expires_at: 7.days.from_now
      }
    end
  end

  # メール送信をログに記録
  def log_email_sent(user, cart, cart_contents, discount_coupon)
    # ユーザーログに記録
    if defined?(UserLog)
      UserLog.create(
        user_id: user.id,
        action: 'abandoned_cart_reminder_email_sent',
        details: {
          cart_id: cart.id,
          item_count: cart_contents.size,
          total_value: cart_contents.sum { |item| item[:subtotal] },
          coupon_code: discount_coupon[:code]
        }
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'email_sent',
        message: "Abandoned cart reminder email sent to user #{user.id}",
        details: {
          user_id: user.id,
          cart_id: cart.id,
          email_type: 'abandoned_cart_reminder',
          item_count: cart_contents.size,
          total_value: cart_contents.sum { |item| item[:subtotal] },
          coupon_code: discount_coupon[:code]
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Abandoned cart reminder email sent to user #{user.id} for cart #{cart.id} with #{cart_contents.size} items")
  end
end
