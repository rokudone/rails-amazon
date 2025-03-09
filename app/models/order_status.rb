class OrderStatus < ApplicationRecord
  # 関連付け
  has_many :orders, dependent: :restrict_with_error

  # バリデーション
  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :display_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :color_code, format: { with: /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/, message: '有効なカラーコードを入力してください' }, allow_nil: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :default, -> { where(is_default: true) }
  scope :cancellable, -> { where(is_cancellable: true) }
  scope :returnable, -> { where(is_returnable: true) }
  scope :requires_shipping, -> { where(requires_shipping: true) }
  scope :requires_payment, -> { where(requires_payment: true) }
  scope :ordered, -> { order(display_order: :asc) }

  # カスタムメソッド
  def self.get_default
    default.first || first
  end

  def self.find_by_code(code)
    where('LOWER(code) = ?', code.to_s.downcase).first
  end

  def cancellable?
    is_cancellable
  end

  def returnable?
    is_returnable
  end

  def requires_shipping?
    requires_shipping
  end

  def requires_payment?
    requires_payment
  end

  def active?
    is_active
  end

  def default?
    is_default
  end

  def next_statuses
    case code.downcase
    when 'pending'
      OrderStatus.where(code: ['processing', 'cancelled'])
    when 'processing'
      OrderStatus.where(code: ['shipped', 'cancelled'])
    when 'shipped'
      OrderStatus.where(code: ['delivered', 'returned'])
    when 'delivered'
      OrderStatus.where(code: ['returned', 'completed'])
    when 'returned'
      OrderStatus.where(code: ['refunded', 'completed'])
    when 'cancelled'
      []
    when 'refunded'
      OrderStatus.where(code: ['completed'])
    when 'completed'
      []
    else
      []
    end
  end

  def can_transition_to?(target_status)
    next_statuses.include?(target_status)
  end
end
