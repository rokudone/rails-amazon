class OrderItem < ApplicationRecord
  # 関連付け
  belongs_to :order
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :warehouse, optional: true
  belongs_to :shipment, optional: true
  belongs_to :return, optional: true
  has_one :gift_wrap, dependent: :destroy

  # バリデーション
  validates :sku, presence: true
  validates :name, presence: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :subtotal, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: ['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'returned'] }
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :tax_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :gift_wrap_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight, numericality: { greater_than: 0 }, allow_nil: true

  # コールバック
  before_validation :calculate_totals
  after_save :update_order_totals
  after_destroy :update_order_totals

  # スコープ
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :shipped, -> { where(status: 'shipped') }
  scope :delivered, -> { where(status: 'delivered') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :returned, -> { where(status: 'returned') }
  scope :digital, -> { where(is_digital: true) }
  scope :physical, -> { where(is_digital: false) }
  scope :gifts, -> { where(is_gift: true) }
  scope :by_product, ->(product_id) { where(product_id: product_id) }
  scope :by_variant, ->(variant_id) { where(product_variant_id: variant_id) }
  scope :by_warehouse, ->(warehouse_id) { where(warehouse_id: warehouse_id) }
  scope :by_shipment, ->(shipment_id) { where(shipment_id: shipment_id) }
  scope :by_return, ->(return_id) { where(return_id: return_id) }
  scope :by_sku, ->(sku) { where(sku: sku) }

  # カスタムメソッド
  def digital?
    is_digital
  end

  def physical?
    !is_digital
  end

  def gift?
    is_gift
  end

  def shipped?
    status == 'shipped' || status == 'delivered'
  end

  def delivered?
    status == 'delivered'
  end

  def cancelled?
    status == 'cancelled'
  end

  def returned?
    status == 'returned'
  end

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def discounted?
    discount_amount.present? && discount_amount > 0
  end

  def discount_percentage
    return 0 if discount_amount.blank? || discount_amount <= 0 || unit_price <= 0

    (discount_amount / (unit_price * quantity) * 100).round(2)
  end

  def original_total
    unit_price * quantity
  end

  def gift_wrap!
    return false if gift_wrap.present?

    create_gift_wrap(
      order: order,
      wrap_type: 'standard',
      include_gift_receipt: true,
      hide_prices: true,
      gift_message: gift_message,
      gift_from: order.user.profile.full_name,
      gift_to: gift_message.to_s.match(/To: (.+)/)&.captures&.first,
      wrap_cost: 3.99,
      is_gift_wrapped: true
    )
  end

  def update_quantity(new_quantity)
    return false if new_quantity <= 0

    old_quantity = quantity

    if update(quantity: new_quantity)
      # 在庫の予約数を更新
      if physical? && warehouse.present?
        inventory = Inventory.find_by(
          product_id: product_id,
          product_variant_id: product_variant_id,
          warehouse_id: warehouse_id
        )

        if inventory
          if new_quantity > old_quantity
            # 予約数を増やす
            inventory.reserve(new_quantity - old_quantity)
          elsif new_quantity < old_quantity
            # 予約数を減らす
            inventory.unreserve(old_quantity - new_quantity)
          end
        end
      end

      true
    else
      false
    end
  end

  def cancel!
    return false if cancelled? || returned?

    transaction do
      update(status: 'cancelled')

      # 在庫の予約を解除
      if physical? && warehouse.present?
        inventory = Inventory.find_by(
          product_id: product_id,
          product_variant_id: product_variant_id,
          warehouse_id: warehouse_id
        )

        inventory&.unreserve(quantity)
      end

      true
    end
  rescue => e
    errors.add(:base, "キャンセル処理中にエラーが発生しました: #{e.message}")
    false
  end

  def return!(return_reason = nil)
    return false if returned? || cancelled? || !shipped?

    transaction do
      # 返品レコードを作成
      return_record = Return.create!(
        return_number: "RET-#{order.order_number}-#{SecureRandom.alphanumeric(6).upcase}",
        order: order,
        user: order.user,
        status: 'requested',
        return_type: 'refund',
        return_reason: return_reason || 'customer_request',
        requested_at: Time.now,
        return_method: 'mail'
      )

      # 注文アイテムを返品に関連付ける
      update(
        status: 'returned',
        return_id: return_record.id,
        return_reason: return_reason
      )

      # 返品ログを作成
      order.order_logs.create!(
        action: 'item_returned',
        message: "商品 #{name} (SKU: #{sku}) が返品されました。理由: #{return_reason || '理由なし'}",
        reference_id: return_record.id.to_s,
        reference_type: 'return',
        source: 'system'
      )

      true
    end
  rescue => e
    errors.add(:base, "返品処理中にエラーが発生しました: #{e.message}")
    false
  end

  def assign_to_warehouse(warehouse)
    return false unless warehouse

    update(warehouse_id: warehouse.id)
  end

  def assign_to_shipment(shipment)
    return false unless shipment

    update(shipment_id: shipment.id, status: 'shipped')
  end

  private

  def calculate_totals
    self.tax_amount ||= 0
    self.discount_amount ||= 0
    self.gift_wrap_cost ||= 0

    if unit_price.present? && quantity.present?
      self.subtotal = unit_price * quantity
      self.total = subtotal - discount_amount + tax_amount + gift_wrap_cost
    end
  end

  def update_order_totals
    order.calculate_totals
    order.save
  end
end
