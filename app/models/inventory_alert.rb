class InventoryAlert < ApplicationRecord
  # 関連付け
  belongs_to :inventory
  belongs_to :product, optional: true
  belongs_to :warehouse, optional: true

  # バリデーション
  validates :alert_type, presence: true, inclusion: { in: ['low_stock', 'overstock', 'expiry', 'no_movement'] }
  validates :threshold_value, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :frequency_days, numericality: { only_integer: true, greater_than: 0 }
  validates :notification_method, inclusion: { in: ['email', 'sms', 'dashboard', 'all'] }, allow_nil: true
  validates :severity, inclusion: { in: ['low', 'medium', 'high', 'critical'] }
  validates :auto_reorder_quantity, numericality: { only_integer: true, greater_than: 0 }, if: :auto_reorder?

  # スコープ
  scope :active, -> { where(active: true) }
  scope :by_alert_type, ->(type) { where(alert_type: type) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :by_product, ->(product_id) { where(product_id: product_id) }
  scope :by_warehouse, ->(warehouse_id) { where(warehouse_id: warehouse_id) }
  scope :by_inventory, ->(inventory_id) { where(inventory_id: inventory_id) }
  scope :triggered_recently, ->(days = 7) { where('last_triggered_at >= ?', Time.now - days.days) }
  scope :not_triggered_recently, ->(days = 7) { where('last_triggered_at IS NULL OR last_triggered_at < ?', Time.now - days.days) }
  scope :due_for_notification, -> { active.where('last_triggered_at IS NULL OR last_triggered_at < ?', Time.now - Arel.sql('frequency_days * interval \'1 day\'')) }

  # カスタムメソッド
  def trigger!
    self.last_triggered_at = Time.now
    self.trigger_count += 1
    save
  end

  def should_notify?
    active? && (last_triggered_at.nil? || Time.now - last_triggered_at > frequency_days.days)
  end

  def notification_recipients_array
    notification_recipients.to_s.split(',').map(&:strip)
  end

  def formatted_message
    if message_template.present?
      template = message_template
    else
      case alert_type
      when 'low_stock'
        template = "低在庫アラート: #{inventory.product.name} (SKU: #{inventory.sku}) の在庫が #{inventory.quantity} 個になりました。最小在庫レベル: #{inventory.minimum_stock_level}"
      when 'overstock'
        template = "過剰在庫アラート: #{inventory.product.name} (SKU: #{inventory.sku}) の在庫が #{inventory.quantity} 個になりました。最大在庫レベル: #{inventory.maximum_stock_level}"
      when 'expiry'
        template = "期限切れアラート: #{inventory.product.name} (SKU: #{inventory.sku}) の在庫が #{inventory.days_until_expiry} 日後に期限切れになります。"
      when 'no_movement'
        template = "在庫移動なしアラート: #{inventory.product.name} (SKU: #{inventory.sku}) の在庫が #{threshold_value} 日間移動していません。"
      else
        template = "在庫アラート: #{inventory.product.name} (SKU: #{inventory.sku})"
      end
    end

    template
  end

  def check_condition
    case alert_type
    when 'low_stock'
      inventory.quantity <= threshold_value
    when 'overstock'
      inventory.quantity >= threshold_value
    when 'expiry'
      inventory.expiry_date.present? && (inventory.expiry_date - Date.today).to_i <= threshold_value
    when 'no_movement'
      last_movement = StockMovement.where(inventory_id: inventory_id).order(created_at: :desc).first
      last_movement.nil? || (Date.today - last_movement.created_at.to_date).to_i >= threshold_value
    else
      false
    end
  end
end
