class Warehouse < ApplicationRecord
  # 関連付け
  has_many :inventories, dependent: :restrict_with_error
  has_many :stock_movements_as_source, class_name: 'StockMovement', foreign_key: 'source_warehouse_id'
  has_many :stock_movements_as_destination, class_name: 'StockMovement', foreign_key: 'destination_warehouse_id'
  has_many :inventory_alerts
  has_many :inventory_forecasts
  has_many :supplier_orders
  has_many :shipments
  has_many :order_items

  # バリデーション
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :address, presence: true
  validates :city, presence: true
  validates :postal_code, presence: true
  validates :country, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

  # スコープ
  scope :active, -> { where(active: true) }
  scope :by_country, ->(country) { where(country: country) }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_type, ->(type) { where(warehouse_type: type) }
  scope :with_capacity_over, ->(capacity) { where('capacity > ?', capacity) }

  # カスタムメソッド
  def full_address
    [address, city, state, postal_code, country].compact.join(', ')
  end

  def current_inventory_count
    inventories.sum(:quantity)
  end

  def available_capacity
    return nil if capacity.nil?
    capacity - current_inventory_count
  end

  def capacity_percentage
    return nil if capacity.nil? || capacity.zero?
    (current_inventory_count.to_f / capacity * 100).round(2)
  end

  def at_capacity?
    return false if capacity.nil?
    current_inventory_count >= capacity
  end

  def low_stock_items(threshold = 10)
    inventories.where('quantity <= ?', threshold)
  end
end
