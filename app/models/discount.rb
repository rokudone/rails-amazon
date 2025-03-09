class Discount < ApplicationRecord
  # 関連付け
  belongs_to :product, optional: true
  belongs_to :category, optional: true
  belongs_to :brand, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  # バリデーション
  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :discount_type, presence: true
  validates :discount_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :minimum_purchase_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :usage_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :end_date_after_start_date
  validate :target_present

  # コールバック
  before_save :set_status

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :expired, -> { where('end_date < ?', Time.current) }
  scope :by_type, ->(type) { where(discount_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :automatic, -> { where(is_automatic: true) }
  scope :manual, -> { where(is_automatic: false) }
  scope :combinable, -> { where(is_combinable: true) }
  scope :by_priority, -> { order(priority: :desc) }
  scope :for_product, ->(product_id) { where(product_id: product_id) }
  scope :for_category, ->(category_id) { where(category_id: category_id) }
  scope :for_brand, ->(brand_id) { where(brand_id: brand_id) }

  # カスタムメソッド
  def active?
    is_active && current?
  end

  def current?
    start_date <= Time.current && end_date >= Time.current
  end

  def upcoming?
    start_date > Time.current
  end

  def expired?
    end_date < Time.current
  end

  def activate!
    update(is_active: true)
  end

  def deactivate!
    update(is_active: false)
  end

  def increment_usage!
    increment!(:usage_count)
  end

  def usage_limit_reached?
    usage_limit.present? && usage_count >= usage_limit
  end

  def remaining_usage
    return nil if usage_limit.nil?
    [usage_limit - usage_count, 0].max
  end

  def applicable?(item_or_order)
    return false unless active?
    return false if usage_limit_reached?

    case item_or_order
    when OrderItem
      applicable_to_item?(item_or_order)
    when Order
      applicable_to_order?(item_or_order)
    else
      false
    end
  end

  def calculate_discount(item_or_order)
    return 0 unless applicable?(item_or_order)

    case item_or_order
    when OrderItem
      calculate_item_discount(item_or_order)
    when Order
      calculate_order_discount(item_or_order)
    else
      0
    end
  end

  private

  def applicable_to_item?(item)
    return false if product_id.present? && item.product_id != product_id
    return false if category_id.present? && item.product.category_id != category_id
    return false if brand_id.present? && item.product.brand_id != brand_id

    true
  end

  def applicable_to_order?(order)
    return false if minimum_purchase_amount.present? && order.total < minimum_purchase_amount

    if product_id.present?
      return order.items.any? { |item| item.product_id == product_id }
    end

    if category_id.present?
      return order.items.any? { |item| item.product.category_id == category_id }
    end

    if brand_id.present?
      return order.items.any? { |item| item.product.brand_id == brand_id }
    end

    true
  end

  def calculate_item_discount(item)
    case discount_type
    when 'percentage'
      (item.price * item.quantity * discount_amount / 100).round(2)
    when 'fixed_amount'
      [discount_amount, item.price * item.quantity].min
    when 'buy_one_get_one'
      calculate_bogo_discount(item)
    else
      0
    end
  end

  def calculate_order_discount(order)
    applicable_items = order.items.select { |item| applicable_to_item?(item) }
    applicable_amount = applicable_items.sum { |item| item.price * item.quantity }

    case discount_type
    when 'percentage'
      (applicable_amount * discount_amount / 100).round(2)
    when 'fixed_amount'
      [discount_amount, applicable_amount].min
    when 'buy_one_get_one'
      applicable_items.sum { |item| calculate_bogo_discount(item) }
    else
      0
    end
  end

  def calculate_bogo_discount(item)
    # Buy One Get One Free の計算ロジック
    # 例: 2個買うと1個無料、3個買うと1個無料、4個買うと2個無料など
    free_quantity = (item.quantity / 2).floor
    (free_quantity * item.price).round(2)
  end

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "は開始日より後の日付にしてください")
    end
  end

  def target_present
    if product_id.blank? && category_id.blank? && brand_id.blank?
      errors.add(:base, "商品、カテゴリ、またはブランドのいずれかを指定してください")
    end
  end

  def set_status
    self.status = if Time.current < start_date
                    'scheduled'
                  elsif Time.current > end_date
                    'expired'
                  elsif is_active
                    'active'
                  else
                    'cancelled'
                  end
  end
end
