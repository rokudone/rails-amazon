class SupplierOrder < ApplicationRecord
  # 関連付け
  belongs_to :warehouse
  has_many :stock_movements, dependent: :restrict_with_error

  # バリデーション
  validates :order_number, presence: true, uniqueness: true
  validates :supplier_name, presence: true
  validates :order_date, presence: true
  validates :status, inclusion: { in: ['draft', 'submitted', 'confirmed', 'shipped', 'partially_received', 'received', 'cancelled'] }
  validates :payment_status, inclusion: { in: ['pending', 'partial', 'paid'] }
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :tax_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :shipping_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :exchange_rate, numericality: { greater_than: 0 }

  # コールバック
  before_validation :generate_order_number, on: :create

  # スコープ
  scope :draft, -> { where(status: 'draft') }
  scope :submitted, -> { where(status: 'submitted') }
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :shipped, -> { where(status: 'shipped') }
  scope :partially_received, -> { where(status: 'partially_received') }
  scope :received, -> { where(status: 'received') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :pending_payment, -> { where(payment_status: 'pending') }
  scope :partial_payment, -> { where(payment_status: 'partial') }
  scope :paid, -> { where(payment_status: 'paid') }
  scope :by_supplier, ->(supplier_name) { where('supplier_name LIKE ?', "%#{supplier_name}%") }
  scope :by_warehouse, ->(warehouse_id) { where(warehouse_id: warehouse_id) }
  scope :by_date_range, ->(start_date, end_date) { where(order_date: start_date..end_date) }
  scope :expected_delivery, ->(date) { where(expected_delivery_date: date) }
  scope :overdue, -> { where('expected_delivery_date < ? AND status NOT IN (?)', Date.today, ['received', 'cancelled']) }
  scope :recent, -> { order(created_at: :desc) }

  # ステータス管理
  def submit!
    return false if status != 'draft'

    update(status: 'submitted')
  end

  def confirm!
    return false if status != 'submitted'

    update(status: 'confirmed')
  end

  def ship!
    return false if !['confirmed', 'submitted'].include?(status)

    update(status: 'shipped')
  end

  def receive_partially!
    return false if !['shipped', 'confirmed'].include?(status)

    update(status: 'partially_received')
  end

  def receive_fully!
    return false if !['shipped', 'partially_received', 'confirmed'].include?(status)

    update(status: 'received', actual_delivery_date: Date.today)
  end

  def cancel!
    return false if ['received', 'cancelled'].include?(status)

    update(status: 'cancelled')
  end

  def mark_as_paid!
    update(payment_status: 'paid')
  end

  def mark_as_partially_paid!
    update(payment_status: 'partial')
  end

  # カスタムメソッド
  def total_items
    return 0 if line_items.blank?

    line_items.sum { |item| item['quantity'].to_i }
  end

  def total_unique_items
    return 0 if line_items.blank?

    line_items.size
  end

  def days_until_expected_delivery
    return nil if expected_delivery_date.blank?

    (expected_delivery_date - Date.today).to_i
  end

  def overdue?
    expected_delivery_date.present? &&
    expected_delivery_date < Date.today &&
    !['received', 'cancelled'].include?(status)
  end

  def days_overdue
    return 0 unless overdue?

    (Date.today - expected_delivery_date).to_i
  end

  def calculate_total_amount
    return 0 if line_items.blank?

    subtotal = line_items.sum { |item| item['unit_price'].to_f * item['quantity'].to_i }
    tax = tax_amount || 0
    shipping = shipping_cost || 0

    subtotal + tax + shipping
  end

  def update_total_amount!
    update(total_amount: calculate_total_amount)
  end

  def receive_items!(received_items)
    return false if received_items.blank? || !['shipped', 'confirmed', 'partially_received'].include?(status)

    transaction do
      received_items.each do |item|
        product_id = item['product_id']
        variant_id = item['variant_id']
        quantity = item['quantity'].to_i
        unit_cost = item['unit_cost'].to_f

        # 在庫を探すか作成する
        inventory = Inventory.find_or_initialize_by(
          product_id: product_id,
          product_variant_id: variant_id.presence,
          warehouse_id: warehouse_id
        )

        if inventory.new_record?
          product = Product.find(product_id)
          inventory.sku = "#{product.sku}-#{warehouse.code}"
          inventory.quantity = 0
          inventory.reserved_quantity = 0
          inventory.minimum_stock_level = 10
          inventory.status = 'active'
          inventory.save!
        end

        # 在庫を増やす
        inventory.restock(quantity, item['batch_number'], item['expiry_date'], unit_cost)

        # 在庫移動記録を作成
        StockMovement.create!(
          inventory: inventory,
          destination_warehouse: warehouse,
          quantity: quantity,
          movement_type: 'inbound',
          reference_number: order_number,
          supplier_order_id: id,
          status: 'completed',
          completed_at: Time.now,
          unit_cost: unit_cost,
          batch_number: item['batch_number'],
          expiry_date: item['expiry_date']
        )
      end

      # 注文ステータスを更新
      if received_items.size == total_unique_items
        update(status: 'received', actual_delivery_date: Date.today)
      else
        update(status: 'partially_received')
      end

      true
    end
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, "入荷処理中にエラーが発生しました: #{e.message}")
    false
  end

  private

  def generate_order_number
    return if order_number.present?

    date_part = Date.today.strftime('%Y%m%d')
    random_part = SecureRandom.alphanumeric(6).upcase
    self.order_number = "PO-#{date_part}-#{random_part}"
  end
end
