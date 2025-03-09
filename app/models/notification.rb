class Notification < ApplicationRecord
  # 関連付け
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  # バリデーション
  validates :notification_type, presence: true
  validates :title, presence: true

  # コールバック
  before_save :set_read_at, if: -> { is_read_changed? && is_read? }
  before_save :set_sent_at, if: -> { is_sent_changed? && is_sent? }

  # スコープ
  scope :unread, -> { where(is_read: false) }
  scope :read, -> { where(is_read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :actionable, -> { where(is_actionable: true) }
  scope :non_actionable, -> { where(is_actionable: false) }
  scope :sent, -> { where(is_sent: true) }
  scope :unsent, -> { where(is_sent: false) }
  scope :unexpired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at IS NOT NULL AND expires_at <= ?', Time.current) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :high_priority, -> { where('priority > 0') }
  scope :by_delivery_method, ->(method) { where(delivery_method: method) }

  # カスタムメソッド
  def mark_as_read!
    update(is_read: true, read_at: Time.current)
  end

  def mark_as_unread!
    update(is_read: false, read_at: nil)
  end

  def mark_as_sent!
    update(is_sent: true, sent_at: Time.current)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def unexpired?
    expires_at.nil? || expires_at > Time.current
  end

  def high_priority?
    priority > 0
  end

  def actionable?
    is_actionable?
  end

  def action_url_with_tracking
    return nil unless action_url.present?

    uri = URI.parse(action_url)
    params = URI.decode_www_form(uri.query || '')
    params << ['notification_id', id.to_s]
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end

  def notification_type_name
    case notification_type
    when 'order_status'
      '注文状況'
    when 'price_drop'
      '値下げ'
    when 'back_in_stock'
      '在庫あり'
    when 'shipping_update'
      '配送状況'
    when 'payment_update'
      '支払い状況'
    when 'review_request'
      'レビュー依頼'
    when 'promotion'
      'プロモーション'
    when 'system'
      'システム'
    else
      notification_type.humanize
    end
  end

  def priority_name
    case priority
    when 0
      '通常'
    when 1
      '重要'
    when 2
      '緊急'
    else
      '通常'
    end
  end

  def delivery_method_name
    case delivery_method
    when 'in_app'
      'アプリ内'
    when 'email'
      'メール'
    when 'sms'
      'SMS'
    when 'push'
      'プッシュ通知'
    else
      delivery_method.humanize
    end
  end

  def time_ago
    time_diff = Time.current - created_at

    if time_diff < 1.minute
      "たった今"
    elsif time_diff < 1.hour
      "#{(time_diff / 1.minute).to_i}分前"
    elsif time_diff < 1.day
      "#{(time_diff / 1.hour).to_i}時間前"
    elsif time_diff < 7.days
      "#{(time_diff / 1.day).to_i}日前"
    elsif time_diff < 30.days
      "#{(time_diff / 7.days).to_i}週間前"
    else
      created_at.strftime('%Y年%m月%d日')
    end
  end

  # クラスメソッド
  def self.mark_all_as_read!(user_id)
    where(user_id: user_id, is_read: false).update_all(is_read: true, read_at: Time.current)
  end

  def self.create_notification!(user, attributes = {})
    notification = user.notifications.create!(attributes)

    # 通知の送信処理（実装は別途必要）
    notification.send_notification if notification.persisted?

    notification
  end

  private

  def set_read_at
    self.read_at = Time.current
  end

  def set_sent_at
    self.sent_at = Time.current
  end

  def send_notification
    # 通知の送信処理（実装は別途必要）
    # delivery_methodに基づいて適切な送信方法を選択
    case delivery_method
    when 'email'
      # メール送信処理
    when 'sms'
      # SMS送信処理
    when 'push'
      # プッシュ通知送信処理
    end

    mark_as_sent! unless is_sent?
  end
end
