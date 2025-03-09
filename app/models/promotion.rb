class Promotion < ApplicationRecord
  # 関連付け
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :promotion_rules, dependent: :destroy
  has_many :coupons, dependent: :destroy
  has_many :campaigns, dependent: :nullify

  # バリデーション
  validates :name, presence: true, length: { maximum: 255 }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :promotion_type, presence: true
  validates :code, uniqueness: true, allow_blank: true
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :minimum_order_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :usage_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :end_date_after_start_date

  # コールバック
  before_save :generate_code, if: -> { code.blank? && promotion_type.present? }

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :expired, -> { where('end_date < ?', Time.current) }
  scope :public_promotions, -> { where(is_public: true) }
  scope :private_promotions, -> { where(is_public: false) }
  scope :combinable, -> { where(is_combinable: true) }
  scope :by_type, ->(type) { where(promotion_type: type) }
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
    usage_limit.present? && usage_count >= usage_limit
  end

  def remaining_usage
    return nil if usage_limit.nil?
    [usage_limit - usage_count, 0].max
  end

  def applicable?(order)
    return false unless active?
    return false if usage_limit_reached?
    return false if minimum_order_amount.present? && order.total < minimum_order_amount

    # プロモーションルールの評価
    promotion_rules.all? { |rule| rule.eligible?(order) }
  end

  def calculate_discount(order)
    return 0 unless applicable?(order)

    case promotion_type
    when 'percentage_discount'
      (order.total * discount_amount / 100).round(2)
    when 'fixed_amount'
      [discount_amount, order.total].min
    when 'buy_x_get_y'
      # 実装は別途必要
      0
    else
      0
    end
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "は開始日より後の日付にしてください")
    end
  end

  def generate_code
    prefix = case promotion_type
             when 'percentage_discount' then 'PCT'
             when 'fixed_amount' then 'AMT'
             when 'buy_x_get_y' then 'BOGO'
             else 'PROMO'
             end

    self.code = "#{prefix}#{SecureRandom.hex(4).upcase}"
  end
end
