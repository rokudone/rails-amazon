class OrderDiscount < ApplicationRecord
  # 関連付け
  belongs_to :order

  # バリデーション
  validates :discount_type, presence: true, inclusion: { in: ['coupon', 'promotion', 'volume', 'loyalty', 'seasonal', 'employee', 'bundle'] }
  validates :calculation_type, presence: true, inclusion: { in: ['percentage', 'fixed_amount', 'free_shipping', 'buy_x_get_y'] }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }
  validates :maximum_discount_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :minimum_order_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :applied_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :usage_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :usage_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :valid_date_range

  # コールバック
  before_validation :calculate_applied_amount, if: :new_record?
  after_save :update_order_totals
  after_destroy :update_order_totals

  # スコープ
  scope :active, -> { where(is_applied: true) }
  scope :inactive, -> { where(is_applied: false) }
  scope :by_type, ->(type) { where(discount_type: type) }
  scope :by_calculation_type, ->(type) { where(calculation_type: type) }
  scope :by_code, ->(code) { where(discount_code: code) }
  scope :combinable, -> { where(is_combinable: true) }
  scope :non_combinable, -> { where(is_combinable: false) }
  scope :current, -> { where('valid_from IS NULL OR valid_from <= ?', Time.now).where('valid_until IS NULL OR valid_until >= ?', Time.now) }
  scope :expired, -> { where('valid_until < ?', Time.now) }
  scope :not_started, -> { where('valid_from > ?', Time.now) }
  scope :by_date_range, ->(start_date, end_date) { where('valid_from <= ? AND valid_until >= ?', end_date, start_date) }
  scope :by_order, ->(order_id) { where(order_id: order_id) }

  # カスタムメソッド
  def active?
    is_applied
  end

  def inactive?
    !is_applied
  end

  def combinable?
    is_combinable
  end

  def expired?
    valid_until.present? && valid_until < Time.now
  end

  def not_started?
    valid_from.present? && valid_from > Time.now
  end

  def current?
    !expired? && !not_started?
  end

  def usage_limit_reached?
    usage_limit.present? && usage_count >= usage_limit
  end

  def minimum_order_amount_met?(order_subtotal)
    minimum_order_amount.blank? || order_subtotal >= minimum_order_amount
  end

  def calculate_discount_amount(order_subtotal)
    return 0 unless active? && current? && !usage_limit_reached? && minimum_order_amount_met?(order_subtotal)

    amount = case calculation_type
    when 'percentage'
      order_subtotal * (discount_value / 100.0)
    when 'fixed_amount'
      discount_value
    when 'free_shipping'
      order.shipping_total || 0
    when 'buy_x_get_y'
      # 実際の実装では、より複雑なロジックが必要
      # ここでは簡易的な実装
      0
    else
      0
    end

    # 最大割引額を適用
    if maximum_discount_amount.present?
      amount = [amount, maximum_discount_amount].min
    end

    amount
  end

  def apply!
    return false if expired? || not_started? || usage_limit_reached?

    if update(
      is_applied: true,
      applied_at: Time.now,
      usage_count: usage_count + 1
    )
      update_order_totals
      true
    else
      false
    end
  end

  def unapply!
    if update(
      is_applied: false,
      applied_amount: 0
    )
      update_order_totals
      true
    else
      false
    end
  end

  def discount_type_label
    case discount_type
    when 'coupon'
      'クーポン'
    when 'promotion'
      'プロモーション'
    when 'volume'
      '数量割引'
    when 'loyalty'
      'ロイヤルティ割引'
    when 'seasonal'
      '季節割引'
    when 'employee'
      '従業員割引'
    when 'bundle'
      'バンドル割引'
    else
      discount_type
    end
  end

  def calculation_type_label
    case calculation_type
    when 'percentage'
      'パーセント割引'
    when 'fixed_amount'
      '固定金額割引'
    when 'free_shipping'
      '送料無料'
    when 'buy_x_get_y'
      'X個買うとY個無料'
    else
      calculation_type
    end
  end

  def discount_description
    case calculation_type
    when 'percentage'
      "#{discount_value}%オフ"
    when 'fixed_amount'
      "#{discount_value}#{order.currency}オフ"
    when 'free_shipping'
      "送料無料"
    when 'buy_x_get_y'
      "X個買うとY個無料"
    else
      description || "割引"
    end
  end

  def formatted_valid_period
    if valid_from.present? && valid_until.present?
      "#{valid_from.strftime('%Y/%m/%d')} - #{valid_until.strftime('%Y/%m/%d')}"
    elsif valid_from.present?
      "#{valid_from.strftime('%Y/%m/%d')}から"
    elsif valid_until.present?
      "#{valid_until.strftime('%Y/%m/%d')}まで"
    else
      "無期限"
    end
  end

  private

  def valid_date_range
    if valid_from.present? && valid_until.present? && valid_from > valid_until
      errors.add(:valid_until, "は開始日より後の日付にしてください")
    end
  end

  def calculate_applied_amount
    return if order.nil? || !is_applied

    self.applied_amount = calculate_discount_amount(order.subtotal)
  end

  def update_order_totals
    return if order.nil?

    # 注文の割引合計を再計算
    total_discount = order.order_discounts.active.sum(:applied_amount)
    order.update(discount_total: total_discount)

    # 注文の総額を再計算
    order.calculate_totals
    order.save
  end
end
