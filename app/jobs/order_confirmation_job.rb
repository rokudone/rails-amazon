class OrderConfirmationJob < ApplicationJob
  queue_as :mailers

  # 注文確認メールを送信するジョブ
  def perform(order_id)
    # 注文情報を取得
    order = Order.find_by(id: order_id)

    # 注文が見つからない場合は終了
    return unless order

    # ユーザー情報を取得
    user = order.user

    # ユーザーが見つからない場合は終了
    return unless user

    # メール送信
    OrderMailer.confirmation(order).deliver_now

    # ログ記録
    log_email_sent(order, user)
  end

  private

  # メール送信をログに記録
  def log_email_sent(order, user)
    # ユーザーログに記録
    if defined?(UserLog)
      UserLog.create(
        user_id: user.id,
        action: 'order_confirmation_email_sent',
        details: { order_id: order.id }
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'email_sent',
        message: "Order confirmation email sent to user #{user.id} for order #{order.id}",
        details: {
          user_id: user.id,
          order_id: order.id,
          email_type: 'order_confirmation'
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Order confirmation email sent to user #{user.id} for order #{order.id}")
  end
end
