class Coupon < ApplicationRecord
  # 関連付け
  belongs_to :promotion, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :category, optional: true
  belongs_to :product, optional: true

  # バリデーション
  validates :code, presence: true, uniqueness: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :coupon_type, presence: true
  validates :discount_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :minimum_order_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :usage_limit_per_user, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :usage_limit_total, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :end_date_after_start_date
  validate :category_or_product_present_if_specific

  # コールバック
  before_validation :upcase_code

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :expired, -> { where('end_date < ?', Time.current) }
  scope :by_type, ->(type) { where(coupon_type: type) }
  scope :single_use, -> { where(is_single_use: true) }
  scope :first_order_only, -> { where(is_first_order_only: true) }
  scope :combinable, -> { where(is_combinable: true) }
  scope :by_priority, -> { order(priority: :desc) }

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
    (usage_limit_total.present? && usage_count >= usage_limit_total)
  end

  def usage_limit_reached_for_user?(user)
    return false unless usage_limit_per_user.present? && user.present?

    user_usage_count = user.orders.where("coupon_code = ?", code).count
    user_usage_count >= usage_limit_per_user
  end

  def remaining_usage
    return nil if usage_limit_total.nil?
    [usage_limit_total - usage_count, 0].max
  end

  def applicable?(order, user = nil)
    return false unless active?
    return false if usage_limit_reached?
    return false if user.present? && usage_limit_reached_for_user?(user)
    return false if is_first_order_only && user.present? && user.orders.completed.count > 0
    return false if minimum_order_amount.present? && order.total < minimum_order_amount

    # カテゴリまたは商品の制限チェック
    if category.present?
      return false unless order.items.any? { |item| item.product.category_id == category_id }
    end

    if product.present?
      return false unless order.items.any? { |item| item.product_id == product_id }
    end

    true
  end

  def calculate_discount(order)
    return 0 unless applicable?(order, order.user)

    case coupon_type
    when 'percentage'
      applicable_amount = calculate_applicable_amount(order)
      (applicable_amount * discount_amount / 100).round(2)
    when 'fixed_amount'
      [discount_amount, order.total].min
    when 'free_shipping'
      order.shipping_cost || 0
    else
      0
    end
  end

  private

  def calculate_applicable_amount(order)
    if category.present?
      order.items.select { |item| item.product.category_id == category_id }.sum(&:total)
    elsif product.present?
      order.items.select { |item| item.product_id == product_id }.sum(&:total)
    else
      order.total
    end
  end

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "は開始日より後の日付にしてください")
    end
  end

  def category_or_product_present_if_specific
    if coupon_type == 'category_specific' && category_id.blank?
      errors.add(:category_id, "カテゴリ限定クーポンにはカテゴリの指定が必要です")
    end

    if coupon_type == 'product_specific' && product_id.blank?
      errors.add(:product_id, "商品限定クーポンには商品の指定が必要です")
    end
  end

  def upcase_code
    self.code = code.upcase if code.present?
  end
end
