class StockMovement < ApplicationRecord
  # 関連付け
  belongs_to :inventory
  belongs_to :source_warehouse, class_name: 'Warehouse', optional: true
  belongs_to :destination_warehouse, class_name: 'Warehouse', optional: true
  belongs_to :order, optional: true
  belongs_to :supplier_order, optional: true
  belongs_to :return, optional: true

  # バリデーション
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :movement_type, presence: true, inclusion: { in: ['inbound', 'outbound', 'transfer', 'return', 'adjustment', 'disposal'] }
  validates :status, inclusion: { in: ['pending', 'in_progress', 'completed', 'cancelled'] }
  validates :source_warehouse, presence: true, if: -> { movement_type == 'transfer' || movement_type == 'outbound' }
  validates :destination_warehouse, presence: true, if: -> { movement_type == 'transfer' || movement_type == 'inbound' }
  validates :order, presence: true, if: -> { movement_type == 'outbound' && supplier_order.blank? && return_id.blank? }
  validates :supplier_order, presence: true, if: -> { movement_type == 'inbound' && order.blank? && return_id.blank? }
  validates :return, presence: true, if: -> { movement_type == 'return' }
  validates :unit_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # コールバック
  before_validation :calculate_total_cost
  before_save :update_inventory_quantity, if: -> { status_changed? && status == 'completed' }

  # スコープ
  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :by_movement_type, ->(type) { where(movement_type: type) }
  scope :by_inventory, ->(inventory_id) { where(inventory_id: inventory_id) }
  scope :by_source_warehouse, ->(warehouse_id) { where(source_warehouse_id: warehouse_id) }
  scope :by_destination_warehouse, ->(warehouse_id) { where(destination_warehouse_id: warehouse_id) }
  scope :by_order, ->(order_id) { where(order_id: order_id) }
  scope :by_supplier_order, ->(supplier_order_id) { where(supplier_order_id: supplier_order_id) }
  scope :by_return, ->(return_id) { where(return_id: return_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # カスタムメソッド
  def complete!
    return false if status == 'completed' || status == 'cancelled'

    update(status: 'completed', completed_at: Time.now)
    true
  end

  def cancel!
    return false if status == 'completed'

    update(status: 'cancelled')
    true
  end

  def inbound?
    movement_type == 'inbound'
  end

  def outbound?
    movement_type == 'outbound'
  end

  def transfer?
    movement_type == 'transfer'
  end

  def return?
    movement_type == 'return'
  end

  def adjustment?
    movement_type == 'adjustment'
  end

  def disposal?
    movement_type == 'disposal'
  end

  def reference
    if order.present?
      "Order ##{order.order_number}"
    elsif supplier_order.present?
      "Supplier Order ##{supplier_order.order_number}"
    elsif self.return.present?
      "Return ##{self.return.return_number}"
    else
      reference_number
    end
  end

  private

  def calculate_total_cost
    if unit_cost.present? && quantity.present?
      self.total_cost = unit_cost * quantity
    end
  end

  def update_inventory_quantity
    case movement_type
    when 'inbound'
      inventory.update(
        quantity: inventory.quantity + quantity,
        last_restock_date: Date.today
      )
    when 'outbound'
      new_quantity = [inventory.quantity - quantity, 0].max
      inventory.update(quantity: new_quantity)
    when 'transfer'
      if source_warehouse.present? && destination_warehouse.present?
        # 元の在庫から減らす
        source_inventory = inventory
        source_inventory.update(quantity: [source_inventory.quantity - quantity, 0].max)

        # 移動先の在庫を探すか作成する
        destination_inventory = Inventory.find_or_initialize_by(
          product_id: source_inventory.product_id,
          product_variant_id: source_inventory.product_variant_id,
          warehouse_id: destination_warehouse.id
        )

        if destination_inventory.new_record?
          destination_inventory.sku = "#{source_inventory.sku}-#{destination_warehouse.code}"
          destination_inventory.quantity = 0
          destination_inventory.reserved_quantity = 0
          destination_inventory.minimum_stock_level = source_inventory.minimum_stock_level
          destination_inventory.maximum_stock_level = source_inventory.maximum_stock_level
          destination_inventory.reorder_point = source_inventory.reorder_point
          destination_inventory.status = source_inventory.status
        end

        # 移動先の在庫を増やす
        destination_inventory.quantity += quantity
        destination_inventory.save
      end
    when 'return'
      inventory.update(quantity: inventory.quantity + quantity)
    when 'adjustment'
      inventory.update(quantity: [inventory.quantity + quantity, 0].max)
    when 'disposal'
      inventory.update(quantity: [inventory.quantity - quantity, 0].max)
    end
  end
end
