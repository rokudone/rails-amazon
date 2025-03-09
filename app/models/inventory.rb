class Inventory < ApplicationRecord
  # 関連付け
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :warehouse
  has_many :stock_movements, dependent: :restrict_with_error
  has_many :inventory_alerts, dependent: :destroy

  # バリデーション
  validates :sku, presence: true, uniqueness: true
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reserved_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :minimum_stock_level, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :maximum_stock_level, numericality: { only_integer: true, greater_than: :minimum_stock_level, allow_nil: true }, if: -> { minimum_stock_level.present? && maximum_stock_level.present? }
  validates :reorder_point, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :unit_cost, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validate :unique_product_warehouse_variant_combination

  # コールバック
  before_save :update_available_quantity
  before_save :check_stock_alerts

  # スコープ
  scope :active, -> { where(status: 'active') }
  scope :low_stock, -> { where('quantity <= minimum_stock_level') }
  scope :out_of_stock, -> { where(quantity: 0) }
  scope :in_stock, -> { where('quantity > 0') }
  scope :by_warehouse, ->(warehouse_id) { where(warehouse_id: warehouse_id) }
  scope :by_product, ->(product_id) { where(product_id: product_id) }
  scope :by_variant, ->(variant_id) { where(product_variant_id: variant_id) }
  scope :expiring_soon, ->(days = 30) { where('expiry_date IS NOT NULL AND expiry_date <= ?', Date.today + days.days) }
  scope :recently_restocked, ->(days = 7) { where('last_restock_date >= ?', Date.today - days.days) }

  # カスタムメソッド
  def low_stock?
    minimum_stock_level.present? && quantity <= minimum_stock_level
  end

  def out_of_stock?
    quantity.zero?
  end

  def overstock?
    maximum_stock_level.present? && quantity > maximum_stock_level
  end

  def needs_reorder?
    reorder_point.present? && quantity <= reorder_point
  end

  def days_until_expiry
    return nil if expiry_date.blank?
    (expiry_date - Date.today).to_i
  end

  def expired?
    expiry_date.present? && expiry_date < Date.today
  end

  def restock(amount, batch_number = nil, expiry_date = nil, cost = nil)
    return false if amount <= 0

    transaction do
      self.quantity += amount
      self.last_restock_date = Date.today
      self.batch_number = batch_number if batch_number.present?
      self.expiry_date = expiry_date if expiry_date.present?
      self.unit_cost = cost if cost.present?
      save!

      StockMovement.create!(
        inventory: self,
        destination_warehouse: warehouse,
        quantity: amount,
        movement_type: 'inbound',
        reference_number: "RESTOCK-#{Time.now.to_i}",
        status: 'completed',
        completed_at: Time.now,
        unit_cost: cost,
        batch_number: batch_number,
        expiry_date: expiry_date
      )

      true
    end
  rescue ActiveRecord::RecordInvalid
    false
  end

  def reserve(amount)
    return false if amount <= 0 || amount > available_quantity

    self.reserved_quantity += amount
    save
  end

  def unreserve(amount)
    return false if amount <= 0 || amount > reserved_quantity

    self.reserved_quantity -= amount
    save
  end

  def transfer_to(destination_warehouse, amount, reference = nil)
    return false if amount <= 0 || amount > available_quantity

    transaction do
      # 元の在庫から減らす
      self.quantity -= amount
      save!

      # 移動先の在庫を探すか作成する
      destination_inventory = Inventory.find_or_initialize_by(
        product_id: product_id,
        product_variant_id: product_variant_id,
        warehouse_id: destination_warehouse.id
      )

      if destination_inventory.new_record?
        destination_inventory.sku = "#{sku}-#{destination_warehouse.code}"
        destination_inventory.quantity = 0
        destination_inventory.reserved_quantity = 0
        destination_inventory.minimum_stock_level = minimum_stock_level
        destination_inventory.maximum_stock_level = maximum_stock_level
        destination_inventory.reorder_point = reorder_point
        destination_inventory.status = status
      end

      # 移動先の在庫を増やす
      destination_inventory.quantity += amount
      destination_inventory.save!

      # 在庫移動記録を作成
      StockMovement.create!(
        inventory: self,
        source_warehouse: warehouse,
        destination_warehouse: destination_warehouse,
        quantity: amount,
        movement_type: 'transfer',
        reference_number: reference || "TRANSFER-#{Time.now.to_i}",
        status: 'completed',
        completed_at: Time.now,
        unit_cost: unit_cost,
        batch_number: batch_number,
        expiry_date: expiry_date
      )

      true
    end
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  def update_available_quantity
    self.available_quantity = [quantity - reserved_quantity, 0].max
  end

  def check_stock_alerts
    if low_stock? && status == 'active'
      inventory_alerts.find_or_create_by(
        alert_type: 'low_stock',
        threshold_value: minimum_stock_level
      )
    elsif overstock? && status == 'active'
      inventory_alerts.find_or_create_by(
        alert_type: 'overstock',
        threshold_value: maximum_stock_level
      )
    end
  end

  def unique_product_warehouse_variant_combination
    query = Inventory.where(product_id: product_id, warehouse_id: warehouse_id)
    query = query.where(product_variant_id: product_variant_id) if product_variant_id.present?
    query = query.where.not(id: id) if persisted?

    if query.exists?
      errors.add(:base, 'この商品と倉庫の組み合わせはすでに存在します')
    end
  end
end
