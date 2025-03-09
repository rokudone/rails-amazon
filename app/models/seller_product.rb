class SellerProduct < ApplicationRecord
  # 関連付け
  belongs_to :seller
  belongs_to :product
  has_many :order_items, dependent: :nullify

  # バリデーション
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :seller_id, uniqueness: { scope: :product_id, message: "すでにこの商品を出品しています" }
  validates :sku, uniqueness: { scope: :seller_id, allow_blank: true }
  validates :condition, presence: true
  validates :handling_days, numericality: { only_integer: true, greater_than: 0 }

  # コールバック
  before_save :calculate_profit_margin, if: -> { price_changed? || seller_cost_changed? }
  after_save :update_product_price, if: -> { saved_change_to_price? && is_active? }
  after_save :update_sales_stats, if: -> { saved_change_to_sales_count? }

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :in_stock, -> { where('quantity > 0') }
  scope :out_of_stock, -> { where(quantity: 0) }
  scope :featured, -> { where(is_featured: true) }
  scope :prime_eligible, -> { where(is_prime_eligible: true) }
  scope :fulfilled_by_amazon, -> { where(is_fulfilled_by_amazon: true) }
  scope :by_condition, ->(condition) { where(condition: condition) }
  scope :by_price_range, ->(min, max) { where('price >= ? AND price <= ?', min, max) }
  scope :best_selling, -> { order(sales_count: :desc) }
  scope :recently_sold, -> { where.not(last_sold_at: nil).order(last_sold_at: :desc) }
  scope :most_profitable, -> { order(profit_margin: :desc) }

  # カスタムメソッド
  def activate!
    update(is_active: true)
  end

  def deactivate!
    update(is_active: false)
  end

  def feature!
    update(is_featured: true)
  end

  def unfeature!
    update(is_featured: false)
  end

  def enable_prime!
    update(is_prime_eligible: true)
  end

  def disable_prime!
    update(is_prime_eligible: false)
  end

  def enable_fba!
    update(is_fulfilled_by_amazon: true)
  end

  def disable_fba!
    update(is_fulfilled_by_amazon: false)
  end

  def in_stock?
    quantity > 0
  end

  def out_of_stock?
    quantity <= 0
  end

  def low_stock?
    quantity > 0 && quantity <= 5
  end

  def update_quantity!(new_quantity)
    update(quantity: new_quantity)
  end

  def increment_quantity!(amount = 1)
    increment!(:quantity, amount)
  end

  def decrement_quantity!(amount = 1)
    decrement!(:quantity, [amount, quantity].min)
  end

  def record_sale!(quantity_sold = 1)
    decrement_quantity!(quantity_sold)
    increment!(:sales_count, quantity_sold)
    update(last_sold_at: Time.current)
  end

  def total_revenue
    price * sales_count
  end

  def total_profit
    return 0 if seller_cost.nil?
    (price - seller_cost) * sales_count
  end

  def shipping_days_range
    min_days = handling_days
    max_days = handling_days + (is_prime_eligible? ? 2 : 5)
    "#{min_days}-#{max_days}"
  end

  private

  def calculate_profit_margin
    if price.present? && seller_cost.present? && price > 0
      self.profit_margin = ((price - seller_cost) / price * 100).round(2)
    else
      self.profit_margin = nil
    end
  end

  def update_product_price
    # 最安値の場合、商品の価格を更新
    min_price = product.seller_products.active.minimum(:price)
    if min_price.present? && (product.price.nil? || min_price < product.price)
      product.update(price: min_price)
    end
  end

  def update_sales_stats
    # 販売者の売上統計を更新
    # 実装は別途必要
  end
end
