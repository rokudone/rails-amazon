class PricingService
  attr_reader :product, :cart, :order

  def initialize(product = nil, cart = nil, order = nil)
    @product = product
    @cart = cart
    @order = order
  end

  # 価格計算
  def calculate_price(quantity = 1, options = {})
    return 0 unless @product

    # 基本価格
    base_price = @product.price

    # セール価格がある場合
    if @product.sale_price.present? &&
       @product.sale_price > 0 &&
       (@product.sale_start_date.nil? || @product.sale_start_date <= Time.current) &&
       (@product.sale_end_date.nil? || @product.sale_end_date >= Time.current)
      base_price = @product.sale_price
    end

    # 数量に基づく価格
    total_price = base_price * quantity

    # 割引の適用
    discount_amount = calculate_discount(total_price, options)

    # 税金の計算
    tax_amount = calculate_tax(total_price - discount_amount, options)

    {
      base_price: base_price,
      quantity: quantity,
      subtotal: total_price,
      discount: discount_amount,
      tax: tax_amount,
      total: total_price - discount_amount + tax_amount
    }
  end

  # 割引適用
  def apply_discount(discount_type, discount_value, options = {})
    return 0 unless @product || @cart || @order

    base_amount = if @product
                    @product.price
                  elsif @cart
                    @cart.subtotal
                  elsif @order
                    @order.subtotal
                  else
                    0
                  end

    case discount_type
    when 'percentage'
      # パーセンテージ割引
      (base_amount * discount_value / 100).round(2)
    when 'fixed_amount'
      # 固定金額割引
      [discount_value, base_amount].min
    when 'buy_x_get_y'
      # X個買うとY個無料
      if @product && options[:quantity]
        x = options[:buy_quantity] || 1
        y = options[:free_quantity] || 1

        if options[:quantity] >= x
          free_items = (options[:quantity] / x) * y
          (@product.price * free_items).round(2)
        else
          0
        end
      else
        0
      end
    else
      0
    end
  end

  # 税金計算
  def calculate_tax(amount, options = {})
    # 税率の取得
    tax_rate = if @product
                 @product.tax_rate || default_tax_rate(options)
               else
                 default_tax_rate(options)
               end

    # 税金の計算
    (amount * tax_rate / 100).round(2)
  end

  # カート計算
  def calculate_cart
    return { subtotal: 0, discount: 0, tax: 0, shipping: 0, total: 0 } unless @cart

    # 小計の計算
    subtotal = @cart.cart_items.sum { |item| item.price * item.quantity }

    # 割引の計算
    discount = @cart.discount || 0

    # 配送料の計算
    shipping = calculate_shipping_cost

    # 税金の計算
    tax = calculate_cart_tax(subtotal - discount)

    # 合計の計算
    total = subtotal - discount + shipping + tax

    # カートの更新
    @cart.update(
      subtotal: subtotal,
      shipping_cost: shipping,
      tax: tax,
      total: total
    )

    {
      subtotal: subtotal,
      discount: discount,
      shipping: shipping,
      tax: tax,
      total: total
    }
  end

  # 注文計算
  def calculate_order
    return { subtotal: 0, discount: 0, tax: 0, shipping: 0, total: 0 } unless @order

    # 小計の計算
    subtotal = @order.order_items.sum { |item| item.price * item.quantity }

    # 割引の計算
    discount = @order.order_discounts.sum(:amount) || 0

    # 配送料の計算
    shipping = @order.shipping_cost || calculate_shipping_cost(true)

    # 税金の計算
    tax = @order.tax || calculate_cart_tax(subtotal - discount)

    # 合計の計算
    total = subtotal - discount + shipping + tax

    # 注文の更新
    @order.update(
      subtotal: subtotal,
      discount: discount,
      shipping_cost: shipping,
      tax: tax,
      total: total
    )

    {
      subtotal: subtotal,
      discount: discount,
      shipping: shipping,
      tax: tax,
      total: total
    }
  end

  # 価格履歴管理
  def price_history
    return [] unless @product

    @product.price_histories.order(created_at: :desc)
  end

  # 価格変更
  def update_price(new_price, changed_by = 'system')
    return false unless @product

    old_price = @product.price

    if @product.update(price: new_price)
      # 価格履歴の記録
      PriceHistory.create(
        product_id: @product.id,
        old_price: old_price,
        new_price: new_price,
        changed_by: changed_by
      )

      true
    else
      false
    end
  end

  # セール価格設定
  def set_sale_price(sale_price, start_date = nil, end_date = nil, changed_by = 'system')
    return false unless @product

    if @product.update(
      sale_price: sale_price,
      sale_start_date: start_date,
      sale_end_date: end_date
    )
      # 価格履歴の記録
      PriceHistory.create(
        product_id: @product.id,
        old_price: @product.price,
        new_price: sale_price,
        changed_by: changed_by,
        notes: "Sale price: #{start_date} to #{end_date}"
      )

      true
    else
      false
    end
  end

  # クーポン検証
  def validate_coupon(code, options = {})
    coupon = Coupon.find_by(code: code)

    return { valid: false, message: 'Invalid coupon code' } unless coupon

    # クーポンがアクティブかどうか
    unless coupon.active
      return { valid: false, message: 'Coupon is not active' }
    end

    # 有効期限のチェック
    if coupon.start_date && coupon.start_date > Time.current
      return { valid: false, message: 'Coupon is not yet valid' }
    end

    if coupon.end_date && coupon.end_date < Time.current
      return { valid: false, message: 'Coupon has expired' }
    end

    # 使用回数制限のチェック
    if coupon.usage_limit && coupon.used_count >= coupon.usage_limit
      return { valid: false, message: 'Coupon usage limit reached' }
    end

    # ユーザーごとの使用回数制限のチェック
    if coupon.per_user_limit && options[:user_id]
      user_usage = OrderDiscount.joins(:order)
                              .where(orders: { user_id: options[:user_id] })
                              .where(code: code)
                              .count

      if user_usage >= coupon.per_user_limit
        return { valid: false, message: 'You have reached the usage limit for this coupon' }
      end
    end

    # 最小注文金額のチェック
    if coupon.minimum_order_amount && options[:order_amount] && options[:order_amount] < coupon.minimum_order_amount
      return { valid: false, message: "Minimum order amount of #{coupon.minimum_order_amount} required" }
    end

    # クーポンの割引額を計算
    discount_amount = case coupon.discount_type
                      when 'percentage'
                        options[:order_amount] ? (options[:order_amount] * coupon.discount_value / 100).round(2) : nil
                      when 'fixed_amount'
                        coupon.discount_value
                      when 'free_shipping'
                        options[:shipping_cost] || 0
                      else
                        0
                      end

    {
      valid: true,
      coupon: coupon,
      discount_amount: discount_amount,
      message: 'Coupon is valid'
    }
  end

  private

  # 割引の計算
  def calculate_discount(amount, options = {})
    discount_amount = 0

    # クーポンコードがある場合
    if options[:coupon_code]
      coupon_result = validate_coupon(
        options[:coupon_code],
        {
          user_id: options[:user_id],
          order_amount: amount,
          shipping_cost: options[:shipping_cost]
        }
      )

      if coupon_result[:valid]
        discount_amount += coupon_result[:discount_amount] || 0
      end
    end

    # プロモーションがある場合
    if options[:promotion_id]
      promotion = Promotion.find_by(id: options[:promotion_id])

      if promotion && promotion.active &&
         (promotion.start_date.nil? || promotion.start_date <= Time.current) &&
         (promotion.end_date.nil? || promotion.end_date >= Time.current)

        promotion_discount = case promotion.discount_type
                            when 'percentage'
                              (amount * promotion.discount_value / 100).round(2)
                            when 'fixed_amount'
                              promotion.discount_value
                            else
                              0
                            end

        discount_amount += promotion_discount
      end
    end

    # 数量割引がある場合
    if @product && options[:quantity] && options[:quantity] > 1
      # 数量割引の計算ロジック
      # 例: 5個以上で5%割引、10個以上で10%割引
      quantity_discount = 0

      if options[:quantity] >= 10
        quantity_discount = (amount * 0.1).round(2)
      elsif options[:quantity] >= 5
        quantity_discount = (amount * 0.05).round(2)
      end

      discount_amount += quantity_discount
    end

    discount_amount
  end

  # デフォルト税率の取得
  def default_tax_rate(options = {})
    # 配送先の国や地域に基づいて税率を取得
    if options[:country_id]
      country = Country.find_by(id: options[:country_id])
      return country.tax_rate if country && country.tax_rate.present?
    end

    if options[:region_id]
      region = Region.find_by(id: options[:region_id])
      return region.tax_rate if region && region.tax_rate.present?
    end

    # デフォルト税率
    10.0 # 10%
  end

  # 配送料の計算
  def calculate_shipping_cost(for_order = false)
    if for_order && @order
      # 注文の配送先住所に基づいて計算
      shipping_address = @order.shipping_address
      return calculate_shipping_by_address(shipping_address) if shipping_address
    elsif @cart
      # カートの配送先住所に基づいて計算
      user = @cart.user
      shipping_address = user.addresses.find_by(default: true) if user
      return calculate_shipping_by_address(shipping_address) if shipping_address
    end

    # デフォルト配送料
    5.0
  end

  # 住所に基づく配送料の計算
  def calculate_shipping_by_address(address)
    return 5.0 unless address

    # 国や地域に基づいて配送料を計算
    country = address.country

    if country == 'US'
      # アメリカ国内の配送料
      case address.state
      when 'CA', 'NY', 'FL'
        7.0
      else
        5.0
      end
    else
      # 国際配送料
      15.0
    end
  end

  # カートの税金計算
  def calculate_cart_tax(amount)
    return 0 unless @cart

    # カートのユーザーの配送先住所に基づいて税率を取得
    user = @cart.user
    shipping_address = user.addresses.find_by(default: true) if user

    options = {}

    if shipping_address
      options[:country_id] = shipping_address.country_id if shipping_address.country_id
      options[:region_id] = shipping_address.state_id if shipping_address.state_id
    end

    # 税金の計算
    tax_rate = default_tax_rate(options)
    (amount * tax_rate / 100).round(2)
  end
end
