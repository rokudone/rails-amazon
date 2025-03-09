class OrderLog < ApplicationRecord
  # 関連付け
  belongs_to :order
  belongs_to :user, optional: true

  # バリデーション
  validates :action, presence: true

  # スコープ
  scope :by_action, ->(action) { where(action: action) }
  scope :by_order, ->(order_id) { where(order_id: order_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :by_source, ->(source) { where(source: source) }
  scope :by_reference, ->(type, id) { where(reference_type: type, reference_id: id) }
  scope :customer_visible, -> { where(is_customer_visible: true) }
  scope :admin_only, -> { where(is_customer_visible: false) }
  scope :notifications_sent, -> { where(is_notification_sent: true) }
  scope :notifications_pending, -> { where(is_notification_sent: false) }
  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }
  scope :status_changes, -> { where(action: 'status_changed') }
  scope :payment_events, -> { where("action LIKE ?", "payment%") }
  scope :shipping_events, -> { where("action LIKE ?", "ship%") }
  scope :return_events, -> { where("action LIKE ?", "return%") }

  # カスタムメソッド
  def customer_visible?
    is_customer_visible
  end

  def notification_sent?
    is_notification_sent
  end

  def mark_notification_sent!
    update(
      is_notification_sent: true,
      notification_sent_at: Time.now
    )
  end

  def status_change?
    action == 'status_changed'
  end

  def payment_event?
    action.start_with?('payment')
  end

  def shipping_event?
    action.start_with?('ship')
  end

  def return_event?
    action.start_with?('return')
  end

  def action_label
    case action
    when 'created'
      '注文作成'
    when 'updated'
      '注文更新'
    when 'status_changed'
      'ステータス変更'
    when 'payment_received'
      '支払い受領'
    when 'payment_failed'
      '支払い失敗'
    when 'payment_refunded'
      '返金'
    when 'shipped'
      '出荷'
    when 'delivered'
      '配達完了'
    when 'cancelled'
      'キャンセル'
    when 'return_requested'
      '返品リクエスト'
    when 'return_approved'
      '返品承認'
    when 'return_received'
      '返品受領'
    when 'return_completed'
      '返品完了'
    when 'return_rejected'
      '返品拒否'
    when 'invoice_created'
      '請求書作成'
    when 'invoice_sent'
      '請求書送信'
    when 'invoice_paid'
      '請求書支払い'
    when 'invoice_cancelled'
      '請求書キャンセル'
    when 'shipment_created'
      '出荷作成'
    when 'item_returned'
      '商品返品'
    else
      action
    end
  end

  def source_label
    case source
    when 'system'
      'システム'
    when 'admin'
      '管理者'
    when 'customer'
      '顧客'
    when 'api'
      'API'
    else
      source
    end
  end

  def reference_label
    return nil if reference_type.blank? || reference_id.blank?

    case reference_type
    when 'payment'
      "支払い ##{reference_id}"
    when 'shipment'
      "出荷 ##{reference_id}"
    when 'return'
      "返品 ##{reference_id}"
    when 'invoice'
      "請求書 ##{reference_id}"
    else
      "#{reference_type} ##{reference_id}"
    end
  end

  def formatted_created_at
    created_at.strftime('%Y年%m月%d日 %H:%M:%S')
  end

  def status_change_description
    return nil unless status_change?

    "#{previous_status || '不明'} → #{new_status || '不明'}"
  end

  def self.log_order_event(order, action, options = {})
    create!(
      order: order,
      user_id: options[:user_id],
      action: action,
      previous_status: options[:previous_status],
      new_status: options[:new_status],
      message: options[:message],
      data_changes: options[:data_changes],
      ip_address: options[:ip_address],
      user_agent: options[:user_agent],
      source: options[:source] || 'system',
      reference_id: options[:reference_id],
      reference_type: options[:reference_type],
      notes: options[:notes],
      is_customer_visible: options[:is_customer_visible] || false
    )
  end
end
