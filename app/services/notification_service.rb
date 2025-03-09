class NotificationService
  attr_reader :user, :notification

  def initialize(user = nil, notification = nil)
    @user = user
    @notification = notification
  end

  # 通知作成
  def create(params)
    return false unless @user

    @notification = @user.notifications.new(params)

    if @notification.save
      # 通知の送信
      send_notification

      true
    else
      false
    end
  end

  # 通知送信
  def send_notification
    return false unless @notification

    # 通知タイプに応じた送信処理
    case @notification.notification_type
    when 'email'
      send_email_notification
    when 'push'
      send_push_notification
    when 'sms'
      send_sms_notification
    when 'in_app'
      # アプリ内通知は作成時に自動的に送信される
      true
    else
      # デフォルトはアプリ内通知のみ
      true
    end
  end

  # 通知管理
  def manage_notifications(options = {})
    return [] unless @user

    notifications = @user.notifications

    # 既読/未読でフィルタリング
    notifications = notifications.where(read: options[:read]) if options[:read].present?

    # タイプでフィルタリング
    notifications = notifications.where(notification_type: options[:type]) if options[:type].present?

    # 日付範囲でフィルタリング
    notifications = notifications.where('created_at >= ?', options[:start_date]) if options[:start_date].present?
    notifications = notifications.where('created_at <= ?', options[:end_date]) if options[:end_date].present?

    # ソート
    case options[:sort]
    when 'newest'
      notifications = notifications.order(created_at: :desc)
    when 'oldest'
      notifications = notifications.order(created_at: :asc)
    when 'priority'
      notifications = notifications.order(priority: :desc)
    else
      notifications = notifications.order(created_at: :desc)
    end

    # ページネーション
    page = options[:page] || 1
    per_page = options[:per_page] || 20

    notifications.page(page).per(per_page)
  end

  # 通知を既読にする
  def mark_as_read
    return false unless @notification

    @notification.update(read: true, read_at: Time.current)
  end

  # すべての通知を既読にする
  def mark_all_as_read
    return false unless @user

    @user.notifications.update_all(read: true, read_at: Time.current)

    true
  end

  # 通知を削除する
  def delete_notification
    return false unless @notification

    @notification.destroy

    true
  end

  # すべての通知を削除する
  def delete_all_notifications
    return false unless @user

    @user.notifications.destroy_all

    true
  end

  # 通知設定の更新
  def update_notification_preferences(preferences)
    return false unless @user

    user_preference = @user.user_preference || @user.create_user_preference

    user_preference.update(
      notification_email: preferences[:email],
      notification_push: preferences[:push],
      notification_sms: preferences[:sms],
      marketing_email: preferences[:marketing_email],
      marketing_push: preferences[:marketing_push],
      marketing_sms: preferences[:marketing_sms]
    )
  end

  # 通知の一括送信
  def send_bulk_notifications(users, params)
    success_count = 0
    failed_count = 0

    users.each do |user|
      notification = user.notifications.new(params)

      if notification.save
        # 通知の送信
        notification_service = NotificationService.new(user, notification)
        notification_service.send_notification

        success_count += 1
      else
        failed_count += 1
      end
    end

    {
      success_count: success_count,
      failed_count: failed_count,
      total: users.count
    }
  end

  # 未読通知数の取得
  def unread_count
    return 0 unless @user

    @user.notifications.where(read: false).count
  end

  # エラーメッセージの取得
  def error_message
    @notification&.errors&.full_messages&.join(', ')
  end

  private

  # メール通知の送信
  def send_email_notification
    return false unless @notification && @user

    # ユーザーのメール通知設定を確認
    user_preference = @user.user_preference
    return false if user_preference && user_preference.notification_email == false

    # メール送信処理
    # NotificationMailer.send_notification(@user, @notification).deliver_later

    true
  end

  # プッシュ通知の送信
  def send_push_notification
    return false unless @notification && @user

    # ユーザーのプッシュ通知設定を確認
    user_preference = @user.user_preference
    return false if user_preference && user_preference.notification_push == false

    # ユーザーのデバイストークンを取得
    device_tokens = @user.user_devices.pluck(:push_token).compact
    return false if device_tokens.empty?

    # プッシュ通知送信処理
    # FCMやAPNsなどのサービスを使用して送信
    # PushNotificationService.send_notification(device_tokens, @notification)

    true
  end

  # SMS通知の送信
  def send_sms_notification
    return false unless @notification && @user

    # ユーザーのSMS通知設定を確認
    user_preference = @user.user_preference
    return false if user_preference && user_preference.notification_sms == false

    # ユーザーの電話番号を確認
    return false unless @user.phone_number.present?

    # SMS送信処理
    # TwilioやAWSなどのサービスを使用して送信
    # SmsService.send_message(@user.phone_number, @notification.content)

    true
  end
end
