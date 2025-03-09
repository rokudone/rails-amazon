class OrderProcessingJob < ApplicationJob
  queue_as :orders

  # 注文処理を行うジョブ
  def perform(order_id)
    # 注文情報を取得
    order = Order.find_by(id: order_id)

    # 注文が見つからない場合は終了
    return unless order

    # 注文が処理済みの場合は終了
    return if order.status == 'completed' || order.status == 'cancelled'

    # 注文処理を開始
    begin
      # 注文ステータスを処理中に更新
      update_order_status(order, 'processing', 'Order processing started')

      # 在庫確認
      check_inventory(order)

      # 支払い処理
      process_payment(order)

      # 注文確認メール送信
      send_confirmation_email(order)

      # 注文ステータスを完了に更新
      update_order_status(order, 'completed', 'Order processing completed')

      # 注文完了後の処理
      after_order_completed(order)
    rescue => e
      # エラーが発生した場合
      handle_error(order, e)
    end
  end

  private

  # 注文ステータスを更新
  def update_order_status(order, status, notes = nil)
    # 注文ステータスを更新
    order.update(status: status)

    # 注文ログを記録
    if defined?(OrderLog) && order.respond_to?(:order_logs)
      order.order_logs.create(
        status: status,
        notes: notes
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'order_status_updated',
        message: "Order #{order.id} status updated to #{status}",
        details: {
          order_id: order.id,
          status: status,
          notes: notes
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Order #{order.id} status updated to #{status}")
  end

  # 在庫確認
  def check_inventory(order)
    # 注文アイテムごとに在庫を確認
    order.order_items.each do |item|
      # 商品情報を取得
      product = item.product
      variant = item.product_variant

      # 在庫情報を取得
      inventory = if variant
                    variant.inventory
                  else
                    product.inventory
                  end

      # 在庫が存在しない場合はエラー
      unless inventory
        raise "Inventory not found for product #{product.id}"
      end

      # 在庫数が不足している場合はエラー
      if inventory.quantity < item.quantity
        raise "Insufficient stock for product #{product.id} (#{product.name}). Available: #{inventory.quantity}, Requested: #{item.quantity}"
      end

      # 在庫を減らす
      inventory.update(quantity: inventory.quantity - item.quantity)

      # 在庫移動を記録
      if defined?(StockMovement)
        StockMovement.create(
          inventory_id: inventory.id,
          quantity: -item.quantity,
          reason: 'order',
          reference_id: order.id,
          reference_type: 'Order'
        )
      end

      # 在庫アラートをチェック
      check_inventory_alert(inventory)
    end

    # 在庫確認完了を記録
    update_order_status(order, 'inventory_checked', 'Inventory check completed')
  end

  # 在庫アラートをチェック
  def check_inventory_alert(inventory)
    # 在庫アラートが定義されている場合
    if defined?(InventoryAlert) && inventory.respond_to?(:inventory_alerts)
      # 在庫アラートの閾値を取得
      threshold = inventory.inventory_alerts.where(alert_type: 'low_stock').first&.threshold || 5

      # 在庫が閾値を下回った場合
      if inventory.quantity <= threshold
        # 在庫アラートを作成
        InventoryAlert.create(
          inventory_id: inventory.id,
          alert_type: 'low_stock',
          message: "Low stock alert: #{inventory.quantity} items remaining",
          is_active: true
        )

        # 在庫補充ジョブを実行
        if defined?(InventoryReplenishmentJob)
          InventoryReplenishmentJob.perform_later(inventory.id)
        end
      end
    end
  end

  # 支払い処理
  def process_payment(order)
    # 支払い情報を取得
    payment = order.payments.pending.first

    # 支払いが存在しない場合はエラー
    unless payment
      raise "No pending payment found for order #{order.id}"
    end

    # 支払いサービスを使用して支払いを処理
    if defined?(PaymentService)
      payment_service = PaymentService.new(payment, order, order.user)
      result = payment_service.process_payment(
        order_id: order.id,
        payment_method_id: payment.payment_method_id,
        amount: payment.amount
      )

      # 支払いが失敗した場合はエラー
      unless result
        raise "Payment failed: #{payment_service.error_message}"
      end
    else
      # シミュレーション用
      payment.update(status: 'completed', transaction_id: SecureRandom.hex(10))
    end

    # 支払い処理完了を記録
    update_order_status(order, 'paid', 'Payment processing completed')
  end

  # 注文確認メール送信
  def send_confirmation_email(order)
    # 注文確認メールジョブを実行
    if defined?(OrderConfirmationJob)
      OrderConfirmationJob.perform_later(order.id)
    end
  end

  # 注文完了後の処理
  def after_order_completed(order)
    # 配送処理ジョブを実行
    if defined?(ShipmentProcessingJob)
      ShipmentProcessingJob.perform_later(order.id)
    end

    # カートをクリア
    clear_cart(order.user)

    # ポイント付与
    award_points(order)

    # 分析データ更新
    update_analytics(order)
  end

  # カートをクリア
  def clear_cart(user)
    # ユーザーのカートを取得
    cart = user.cart

    # カートが存在する場合はクリア
    if cart
      cart.cart_items.destroy_all
    end
  end

  # ポイント付与
  def award_points(order)
    # ユーザーリワードが定義されている場合
    if defined?(UserReward) && order.user.respond_to?(:user_rewards)
      # 注文金額に基づいてポイントを計算
      points = (order.total * 0.01).to_i # 1%のポイント付与

      # ポイントを付与
      order.user.user_rewards.create(
        reward_type: 'points',
        points: points,
        expires_at: 1.year.from_now
      )

      # ユーザーログに記録
      if defined?(UserLog)
        UserLog.create(
          user_id: order.user.id,
          action: 'points_awarded',
          details: {
            order_id: order.id,
            points: points
          }
        )
      end
    end
  end

  # 分析データ更新
  def update_analytics(order)
    # 分析データ更新ジョブを実行
    if defined?(AnalyticsUpdateJob)
      AnalyticsUpdateJob.perform_later('order_completed', { order_id: order.id })
    end
  end

  # エラー処理
  def handle_error(order, error)
    # エラーメッセージを取得
    error_message = error.message

    # 注文ステータスをエラーに更新
    update_order_status(order, 'error', "Error: #{error_message}")

    # エラーをログに記録
    Rails.logger.error("Order processing error for order #{order.id}: #{error_message}")
    Rails.logger.error(error.backtrace.join("\n"))

    # エラーを通知
    if defined?(ErrorHandler)
      ErrorHandler.handle_error(error, { order_id: order.id })
    end

    # 特定のエラータイプに応じた処理
    case error_message
    when /Insufficient stock/
      # 在庫不足の場合
      notify_inventory_shortage(order, error_message)
    when /Payment failed/
      # 支払い失敗の場合
      notify_payment_failure(order, error_message)
    else
      # その他のエラーの場合
      notify_general_error(order, error_message)
    end
  end

  # 在庫不足通知
  def notify_inventory_shortage(order, error_message)
    # 在庫管理者に通知
    if defined?(NotificationService)
      NotificationService.notify(
        recipient_type: 'role',
        recipient_id: 'inventory_manager',
        notification_type: 'inventory_shortage',
        title: 'Inventory Shortage',
        message: error_message,
        reference_id: order.id,
        reference_type: 'Order'
      )
    end
  end

  # 支払い失敗通知
  def notify_payment_failure(order, error_message)
    # ユーザーに通知
    if defined?(NotificationService)
      NotificationService.notify(
        recipient_type: 'user',
        recipient_id: order.user.id,
        notification_type: 'payment_failure',
        title: 'Payment Failed',
        message: 'Your payment could not be processed. Please update your payment information.',
        reference_id: order.id,
        reference_type: 'Order'
      )
    end
  end

  # 一般エラー通知
  def notify_general_error(order, error_message)
    # システム管理者に通知
    if defined?(NotificationService)
      NotificationService.notify(
        recipient_type: 'role',
        recipient_id: 'system_admin',
        notification_type: 'system_error',
        title: 'Order Processing Error',
        message: error_message,
        reference_id: order.id,
        reference_type: 'Order'
      )
    end
  end
end
