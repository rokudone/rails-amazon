class ProductBundle < ApplicationRecord
  # 関連付け
  has_many :product_bundle_items, dependent: :destroy
  has_many :products, through: :product_bundle_items

  # バリデーション
  validates :name, presence: true, length: { maximum: 255 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validate :end_date_after_start_date, if: -> { start_date.present? && end_date.present? }

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :current, -> {
    where(is_active: true)
      .where('start_date IS NULL OR start_date <= ?', Time.current)
      .where('end_date IS NULL OR end_date >= ?', Time.current)
  }
  scope :upcoming, -> { where(is_active: true).where('start_date > ?', Time.current) }
  scope :expired, -> { where('end_date < ?', Time.current) }

  # カスタムメソッド
  def total_products_price
    products.sum(:price)
  end

  def savings_amount
    total_products_price - price
  end

  def savings_percentage
    return 0 if total_products_price.zero?
    ((total_products_price - price) / total_products_price * 100).round(2)
  end

  def active?
    is_active? && (!start_date || start_date <= Time.current) && (!end_date || end_date >= Time.current)
  end

  def expired?
    end_date.present? && end_date < Time.current
  end

  def upcoming?
    start_date.present? && start_date > Time.current
  end

  def time_remaining
    return nil unless active? && end_date.present?
    end_date - Time.current
  end

  def days_remaining
    return nil unless time_remaining
    (time_remaining / 1.day).ceil
  end

  def add_product(product, quantity = 1)
    item = product_bundle_items.find_or_initialize_by(product_id: product.id)
    item.quantity = quantity
    item.save
  end

  def remove_product(product)
    product_bundle_items.where(product_id: product.id).destroy_all
  end

  private

  def end_date_after_start_date
    if end_date <= start_date
      errors.add(:end_date, "は開始日より後の日付である必要があります")
    end
  end
end
