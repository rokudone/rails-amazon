class ShipmentNotificationJob < ApplicationJob
  queue_as :mailers

  # 配送通知メールを送信するジョブ
  def perform(shipment_id)
    # 配送情報を取得
    shipment = Shipment.find_by(id: shipment_id)

    # 配送情報が見つからない場合は終了
    return unless shipment

    # 注文情報を取得
    order = shipment.order

    # 注文が見つからない場合は終了
    return unless order

    # ユーザー情報を取得
    user = order.user

    # ユーザーが見つからない場合は終了
    return unless user

    # 追跡情報を取得
    tracking_info = get_tracking_info(shipment)

    # メール送信
    ShipmentMailer.notification(shipment, tracking_info).deliver_now

    # ログ記録
    log_email_sent(shipment, order, user, tracking_info)
  end

  private

  # 追跡情報を取得
  def get_tracking_info(shipment)
    # 追跡情報を取得
    tracking_info = {
      carrier: shipment.carrier,
      tracking_number: shipment.tracking_number,
      tracking_url: shipment.tracking_url,
      estimated_delivery_date: shipment.estimated_delivery_date,
      shipped_at: shipment.shipped_at,
      status: shipment.status
    }

    # 追跡履歴を取得
    if shipment.respond_to?(:shipment_trackings) && shipment.shipment_trackings.present?
      tracking_info[:history] = shipment.shipment_trackings.order(tracked_at: :desc).map do |tracking|
        {
          status: tracking.status,
          location: tracking.location,
          description: tracking.description,
          tracked_at: tracking.tracked_at
        }
      end
    end

    tracking_info
  end

  # メール送信をログに記録
  def log_email_sent(shipment, order, user, tracking_info)
    # ユーザーログに記録
    if defined?(UserLog)
      UserLog.create(
        user_id: user.id,
        action: 'shipment_notification_email_sent',
        details: {
          shipment_id: shipment.id,
          order_id: order.id,
          tracking_number: tracking_info[:tracking_number]
        }
      )
    end

    # イベントログに記録
    if defined?(EventLog)
      EventLog.create(
        event_type: 'email_sent',
        message: "Shipment notification email sent to user #{user.id} for order #{order.id}",
        details: {
          user_id: user.id,
          order_id: order.id,
          shipment_id: shipment.id,
          email_type: 'shipment_notification',
          tracking_info: tracking_info
        }
      )
    end

    # Railsログに記録
    Rails.logger.info("Shipment notification email sent to user #{user.id} for order #{order.id} with tracking number #{tracking_info[:tracking_number]}")
  end
end
