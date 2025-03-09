class OrderService
  attr_reader :order, :user

  def initialize(order = nil, user = nil)
    @order = order
    @user = user
  end

  # 注文作成
  def create(params)
    @order = Order.new(params)
    @order.user_id = @user.id if @user

    if @order.save
      # 注文アイテムの作成
      create_order_items(params[:items]) if params[:items].present?

      # 注文ログの作成
      @order.order_logs.create(
        status: @order.status,
        notes: 'Order created',
        user_id: @user&.id
      )

      # 在庫の更新
      update_inventory

      # カートのクリア
      clear_cart if params[:cart_id].present?

      true
    else
      false
    end
  end

  # 注文更新
  def update(params)
    return false unless @order

    old_status = @order.status

    if @order.update(params)
      # ステータスが変更された場合は注文ログを作成
      if old_status != @order.status
        @order.order_logs.create(
          status: @order.status,
          notes: "Status changed from #{old_status} to #{@order.status}",
          user_id: @user&.id
        )

        # ステータスに応じた処理
        process_status_change(old_status, @order.status)
      end

      true
    else
      false
    end
  end

  # 注文検索
  def search(options = {})
    orders = Order.all

    # ユーザーIDでフィルタリング
    orders = orders.where(user_id: options[:user_id]) if options[:user_id].present?

    # ステータスでフィルタリング
    orders = orders.where(status: options[:status]) if options[:status].present?

    # 日付範囲でフィルタリング
    orders = orders.where('created_at >= ?', options[:start_date]) if options[:start_date].present?
    orders = orders.where('created_at <= ?', options[:end_date]) if options[:end_date].present?

    # 金額範囲でフィルタリング
    orders = orders.where('total >= ?', options[:min_amount]) if options[:min_amount].present?
    orders = orders.where('total <= ?', options[:max_amount]) if options[:max_amount].present?

    # ソート
    orders = apply_sort(orders, options[:sort])

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    orders.page(page).per(per_page)
  end

  # 注文履歴の取得
  def order_history(options = {})
    return [] unless @user

    orders = @user.orders

    # ステータスでフィルタリング
    orders = orders.where(status: options[:status]) if options[:status].present?

    # 日付範囲でフィルタリング
    orders = orders.where('created_at >= ?', options[:start_date]) if options[:start_date].present?
    orders = orders.where('created_at <= ?', options[:end_date]) if options[:end_date].present?

    # ソート
    orders = apply_sort(orders, options[:sort])

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    orders.page(page).per(per_page)
  end

  # 注文詳細の取得
  def order_details
    return {} unless @order

    {
      order: @order,
      items: @order.order_items.includes(:product),
      logs: @order.order_logs.order(created_at: :desc),
      shipping: @order.shipment,
      payment: @order.payment,
      shipping_address: @order.shipping_address,
      billing_address: @order.billing_address
    }
  end

  # 注文ステータスの更新
  def update_status(status, notes = nil)
    return false unless @order

    old_status = @order.status

    if @order.update(status: status)
      # 注文ログの作成
      @order.order_logs.create(
        status: status,
        notes: notes || "Status changed from #{old_status} to #{status}",
        user_id: @user&.id
      )

      # ステータスに応じた処理
      process_status_change(old_status, status)

      true
    else
      false
    end
  end

  # 注文のキャンセル
  def cancel(reason = nil)
    return false unless @order

    # キャンセル可能なステータスかチェック
    unless ['pending', 'confirmed', 'processing'].include?(@order.status)
      @error = 'Order cannot be cancelled'
      return false
    end

    old_status = @order.status

    if @order.update(status: 'cancelled')
      # 注文ログの作成
      @order.order_logs.create(
        status: 'cancelled',
        notes: reason || 'Order cancelled',
        user_id: @user&.id
      )

      # 在庫の戻し
      revert_inventory

      # 支払いがある場合は返金処理
      refund_payment if @order.payment && @order.payment.status == 'completed'

      true
    else
      @error = @order.errors.full_messages.join(', ')
      false
    end
  end

  # 注文の再注文
  def reorder
    return false unless @order && @user

    # 新しい注文の作成
    new_order = Order.new(
      user_id: @user.id,
      status: 'pending',
      shipping_address_id: @order.shipping_address_id,
      billing_address_id: @order.billing_address_id,
      payment_method_id: @order.payment_method_id,
      notes: "Reorder of ##{@order.id}"
    )

    if new_order.save
      # 注文アイテムのコピー
      @order.order_items.each do |item|
        # 商品が存在し、アクティブかチェック
        product = Product.find_by(id: item.product_id)
        next unless product && product.active

        # 在庫があるかチェック
        inventory = Inventory.where(product_id: product.id).sum(:quantity)
        quantity = [item.quantity, inventory].min
        next if quantity <= 0

        # 注文アイテムの作成
        new_order.order_items.create(
          product_id: item.product_id,
          quantity: quantity,
          price: product.price,
          total: product.price * quantity
        )
      end

      # 注文の計算
      calculate_order(new_order)

      # 注文ログの作成
      new_order.order_logs.create(
        status: 'pending',
        notes: "Reorder of ##{@order.id}",
        user_id: @user.id
      )

      @order = new_order
      true
    else
      @error = new_order.errors.full_messages.join(', ')
      false
    end
  end

  # エラーメッセージの取得
  def error_message
    @error || @order&.errors&.full_messages&.join(', ')
  end

  private

  # 注文アイテムの作成
  def create_order_items(items)
    items.each do |item|
      @order.order_items.create(
        product_id: item[:product_id],
        quantity: item[:quantity],
        price: item[:price],
        total: item[:price] * item[:quantity]
      )
    end
  end

  # 在庫の更新
  def update_inventory
    @order.order_items.each do |item|
      inventories = Inventory.where(product_id: item.product_id).order(quantity: :desc)
      remaining_quantity = item.quantity

      inventories.each do |inventory|
        if inventory.quantity >= remaining_quantity
          # 在庫が十分にある場合
          inventory.update(quantity: inventory.quantity - remaining_quantity)

          # 在庫移動の記録
          StockMovement.create(
            product_id: item.product_id,
            warehouse_id: inventory.warehouse_id,
            quantity: -remaining_quantity,
            movement_type: 'out',
            reference: "Order ##{@order.id}",
            notes: "Stock reduced due to order"
          )

          break
        else
          # 在庫が不足している場合、利用可能な分だけ減らす
          remaining_quantity -= inventory.quantity

          # 在庫移動の記録
          StockMovement.create(
            product_id: item.product_id,
            warehouse_id: inventory.warehouse_id,
            quantity: -inventory.quantity,
            movement_type: 'out',
            reference: "Order ##{@order.id}",
            notes: "Stock reduced due to order"
          )

          inventory.update(quantity: 0)
        end
      end
    end
  end

  # 在庫の戻し
  def revert_inventory
    @order.order_items.each do |item|
      # デフォルト倉庫を取得
      warehouse = Warehouse.first

      # 在庫の更新
      inventory = Inventory.find_or_initialize_by(
        product_id: item.product_id,
        warehouse_id: warehouse.id
      )

      inventory.quantity = (inventory.quantity || 0) + item.quantity
      inventory.save

      # 在庫移動の記録
      StockMovement.create(
        product_id: item.product_id,
        warehouse_id: warehouse.id,
        quantity: item.quantity,
        movement_type: 'in',
        reference: "Order ##{@order.id} cancelled",
        notes: "Stock returned from cancelled order"
      )
    end
  end

  # カートのクリア
  def clear_cart
    cart = Cart.find_by(id: params[:cart_id])
    return unless cart

    cart.cart_items.destroy_all
    cart.update(
      subtotal: 0,
      shipping_cost: 0,
      tax: 0,
      discount: 0,
      total: 0,
      discount_code: nil
    )
  end

  # 注文の計算
  def calculate_order(order = nil)
    order ||= @order
    return unless order

    # 小計の計算
    subtotal = order.order_items.sum { |item| item.price * item.quantity }

    # 配送料の計算
    shipping_cost = 5.0 # デフォルト配送料

    # 税金の計算
    tax_rate = 0.1 # デフォルト税率
    tax = (subtotal * tax_rate).round(2)

    # 合計の計算
    total = subtotal + shipping_cost + tax

    order.update(
      subtotal: subtotal,
      shipping_cost: shipping_cost,
      tax: tax,
      total: total
    )
  end

  # 支払いの返金
  def refund_payment
    payment = @order.payment
    return unless payment

    # 支払いステータスの更新
    payment.update(status: 'refunded')

    # 支払い処理の記録
    PaymentTransaction.create(
      payment_id: payment.id,
      amount: payment.amount,
      transaction_type: 'refund',
      status: 'completed',
      transaction_id: SecureRandom.hex(10),
      provider_response: { success: true }.to_json
    )
  end

  # ステータス変更時の処理
  def process_status_change(old_status, new_status)
    case new_status
    when 'paid'
      # 支払い完了時の処理
      process_paid_status
    when 'shipped'
      # 発送時の処理
      process_shipped_status
    when 'delivered'
      # 配送完了時の処理
      process_delivered_status
    when 'cancelled'
      # キャンセル時の処理
      process_cancelled_status(old_status)
    when 'refunded'
      # 返金時の処理
      process_refunded_status
    end
  end

  # 支払い完了時の処理
  def process_paid_status
    # 在庫の確認と更新
    update_inventory

    # 通知の送信
    send_notification('order_paid')
  end

  # 発送時の処理
  def process_shipped_status
    # 配送情報の作成
    create_shipment unless @order.shipment

    # 通知の送信
    send_notification('order_shipped')
  end

  # 配送完了時の処理
  def process_delivered_status
    # 配送情報の更新
    update_shipment_delivered

    # 通知の送信
    send_notification('order_delivered')
  end

  # キャンセル時の処理
  def process_cancelled_status(old_status)
    # 在庫の戻し（支払い済みまたは処理中の場合のみ）
    if ['paid', 'processing', 'confirmed'].include?(old_status)
      revert_inventory
    end

    # 支払いがある場合は返金処理
    refund_payment if @order.payment && @order.payment.status == 'completed'

    # 通知の送信
    send_notification('order_cancelled')
  end

  # 返金時の処理
  def process_refunded_status
    # 通知の送信
    send_notification('order_refunded')
  end

  # 配送情報の作成
  def create_shipment
    @order.create_shipment(
      status: 'pending',
      carrier: 'Default Carrier',
      tracking_number: generate_tracking_number,
      shipped_at: Time.current,
      estimated_delivery_date: 5.days.from_now
    )
  end

  # 配送情報の更新（配送完了）
  def update_shipment_delivered
    shipment = @order.shipment
    return unless shipment

    shipment.update(
      status: 'delivered',
      actual_delivery_date: Time.current
    )

    # 配送追跡の更新
    if shipment.shipment_tracking
      shipment.shipment_tracking.update(status: 'delivered')
    end
  end

  # 追跡番号の生成
  def generate_tracking_number
    "TRK#{SecureRandom.hex(8).upcase}"
  end

  # 通知の送信
  def send_notification(notification_type)
    return unless @order.user

    case notification_type
    when 'order_paid'
      @order.user.notifications.create(
        title: 'Order Payment Confirmed',
        content: "Your payment for order ##{@order.id} has been confirmed.",
        notification_type: 'order_update',
        read: false
      )
    when 'order_shipped'
      @order.user.notifications.create(
        title: 'Order Shipped',
        content: "Your order ##{@order.id} has been shipped.",
        notification_type: 'order_update',
        read: false
      )
    when 'order_delivered'
      @order.user.notifications.create(
        title: 'Order Delivered',
        content: "Your order ##{@order.id} has been delivered.",
        notification_type: 'order_update',
        read: false
      )
    when 'order_cancelled'
      @order.user.notifications.create(
        title: 'Order Cancelled',
        content: "Your order ##{@order.id} has been cancelled.",
        notification_type: 'order_update',
        read: false
      )
    when 'order_refunded'
      @order.user.notifications.create(
        title: 'Order Refunded',
        content: "Your order ##{@order.id} has been refunded.",
        notification_type: 'order_update',
        read: false
      )
    end
  end

  # ソートの適用
  def apply_sort(orders, sort)
    case sort
    when 'newest'
      orders.order(created_at: :desc)
    when 'oldest'
      orders.order(created_at: :asc)
    when 'total_desc'
      orders.order(total: :desc)
    when 'total_asc'
      orders.order(total: :asc)
    else
      orders.order(created_at: :desc)
    end
  end
end
